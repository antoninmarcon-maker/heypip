import Foundation

/// Settings and meeting files.
///
/// A meeting lives in `~/Documents/Pip/<date>_<name>/`:
///   transcript.md   one line per sentence: `[12:03:15] You: …`   (always, stays on your Mac)
///   agent-feed.md   the same lines, only while the agent is on: this is the file your agent follows
///   notes.md        written by your agent during the call, shown in the island
///   you.m4a / them.m4a   the audio, for speaker separation and the summary after the call
/// `~/Documents/Pip/current` always points to the meeting in progress.
enum Store {
  static let defaults = UserDefaults.standard

  static var root: URL {
    if let path = defaults.string(forKey: "meetingsFolder"), !path.isEmpty {
      return URL(fileURLWithPath: (path as NSString).expandingTildeInPath)
    }
    return FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Documents/Pip")
  }

  static var current: URL { root.appendingPathComponent("current") }

  static var supportFolder: URL {
    let url = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("Pip")
    try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
  }

  /// Words the transcription should recognise (names, products, jargon). One per line.
  static var vocabularyFile: URL {
    let url = supportFolder.appendingPathComponent("vocabulary.txt")
    if !FileManager.default.fileExists(atPath: url.path) {
      try? "# One word or name per line: people, companies, products, jargon.\nClaude\n".write(to: url, atomically: true, encoding: .utf8)
    }
    return url
  }

  static var vocabulary: [String] {
    guard let text = try? String(contentsOf: vocabularyFile, encoding: .utf8) else { return [] }
    return text.split(separator: "\n").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty && !$0.hasPrefix("#") }
  }

  /// When off, nothing is written for the agent: the transcript stays local only.
  static var agentEnabled: Bool {
    get { defaults.object(forKey: "agentEnabled") as? Bool ?? true }
    set { defaults.set(newValue, forKey: "agentEnabled") }
  }

  /// Transcription language (BCP 47). Defaults to the Mac's language.
  /// Show the printed Pip next to the notch when no meeting runs.
  static var restingPip: Bool {
    get { defaults.object(forKey: "restingPip") as? Bool ?? true }
    set { defaults.set(newValue, forKey: "restingPip") }
  }

  static var languageID: String {
    get { defaults.string(forKey: "language") ?? (Locale.preferredLanguages.first ?? "en-US") }
    set { defaults.set(newValue, forKey: "language") }
  }

  static func newMeeting(name: String) throws -> URL {
    let f = DateFormatter()
    f.dateFormat = "yyyy-MM-dd_HHmm"
    let slug = name.lowercased().folding(options: .diacriticInsensitive, locale: .current)
      .replacingOccurrences(of: "[^a-z0-9]+", with: "-", options: .regularExpression)
      .trimmingCharacters(in: CharacterSet(charactersIn: "-"))
    let dir = root.appendingPathComponent(f.string(from: Date()) + (slug.isEmpty ? "" : "_" + slug))
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    let d = DateFormatter()
    d.dateStyle = .medium
    d.timeStyle = .short
    let title = name.isEmpty ? L10n.t("meeting") : name
    try "# \(title) · \(d.string(from: Date()))\n\n".write(to: dir.appendingPathComponent("transcript.md"), atomically: true, encoding: .utf8)
    try "".write(to: dir.appendingPathComponent("notes.md"), atomically: true, encoding: .utf8)
    try "# \(title) · \(d.string(from: Date()))\n\n".write(to: dir.appendingPathComponent("agent-feed.md"), atomically: true, encoding: .utf8)
    try? FileManager.default.removeItem(at: current)
    try FileManager.default.createSymbolicLink(at: current, withDestinationURL: dir)
    return dir
  }

  static func append(_ text: String, to url: URL) {
    guard let data = text.data(using: .utf8), let h = try? FileHandle(forWritingTo: url) else { return }
    h.seekToEndOfFile()
    h.write(data)
    try? h.close()
  }
}
