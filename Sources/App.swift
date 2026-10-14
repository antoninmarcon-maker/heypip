import AppKit
import Combine
import AVFoundation
import Speech

@MainActor final class AppDelegate: NSObject, NSApplicationDelegate {
  private let meeting = Meeting()
  private let updater = Updater()
  private var island: IslandController?
  private var bag = Set<AnyCancellable>()

  func applicationDidFinishLaunching(_ notification: Notification) {
    let island = IslandController(meeting: meeting, updater: updater)
    self.island = island
    let meeting = self.meeting
    updater.start(isBusy: { meeting.running || meeting.busy })
    // a meeting just ended: a good moment to update
    meeting.$running.dropFirst().filter { !$0 }.sink { [weak self] _ in
      Task { @MainActor in await self?.updater.check(install: true) }
    }.store(in: &bag)
    if let i = CommandLine.arguments.firstIndex(of: "--demo") {
      let lang = i + 1 < CommandLine.arguments.count ? CommandLine.arguments[i + 1] : "en"
      island.runDemo(french: lang == "fr")
    }
    // --start: start a meeting at launch (tests; use -meetingsFolder <dir> to keep your meetings apart)
    if CommandLine.arguments.contains("--start") {
      Task { await meeting.start() }
    }
    // --peek "text": show a sample note (screenshots)
    if let i = CommandLine.arguments.firstIndex(of: "--peek"), i + 1 < CommandLine.arguments.count {
      meeting.peek = CommandLine.arguments[i + 1]
    }
    Task {
      let locales: [Locale]
      if #available(macOS 26, *) { locales = await SpeechTranscriber.supportedLocales } else { locales = Array(SFSpeechRecognizer.supportedLocales()) }
      island.state.languages = locales.sorted { $0.identifier < $1.identifier }
    }
  }

  func applicationWillTerminate(_ notification: Notification) {
    let meeting = self.meeting
    let done = DispatchSemaphore(value: 0)
    Task { await meeting.stop(); done.signal() }
    _ = done.wait(timeout: .now() + 3)
  }
}

// MARK: - File test, no capture: Pip --test file.m4a [language]

func runFileTest(_ path: String, language: String) async {
  guard let file = try? AVAudioFile(forReading: URL(fileURLWithPath: path)) else { print("cannot read file"); exit(1) }
  let t = CommandLine.arguments.contains("--legacy")
    ? LegacyTranscriber(speaker: .them, fileURL: FileManager.default.temporaryDirectory.appendingPathComponent("heypip-test.m4a"))
    : makeTranscriber(speaker: .them, fileURL: FileManager.default.temporaryDirectory.appendingPathComponent("heypip-test.m4a"))
  let start = Date()
  let realtime = CommandLine.arguments.contains("--realtime")
  let splitter = SentenceSplitter()
  let lock = NSLock()
  do {
    try await t.start(languageID: language, words: Store.vocabulary) { who, text, final in
      lock.lock(); defer { lock.unlock() }
      if !final, ProcessInfo.processInfo.environment["EARPIECE_DEBUG"] != nil { print(String(format: "  ~%5.1fs %@", Date().timeIntervalSince(start), String(text.suffix(90)))) }
      let sentences = final ? splitter.final(text) : splitter.volatile(text).new
      for s in sentences { print(String(format: "[%5.1fs] %@: %@", Date().timeIntervalSince(start), who.label, s)) }
    }
  } catch { print("error: \(error.localizedDescription)"); exit(1) }
  let chunk: AVAudioFrameCount = 4800
  while file.framePosition < file.length {
    guard let buf = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: chunk) else { break }
    try? file.read(into: buf, frameCount: chunk)
    if buf.frameLength == 0 { break }
    t.feed(buf)
    if realtime { try? await Task.sleep(for: .seconds(Double(buf.frameLength) / file.processingFormat.sampleRate)) }
  }
  await t.stop()
  print(String(format: "done in %.1f s", Date().timeIntervalSince(start)))
  exit(0)
}

@main
struct PipApp {
  @MainActor static func main() {
    let args = CommandLine.arguments
    if let i = args.firstIndex(of: "--test"), i + 1 < args.count {
      let path = args[i + 1]
      let language = i + 2 < args.count ? args[i + 2] : Store.languageID
      Task { await runFileTest(path, language: language) }
      RunLoop.main.run()
    }
    let app = NSApplication.shared
    let delegate = AppDelegate()
    app.delegate = delegate
    app.setActivationPolicy(.accessory)
    app.run()
  }
}
