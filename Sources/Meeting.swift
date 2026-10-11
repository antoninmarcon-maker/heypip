import AppKit
import AVFoundation
import Foundation

/// One line of the live view: a sentence, or a note from the agent.
struct FeedItem: Identifiable {
  enum Kind { case speech(Speaker), note }
  let id = UUID()
  let time: Date
  let kind: Kind
  let text: String
}

/// Last time each side was heard (written from the audio queue).
final class Levels: @unchecked Sendable {
  private let lock = NSLock()
  private var last: [Speaker: Date] = [:]
  func heard(_ who: Speaker) { lock.lock(); last[who] = Date(); lock.unlock() }
  func recent(_ who: Speaker, within s: TimeInterval = 2.5) -> Bool {
    lock.lock(); defer { lock.unlock() }
    return last[who].map { Date().timeIntervalSince($0) < s } ?? false
  }
}

/// A flag the audio queue can read.
final class Flag: @unchecked Sendable {
  private let lock = NSLock()
  private var v = false
  var value: Bool {
    get { lock.lock(); defer { lock.unlock() }; return v }
    set { lock.lock(); v = newValue; lock.unlock() }
  }
}

/// Is there sound in this buffer (not just silence)?
func hasSound(_ buf: AVAudioPCMBuffer) -> Bool {
  guard let ch = buf.floatChannelData?[0], buf.frameLength > 0 else { return false }
  var sum: Float = 0
  let n = Int(buf.frameLength)
  for i in stride(from: 0, to: n, by: 8) { sum += ch[i] * ch[i] }
  return (sum / Float(max(1, n / 8))).squareRoot() > 0.01
}

@MainActor final class Meeting: ObservableObject {
  @Published var running = false
  @Published var busy = false
  @Published var status = L10n.t("ready")
  @Published var name = ""
  /// Final sentences and agent notes, in order.
  @Published var feed: [FeedItem] = []
  /// Sound heard from each side in the last seconds.
  @Published var hears: [Speaker: Bool] = [:]
  @Published var volatile: [Speaker: String] = [:]
  /// Agent notes, newest first.
  @Published var notes: [String] = []
  /// A new note arrived: the island shows it briefly.
  @Published var peek: String?
  @Published var startedAt: Date?
  /// Recording paused: audio is dropped (not transcribed, not saved) until resume.
  @Published var paused = false
  /// Last start failed or the capture stopped by itself.
  @Published var failed = false
  /// When the last meeting ended (Pip is happy for a few minutes).
  @Published var endedAt: Date?
  private var pausedAt: Date?
  private var pausedTotal: TimeInterval = 0
  private let pauseFlag = Flag()
  @Published var dir: URL?
  /// The agent follows agent-feed.md and writes notes.md. Off: transcription only, nothing for the agent.
  @Published var agentEnabled = Store.agentEnabled

  private let capture = Capture()
  private var transcribers: [Speaker: Transcribing] = [:]
  private var notesTimer: Timer?
  private let levels = Levels()
  private var splitters: [Speaker: SentenceSplitter] = [:]
  private var levelsTimer: Timer?
  private var notesDate: Date?
  private var peekTask: Task<Void, Never>?
  private let timeFormat: DateFormatter = { let f = DateFormatter(); f.dateFormat = "HH:mm:ss"; return f }()

  func toggle() {
    Task { running ? await stop() : await start() }
  }

  /// Recording time, pauses excluded.
  func elapsed(at now: Date) -> TimeInterval {
    guard let startedAt else { return 0 }
    return now.timeIntervalSince(startedAt) - pausedTotal - (pausedAt.map { now.timeIntervalSince($0) } ?? 0)
  }

  func togglePause() {
    guard running else { return }
    paused.toggle()
    pauseFlag.value = paused
    let now = Date()
    if paused { pausedAt = now } else if let p = pausedAt { pausedTotal += now.timeIntervalSince(p); pausedAt = nil }
    status = L10n.t(paused ? "paused" : "listening")
    if paused { volatile = [:] }
    if let dir {
      let mark = "\n— \(L10n.t(paused ? "pause" : "resume")) (\(timeFormat.string(from: now))) —\n"
      Store.append(mark, to: dir.appendingPathComponent("transcript.md"))
      if agentEnabled { Store.append(mark, to: dir.appendingPathComponent("agent-feed.md")) }
    }
  }

