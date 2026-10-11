import AppKit
import Foundation

/// Updates Pip from its GitHub releases.
///
/// Every few hours (and from the menu) Pip asks GitHub for the latest release. If it is newer, Pip downloads `Pip.zip`,
/// checks that the new app is signed by the same developer as the running one and accepted by Gatekeeper, then replaces
/// itself and relaunches — never during a meeting. Development builds (not signed with a Developer ID) never update.
@MainActor final class Updater: ObservableObject {
  static let repo = "pjksens/heypip"

  @Published var available: String?
  @Published var status: String?

  private var timer: Timer?
  private let current = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"

  func start(isBusy: @escaping () -> Bool) {
    self.isBusy = isBusy
    Task { await check(install: true) }
    timer = Timer.scheduledTimer(withTimeInterval: 6 * 3600, repeats: true) { [weak self] _ in
      Task { @MainActor in await self?.check(install: true) }
    }
  }

  private var isBusy: () -> Bool = { false }

  /// Looks for a newer release; installs it if `install` and Pip is not in a meeting.
  func check(install: Bool) async {
    guard let team = Self.teamID(of: Bundle.main.bundleURL) else { return }  // dev build: no updates
    guard let release = await latestRelease(), Self.isNewer(release.version, than: current) else { return }
    available = release.version
    guard install, !isBusy() else { return }
    await self.install(release, team: team)
  }

  /// Installs the update now (menu), even if it was found earlier.
  func installNow() {
    Task {
      guard let team = Self.teamID(of: Bundle.main.bundleURL), let release = await latestRelease(),
            Self.isNewer(release.version, than: current), !isBusy() else { return }
      await install(release, team: team)
    }
  }

  private struct Release { let version: String; let zip: URL }

  private func latestRelease() async -> Release? {
    guard let url = URL(string: "https://api.github.com/repos/\(Self.repo)/releases/latest") else { return nil }
    var req = URLRequest(url: url)
    req.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
    guard let (data, resp) = try? await URLSession.shared.data(for: req), (resp as? HTTPURLResponse)?.statusCode == 200,
          let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
          let tag = json["tag_name"] as? String,
          let assets = json["assets"] as? [[String: Any]],
          let zip = assets.first(where: { ($0["name"] as? String) == "Pip.zip" })?["browser_download_url"] as? String,
          let zipURL = URL(string: zip) else { return nil }
    return Release(version: tag.trimmingCharacters(in: CharacterSet(charactersIn: "vV")), zip: zipURL)
  }

  private func install(_ release: Release, team: String) async {
    status = L10n.t("updating")
    let work = FileManager.default.temporaryDirectory.appendingPathComponent("pip-update-\(UUID().uuidString)")
    defer { try? FileManager.default.removeItem(at: work) }
    do {
      try FileManager.default.createDirectory(at: work, withIntermediateDirectories: true)
      let (tmp, _) = try await URLSession.shared.download(from: release.zip)
      let zip = work.appendingPathComponent("Pip.zip")
      try FileManager.default.moveItem(at: tmp, to: zip)
      guard Self.run("/usr/bin/ditto", ["-x", "-k", zip.path, work.path]) == 0 else { throw UpdateError.unzip }
      let newApp = work.appendingPathComponent("Pip.app")
      // same developer, valid signature, accepted by Gatekeeper (notarized)
      guard Self.teamID(of: newApp) == team,
            Self.run("/usr/bin/codesign", ["--verify", "--deep", "--strict", newApp.path]) == 0,
            Self.run("/usr/sbin/spctl", ["--assess", "--type", "execute", newApp.path]) == 0 else { throw UpdateError.signature }
      let target = Bundle.main.bundleURL
      _ = try FileManager.default.replaceItemAt(target, withItemAt: newApp)
      status = nil
      // relaunch the new version once this one has quit
      let p = Process()
      p.executableURL = URL(fileURLWithPath: "/bin/sh")
      p.arguments = ["-c", "sleep 1; /usr/bin/open \"\(target.path)\""]
      try p.run()
      NSApp.terminate(nil)
    } catch {
      status = "\(L10n.t("updateFailed")) (\(error))"
    }
  }

  private enum UpdateError: Error { case unzip, signature }

  /// "1.10.0" > "1.9.2"
  static func isNewer(_ a: String, than b: String) -> Bool {
    let x = a.split(separator: ".").map { Int($0) ?? 0 }, y = b.split(separator: ".").map { Int($0) ?? 0 }
    for i in 0..<max(x.count, y.count) {
      let l = i < x.count ? x[i] : 0, r = i < y.count ? y[i] : 0
      if l != r { return l > r }
    }
    return false
  }

  /// The Team ID of a Developer ID signature, nil for ad-hoc or development builds.
  static func teamID(of app: URL) -> String? {
    let pipe = Pipe()
    let p = Process()
    p.executableURL = URL(fileURLWithPath: "/usr/bin/codesign")
    p.arguments = ["-dv", "--verbose=2", app.path]
    p.standardError = pipe
    p.standardOutput = Pipe()
    guard (try? p.run()) != nil else { return nil }
    p.waitUntilExit()
    let out = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
    guard out.contains("Authority=Developer ID Application") else { return nil }
    return out.split(separator: "\n").first { $0.hasPrefix("TeamIdentifier=") }.map { String($0.dropFirst("TeamIdentifier=".count)) }
  }

  @discardableResult
  static func run(_ tool: String, _ args: [String]) -> Int32 {
    let p = Process()
    p.executableURL = URL(fileURLWithPath: tool)
    p.arguments = args
    p.standardOutput = Pipe()
    p.standardError = Pipe()
    guard (try? p.run()) != nil else { return -1 }
    p.waitUntilExit()
    return p.terminationStatus
  }
}
