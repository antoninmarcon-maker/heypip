import AVFoundation
import Foundation

/// Where a meeting's audio comes from: the live capture, or a recorded call played back silently (`--replay`).
protocol AudioSource: AnyObject {
  var onAudio: ((AVAudioPCMBuffer, Speaker) -> Void)? { get set }
  var onError: ((String) -> Void)? { get set }
  func start() async throws
  func stop() async
}

extension Capture: AudioSource {}

/// `Pip --replay you.m4a them.m4a [seconds]`: a recorded call goes through Pip as if it were live, at real speed and
/// without a sound (tests, and bug reports that come with their two tracks). `seconds` moves « Them » later (negative:
/// earlier) so the call's echo in the microphone lines up with the call, as it does live.
final class Replay: AudioSource, @unchecked Sendable {
  /// A replay makes no sound at all (no « Tink » when a note pops out).
  static let active = CommandLine.arguments.contains("--replay")
  var onAudio: ((AVAudioPCMBuffer, Speaker) -> Void)?
  var onError: ((String) -> Void)?
  private let tracks: [(who: Speaker, file: AVAudioFile, delay: TimeInterval)]
  private var fed: [Speaker: AVAudioFramePosition] = [:]
  private var startedAt: Date?
  private var timer: DispatchSourceTimer?
  private let queue = DispatchQueue(label: "heypip.replay")

  /// `themDelay` nil: measured from the tracks (see `alignment`).
  init(you: URL, them: URL, themDelay: TimeInterval?) throws {
    let delay = try themDelay ?? Self.alignment(you: you, them: them)
    tracks = [
      (.me, try AVAudioFile(forReading: you), max(0, -delay)),
      (.them, try AVAudioFile(forReading: them), max(0, delay)),
    ]
    self.delay = delay
  }

  let delay: TimeInterval

  /// The two files of a meeting do not start at exactly the same moment. Live, the call's echo reaches the
  /// microphone at the same time as the call reaches Pip: the delay that lines the microphone's loudness up with the
  /// call's (over the first 10 minutes, within ±3 s: excerpts may be cut a little apart) puts them back that way.
  static func alignment(you: URL, them: URL) throws -> TimeInterval {
    func envelope(_ url: URL) throws -> [Float] {
      let file = try AVAudioFile(forReading: url)
      let bin = AVAudioFrameCount(file.processingFormat.sampleRate * 0.02)
      var out: [Float] = []
      guard let buf = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: bin * 500) else { return [] }
      while file.framePosition < file.length, out.count < 30_000 {
        try file.read(into: buf)
        guard let data = buf.floatChannelData?[0], buf.frameLength > 0 else { break }
        var i = 0
        while i + Int(bin) <= Int(buf.frameLength) {
          var s: Float = 0
          for k in i..<(i + Int(bin)) { s += data[k] * data[k] }
          out.append(log((s / Float(bin)).squareRoot() + 0.0001))
          i += Int(bin)
        }
      }
      return out
    }
    let y = try envelope(you), t = try envelope(them)
    let n = min(y.count, t.count)
    guard n > 200 else { return 0 }
    var best = 0, bestR: Float = 0.3
    for lag in -150...150 {
      // pairs you[i + lag] with them[i]
      let range = max(0, -lag)..<min(n, n - lag)
      guard range.count > 300 else { continue }
      let r = pearson(range.map { y[$0 + lag] }, range.map { t[$0] })
      if r > bestR { best = lag; bestR = r }
    }
    return Double(best) * 0.02
  }

  /// Seconds until both tracks have been played.
  var duration: TimeInterval {
    tracks.map { Double($0.file.length) / $0.file.processingFormat.sampleRate + $0.delay }.max() ?? 0
  }

  func start() async throws {
    // a restart (Meeting.watchCapture) keeps going where it was
    guard timer == nil else { return }
    if startedAt == nil { startedAt = Date() }
    let t = DispatchSource.makeTimerSource(queue: queue)
    t.schedule(deadline: .now(), repeating: .milliseconds(10))
    t.setEventHandler { [weak self] in self?.tick() }
    t.resume()
    timer = t
  }

  func stop() async {
    timer?.cancel()
    timer = nil
  }

  /// Sends what is due since the start, in 20 ms buffers; silence before a track starts and after it ends.
  private func tick() {
    guard let startedAt else { return }
    let elapsed = Date().timeIntervalSince(startedAt)
    for track in tracks {
      let format = track.file.processingFormat
      let chunk = AVAudioFrameCount(format.sampleRate * 0.02)
      let due = AVAudioFramePosition(elapsed * format.sampleRate)
      while (fed[track.who] ?? 0) + AVAudioFramePosition(chunk) <= due {
        guard let buf = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: chunk) else { return }
        let start = fed[track.who] ?? 0
        let delayFrames = AVAudioFramePosition(track.delay * format.sampleRate)
        let position = start - delayFrames
        if position >= 0, position < track.file.length {
          track.file.framePosition = position
          try? track.file.read(into: buf, frameCount: chunk)
        }
        if buf.frameLength < chunk {
          // silence: before the track starts, after it ends, or the end of the last read
          let from = Int(buf.frameLength)
          buf.frameLength = chunk
          for c in 0..<Int(format.channelCount) {
            if let data = buf.floatChannelData?[c] { for i in from..<Int(chunk) { data[i] = 0 } }
          }
        }
        fed[track.who] = start + AVAudioFramePosition(chunk)
        onAudio?(buf, track.who)
      }
    }
  }
}

/// `PIP_TRACE=file`: levels and « You » decisions, one line each, for tuning the echo filter on a replayed call.
enum Trace {
  static let url: URL? = ProcessInfo.processInfo.environment["PIP_TRACE"].map { URL(fileURLWithPath: $0) }
  private static let lock = NSLock()
  nonisolated(unsafe) private static var lines: [String] = []

  static func log(_ line: @autoclosure () -> String) {
    guard url != nil else { return }
    let text = String(format: "%.3f ", Date().timeIntervalSince1970) + line()
    lock.lock(); lines.append(text); lock.unlock()
  }

  static func save() {
    guard let url else { return }
    lock.lock(); let text = lines.joined(separator: "\n") + "\n"; lock.unlock()
    try? text.write(to: url, atomically: true, encoding: .utf8)
  }
}