  func start() async {
    guard !running, !busy else { return }
    busy = true
    defer { busy = false }
    do {
      status = L10n.t("preparing")
      failed = false
      endedAt = nil
      paused = false
      pausedAt = nil
      pausedTotal = 0
      pauseFlag.value = false
      let dir = try Store.newMeeting(name: name)
      self.dir = dir
      feed = []
      hears = [:]
      splitters = [.me: SentenceSplitter(), .them: SentenceSplitter()]
      volatile = [:]
      notes = []
      notesDate = nil
      let me = makeTranscriber(speaker: .me, fileURL: dir.appendingPathComponent("you.m4a"))
      let them = makeTranscriber(speaker: .them, fileURL: dir.appendingPathComponent("them.m4a"))
      transcribers = [.me: me, .them: them]
      let handler: @Sendable (Speaker, String, Bool) -> Void = { [weak self] who, text, final in
        Task { @MainActor in self?.handle(who, text, final) }
      }
      status = L10n.t("model")
      let words = Store.vocabulary
      try await me.start(languageID: Store.languageID, words: words, onResult: handler)
      try await them.start(languageID: Store.languageID, words: words, onResult: handler)
      let levels = self.levels
      let pauseFlag = self.pauseFlag
      capture.onAudio = { buf, who in
        if pauseFlag.value { return }
        if hasSound(buf) { levels.heard(who) }
        (who == .me ? me : them).feed(buf)
      }
      capture.onError = { [weak self] msg in
        Task { @MainActor in
          self?.status = "\(L10n.t("captureStopped")) : \(msg)"
          self?.failed = true
        }
      }
      try await capture.start()
      running = true
      startedAt = Date()
      status = L10n.t("listening")
      watchNotes()
      levelsTimer?.invalidate()
      levelsTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
        Task { @MainActor in
          guard let self else { return }
          let now: [Speaker: Bool] = [.me: self.levels.recent(.me), .them: self.levels.recent(.them)]
          if now != self.hears { self.hears = now }
        }
      }
    } catch {
      status = "\(L10n.t("error")) : \(error.localizedDescription)"
      failed = true
      await capture.stop()
      for t in transcribers.values { await t.stop() }
      transcribers = [:]
    }
  }

  func stop() async {
    guard running, !busy else { return }
    busy = true
    defer { busy = false }
    status = L10n.t("stopping")
    await capture.stop()
    for t in transcribers.values { await t.stop() }
    transcribers = [:]
    if let dir {
      let f = DateFormatter()
      f.dateFormat = "HH:mm"
      Store.append("\n— \(L10n.t("end")) (\(f.string(from: Date()))) —\n", to: dir.appendingPathComponent("transcript.md"))
      Store.append("\n— \(L10n.t("end")) (\(f.string(from: Date()))) —\n", to: dir.appendingPathComponent("agent-feed.md"))
    }
    levelsTimer?.invalidate()
    hears = [:]
    running = false
    startedAt = nil
    paused = false
    pausedAt = nil
    pauseFlag.value = false
    endedAt = Date()
    volatile = [:]
    status = L10n.t("ended")
    // keep reading notes for a few minutes: the agent may still write the summary
    DispatchQueue.main.asyncAfter(deadline: .now() + 300) { [weak self] in
      guard let self, !self.running else { return }
      self.notesTimer?.invalidate()
    }
  }

  private func handle(_ who: Speaker, _ raw: String, _ final: Bool) {
    let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
    let splitter = splitters[who] ?? SentenceSplitter()
    splitters[who] = splitter
    if final {
      volatile[who] = nil
      for sentence in splitter.final(text) { write(who, sentence) }
    } else {
      let (new, tail) = splitter.volatile(text)
      for sentence in new { write(who, sentence) }
      volatile[who] = tail.isEmpty ? nil : tail
    }
  }

  func write(_ who: Speaker, _ text: String) {
    let item = FeedItem(time: Date(), kind: .speech(who), text: text)
    feed.append(item)
    if feed.count > 400 { feed.removeFirst(feed.count - 400) }
    if let dir {
      let line = "[\(timeFormat.string(from: item.time))] \(who.label): \(text)\n"
      Store.append(line, to: dir.appendingPathComponent("transcript.md"))
      if agentEnabled { Store.append(line, to: dir.appendingPathComponent("agent-feed.md")) }
    }
  }

  func toggleAgent() {
    agentEnabled.toggle()
    Store.agentEnabled = agentEnabled
    if let dir, running {
      Store.append("\n— \(L10n.t(agentEnabled ? "agentOn" : "agentOff")) (\(timeFormat.string(from: Date()))) —\n", to: dir.appendingPathComponent("agent-feed.md"))
    }
    if !agentEnabled { peek = nil }
  }

  private func watchNotes() {
    notesTimer?.invalidate()
    notesTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
      Task { @MainActor in self?.loadNotes() }
    }
  }

  private func loadNotes() {
    guard let url = dir?.appendingPathComponent("notes.md"),
          let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
          let date = attrs[.modificationDate] as? Date, date != notesDate,
          let text = try? String(contentsOf: url, encoding: .utf8) else { return }
    notesDate = date
    let new = text.split(separator: "\n").map { String($0).trimmingCharacters(in: .whitespaces) }
      .filter { !$0.isEmpty }.map { $0.hasPrefix("- ") ? String($0.dropFirst(2)) : $0 }.reversed()
    let latest = new.first
    let changed = latest != notes.first
    let added = new.count - notes.count
    if added > 0 {
      for n in new.prefix(added).reversed() { feed.append(FeedItem(time: Date(), kind: .note, text: n)) }
    }
    notes = Array(new)
    if changed, agentEnabled, let latest { showPeek(latest) }
  }

  private func showPeek(_ text: String) {
    peekTask?.cancel()
    peek = text
    NSSound(named: "Tink")?.play()
    peekTask = Task { [weak self] in
      try? await Task.sleep(for: .seconds(8))
      guard !Task.isCancelled else { return }
      self?.peek = nil
    }
  }
}
