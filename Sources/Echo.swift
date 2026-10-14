import AVFoundation
import Foundation

// Without headphones the microphone also hears the call from the speakers, so « Them » comes back on « You »;
// even with headphones a trace of the call can leak into the microphone. Three guards, all cheap and local:
//  - MicGate: the « You » transcriber only hears the microphone when it is clearly louder than the call's echo.
//  - EchoText: a « You » sentence that repeats what « Them » said a moment ago is an echo, not something you said.
//  - Levels.micIsEcho(): the microphone's loudness follows the call's loudness a few hundred ms later.
// Talking over the call still counts as « You »: your voice breaks both the word match and the loudness match.

/// Recent words from « Them », to cut their echo out of what the microphone transcribed.
///
/// The recogniser often glues the echo and your own words into one sentence (« …can download it and — well, I
/// think… »), so the echo is cut word by word: a run of 3 words that « Them » just said is theirs, the rest is yours.
final class EchoText {
  /// How long a « You » sentence waits before it is written, so « Them »'s words for it have arrived.
  static let wait: TimeInterval = 2
  /// How far back « Them »'s words count.
  static let window: TimeInterval = 8
  private var heard: [(time: Date, words: [String])] = []
  /// The filter only cuts once an echo was really seen (no headphones): with headphones, repeating
  /// « seven hundred euros » right after them stays yours.
  private var activeUntil = Date.distantPast

  func reset() { heard = []; activeUntil = .distantPast }

  /// « You » text to write: as heard, or without the echo once the meeting has shown one.
  /// `micEcho`: the microphone's loudness was just following the call's (Levels.micIsEcho).
  func filter(_ text: String, at time: Date = Date(), micEcho: Bool = false) -> String? {
    let mine = Self.words(text)
    let all = recentWords(at: time)
    let shared = mine.filter(all.contains).count
    if micEcho || (mine.count >= 3 && Double(shared) / Double(mine.count) >= 0.6) {
      activeUntil = time.addingTimeInterval(60)
    }
    return time < activeUntil ? strip(text, at: time) : text
  }

  private func recentWords(at time: Date) -> Set<String> {
    heard.filter { $0.time.timeIntervalSince(time) <= Self.wait && time.timeIntervalSince($0.time) <= Self.window }
      .reduce(into: Set<String>()) { $0.formUnion($1.words) }
  }

  /// Words « Them » just said (finished sentences and the text still in progress).
  func them(_ text: String, at time: Date = Date()) {
    let w = Self.words(text)
    guard !w.isEmpty else { return }
    heard.append((time, w))
    heard.removeAll { time.timeIntervalSince($0.time) > Self.window + Self.wait }
  }

  /// The part of this « You » text that is really yours, or nil when it is all echo.
  func strip(_ text: String, at time: Date = Date()) -> String? {
    let tokens = Self.tokens(text)
    guard !tokens.isEmpty else { return nil }
    let recent = heard.filter { $0.time.timeIntervalSince(time) <= Self.wait && time.timeIntervalSince($0.time) <= Self.window }
    guard !recent.isEmpty else { return text }
    let mine = tokens.map(\.word)
    let all = recent.reduce(into: Set<String>()) { $0.formUnion($1.words) }
    // a short « oui » / « d'accord » is an echo only when every word was just said by them
    if mine.count <= 2 { return mine.allSatisfy(all.contains) ? nil : text }
    var trigrams = Set<String>()
    for r in recent where r.words.count >= 3 {
      for i in 0...(r.words.count - 3) { trigrams.insert(r.words[i..<(i + 3)].joined(separator: " ")) }
    }
    var echo = [Bool](repeating: false, count: mine.count)
    for i in 0...(mine.count - 3) where trigrams.contains(mine[i..<(i + 3)].joined(separator: " ")) {
      echo[i] = true; echo[i + 1] = true; echo[i + 2] = true
    }
    if !echo.contains(true) { return text }
    // keep your runs as they were written (punctuation included), drop theirs
    var runs: [String] = []
    var i = 0
    while i < tokens.count {
      guard !echo[i] else { i += 1; continue }
      var j = i
      while j + 1 < tokens.count, !echo[j + 1] { j += 1 }
      // a run of 1–2 words that are their words, misheard (« l'itération » for « l'ablitération »), goes too
      let run = tokens[i...j].map(\.word)
      if run.count > 2 || !run.allSatisfy({ w in all.contains { Self.similar(w, $0) } }) {
        runs.append(String(text[tokens[i].range.lowerBound..<tokens[j].range.upperBound]))
      }
      i = j + 1
    }
    let kept = runs.joined(separator: " … ")
    // what is left must be yours, not the rest of their sentence recognised a little differently
    let left = Self.words(kept)
    let theirs = left.filter(all.contains).count
    if left.isEmpty || (left.count <= 2 ? theirs == left.count : Double(theirs) / Double(left.count) >= 0.7) { return nil }
    return kept.prefix(1).uppercased() + kept.dropFirst()
  }

  /// The same word, or a long word misheard (« habitation » / « habitération »); short words must match exactly,
  /// so your « test » is never taken for their « est ».
  static func similar(_ a: String, _ b: String) -> Bool {
    if a == b { return true }
    guard a.count >= 5, b.count >= 5, abs(a.count - b.count) <= 3 else { return false }
    return distance(Array(a), Array(b)) <= a.count / 3
  }

  static func distance(_ a: [Character], _ b: [Character]) -> Int {
    var row = Array(0...b.count)
    for i in 1...a.count {
      var prev = row[0]; row[0] = i
      for j in 1...b.count {
        let cur = row[j]
        row[j] = min(row[j] + 1, row[j - 1] + 1, prev + (a[i - 1] == b[j - 1] ? 0 : 1))
        prev = cur
      }
    }
    return row[b.count]
  }

  /// Is this « You » text only « Them »'s echo?
  func isEcho(_ text: String, at time: Date = Date()) -> Bool { strip(text, at: time) == nil }

  /// Lowercase words without accents or punctuation: « Ça marche ! » → ["ca", "marche"].
  static func words(_ text: String) -> [String] { tokens(text).map(\.word) }

  static func tokens(_ text: String) -> [(word: String, range: Range<String.Index>)] {
    var out: [(String, Range<String.Index>)] = []
    var i = text.startIndex
    while i < text.endIndex {
      guard text[i].isLetter || text[i].isNumber else { i = text.index(after: i); continue }
      var j = i
      while j < text.endIndex, text[j].isLetter || text[j].isNumber { j = text.index(after: j) }
      out.append((text[i..<j].folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil), i..<j))
      i = j
    }
    return out
  }
}

/// What the « You » transcriber hears: the microphone, silenced while it only carries the call's echo.
///
/// Every 20 ms the microphone's level is compared with the echo the call would give at that moment: the call's level
/// of the last few hundred ms (the room keeps ringing after a syllable) times how much of the call this microphone
/// picks up, measured during the meeting (a lot through speakers, a trace through headphones). The gate opens when the
/// microphone is clearly louder than that (your voice), a little before so the start of a word is kept, and stays open
/// while it remains louder. The recording (you.m4a) keeps everything; only the transcriber hears the gated sound.
/// The decision needs the call's next few bins, so the microphone reaches the transcriber ~180 ms later.
final class MicGate: @unchecked Sendable {
  /// `PIP_GATE=0` turns it off (to compare, in tests).
  static let enabled = ProcessInfo.processInfo.environment["PIP_GATE"] != "0"
  static let bin = 0.02
  /// Opens when the microphone is this much louder than the call's echo, and stays open while it is `low` times louder.
  static let high: Float = 2.5
  static let low: Float = 1.6
  /// Also opens when it stays `low` times louder for this many bins in a row: your voice over a loud call is not
  /// much louder than the echo, but steadily so, while the echo only jumps above it for a bin now and then.
  static let steadyBins = 5
  /// …unless the microphone follows the shape of the call over the last 400 ms: then it is the echo, louder than
  /// measured (the echo comes and goes as you move), not your voice.
  static let followBins = 20
  static let follows: Float = 0.8
  /// Stays open at least this many bins after a clear voice, and this many after a weaker one.
  static let holdBins = 10
  static let keepBins = 3
  /// Opens this many bins before your voice: the start of a word is quiet.
  static let aheadBins = 6
  /// The call's audio can reach Pip a little after its echo reaches the microphone.
  static let leadBins = 2
  /// How fast the room's ringing fades, per bin.
  static let decay: Float = 0.95
  /// Share of the call heard by the microphone until it is measured on `gainSamples` bins of the call talking
  /// (about 3 s): high, the safe side. The first measures come from the starts of syllables, where the call rises
  /// before its echo does, and would make the share look too small: the other side's first words leaked through.
  static let prior: Float = 0.6
  static let gainSamples = 150
  /// Below this share, the microphone only gets a leak of the call (headphones): weak but in spikes, up to 7 times
  /// its usual level for a bin or three. Only a voice that stays `leakHigh` times louder for `leakBins` bins in a row
  /// opens then. Your voice over the call is 4 to 10 times louder for much longer; through speakers the echo is
  /// strong but steady, and the rules above are the right ones.
  static let leakGain: Float = 0.1
  static let leakHigh: Float = 3
  static let leakBins = 4
  /// Bins used to measure that share (60 s), and which ratio of microphone / echo is taken (the median).
  static let gainBins = 3000
  static let gainQuantile: Float = 0.5
  /// The microphone's own noise: the gate needs more than `noiseFactor` times its quiet level, and at least `minFloor`.
  static let minFloor: Float = 0.004
  static let noiseFactor: Float = 1.5
  static let echoMin: Float = 0.02

  private let lock = NSLock()
  private var mic: [Int: (sum: Float, n: Int)] = [:]
  private var call: [Int: (sum: Float, n: Int)] = [:]
  private var micEnd = 0.0
  private var callEnd = 0.0
  private var pending: [(buf: AVAudioPCMBuffer, start: Double)] = []
  private var decided: Int?
  private var open: [Int: Bool] = [:]
  private var hold = 0
  private var ratios: [(bin: Int, r: Float)] = []
  private var measured = false
  private var quiet: [(bin: Int, level: Float)] = []
  private var gain = MicGate.prior
  private var floor = MicGate.minFloor
  private var level: Float = 1
  private var decidedSincePrune = 0

  func reset() {
    lock.lock(); defer { lock.unlock() }
    mic = [:]; call = [:]; micEnd = 0; callEnd = 0; micClock = Clock(); callClock = Clock(); pending = []; decided = nil; open = [:]; hold = 0
    ratios = []; measured = false; quiet = []; gain = Self.prior; floor = Self.minFloor; level = 1
  }

  /// A buffer of the call, as it arrives. Returns the microphone buffers it lets through.
  func call(_ buf: AVAudioPCMBuffer, at arrival: Date = Date()) -> [(original: AVAudioPCMBuffer, heard: AVAudioPCMBuffer)] {
    lock.lock(); defer { lock.unlock() }
    let end = callClock.end(of: buf, arrival: arrival.timeIntervalSince1970)
    callEnd = max(callEnd, add(buf, end: end, to: &call))
    return advance()
  }

  /// When a buffer's audio ends. Buffers can arrive in bursts (a busy Mac), several with almost the same arrival
  /// time: counting samples from the first one keeps them in place. Back to the arrival time after a gap or a drift
  /// of more than 100 ms (pause, capture restarted).
  struct Clock {
    private var start: Double?
    private var seconds = 0.0
    mutating func end(of buf: AVAudioPCMBuffer, arrival: Double) -> Double {
      let duration = Double(buf.frameLength) / buf.format.sampleRate
      if let start, abs(start + seconds + duration - arrival) < 0.1 {
        seconds += duration
        return start + seconds
      }
      start = arrival - duration
      seconds = duration
      return arrival
    }
  }
  private var micClock = Clock()
  private var callClock = Clock()

  /// A microphone buffer, as it arrives. Returns the microphone buffers ready for the transcriber, in order.
  func mic(_ buf: AVAudioPCMBuffer, at arrival: Date = Date()) -> [(original: AVAudioPCMBuffer, heard: AVAudioPCMBuffer)] {
    lock.lock(); defer { lock.unlock() }
    let end = micClock.end(of: buf, arrival: arrival.timeIntervalSince1970)
    let start = end - Double(buf.frameLength) / buf.format.sampleRate
    var out: [(original: AVAudioPCMBuffer, heard: AVAudioPCMBuffer)] = []
    // a gap (pause, capture restarted): finish what was waiting, then start again from here
    if decided != nil, start - micEnd > 0.5 {
      out = advance(upTo: Int(micEnd / Self.bin) + 1)
      decided = nil
    }
    micEnd = max(micEnd, add(buf, end: end, to: &mic))
    pending.append((buf, start))
    if decided == nil { decided = Int(start / Self.bin) - 1 }
    return out + advance()
  }

  /// The end of the meeting: everything still waiting, decided with what is known.
  func flush() -> [(original: AVAudioPCMBuffer, heard: AVAudioPCMBuffer)] {
    lock.lock(); defer { lock.unlock() }
    return advance(upTo: Int(micEnd / Self.bin) + 1)
  }

  /// Adds a buffer's samples to 20 ms bins; returns the clock time its audio ends.
  private func add(_ buf: AVAudioPCMBuffer, end: Double, to bins: inout [Int: (sum: Float, n: Int)]) -> Double {
    guard let data = buf.floatChannelData?[0] else { return end }
    let rate = buf.format.sampleRate, n = Int(buf.frameLength)
    let start = end - Double(n) / rate
    var current = Int(start / Self.bin), sum: Float = 0, count = 0
    for i in 0..<n {
      let b = Int((start + Double(i) / rate) / Self.bin)
      if b != current {
        if count > 0 { bins[current, default: (0, 0)].sum += sum; bins[current, default: (0, 0)].n += count }
        current = b; sum = 0; count = 0
      }
      sum += data[i] * data[i]
      count += 1
    }
    if count > 0 { bins[current, default: (0, 0)].sum += sum; bins[current, default: (0, 0)].n += count }
    return end
  }

  private func rms(_ bins: [Int: (sum: Float, n: Int)], _ b: Int) -> Float {
    guard let v = bins[b], v.n > 0 else { return 0 }
    return (v.sum / Float(v.n)).squareRoot()
  }

  /// The echo the call gives in bin b: its loudest recent level fading with the room (the last 80 ms at full level),
  /// a little ahead included.
  private func echo(_ b: Int) -> Float {
    var r: Float = 0
    for k in 1...Self.leadBins { r = max(r, rms(call, b + k)) }
    for k in 0...4 { r = max(r, rms(call, b - k)) }
    var f: Float = 1
    for k in 0..<25 {
      r = max(r, rms(call, b - k) * f)
      f *= Self.decay
    }
    return r
  }

  /// Decides the bins whose next bins are known (or late enough), and lets through the buffers they cover.
  private func advance(upTo forced: Int? = nil) -> [(original: AVAudioPCMBuffer, heard: AVAudioPCMBuffer)] {
    guard var last = decided else { return [] }
    let micDone = Int(micEnd / Self.bin) - 1, callDone = Int(callEnd / Self.bin) - 1
    var target = min(micDone - Self.aheadBins, callDone - Self.aheadBins - Self.leadBins)
    // the call's audio is late (or there is none): go on without it after 300 ms
    if micEnd - callEnd > 0.3 { target = micDone - Self.aheadBins }
    if let forced { target = forced }
    while last < target {
      last += 1
      decide(last)
    }
    decided = last
    var out: [(original: AVAudioPCMBuffer, heard: AVAudioPCMBuffer)] = []
    while let first = pending.first {
      let end = first.start + Double(first.buf.frameLength) / first.buf.format.sampleRate
      guard Int((end - 0.000_001) / Self.bin) <= last else { break }
      pending.removeFirst()
      out.append((first.buf, gated(first.buf, start: first.start)))
    }
    if decidedSincePrune > 500 { prune(before: last - 100); decidedSincePrune = 0 }
    return out
  }

  private func voice(_ b: Int, _ times: Float) -> Bool {
    let m = rms(mic, b)
    return m > floor && m > times * gain * echo(b)
  }

  /// Does bin b show your voice clearly enough to open the gate?
  private func opens(_ b: Int) -> Bool {
    if gain < Self.leakGain { return ((b - Self.leakBins + 1)...b).allSatisfy { voice($0, Self.leakHigh) } }
    return voice(b, Self.high) || steady(b)
  }

  private func steady(_ b: Int) -> Bool {
    guard ((b - Self.steadyBins + 1)...b).allSatisfy({ voice($0, Self.low) }) else { return false }
    let range = (b - Self.followBins + 1)...b
    let x = range.map { log(rms(mic, $0) + 0.0001) }, y = range.map { log(echo($0) + 0.0001) }
    return pearson(x, y) <= Self.follows
  }

  private func decide(_ b: Int) {
    decidedSincePrune += 1
    if b % 25 == 0 { measure(b) }
    let e = echo(b), m = rms(mic, b)
    if e > Self.echoMin {
      ratios.append((b, m / e))
      // the first measure replaces the prior as soon as there is enough, not at the next update: a quick first answer
      // must not be judged against the prior
      if !measured, ratios.count >= Self.gainSamples { measure(b) }
    }
    quiet.append((b, m))
    if (b...(b + Self.aheadBins)).contains(where: { opens($0) }) {
      hold = max(hold, Self.holdBins)
    } else if hold > 0, voice(b, Self.low) {
      hold = max(hold, Self.keepBins)
    }
    open[b] = hold > 0
    Trace.log(String(format: "G %d %.4f %.4f %.3f %.4f", hold > 0 ? 1 : 0, m, e, gain, floor))
    hold = max(0, hold - 1)
  }

  /// The share of the call this microphone picks up, and its own noise, from the last bins.
  private func measure(_ b: Int) {
    ratios.removeAll { $0.bin < b - Self.gainBins }
    if ratios.count >= Self.gainSamples {
      let r = ratios.map(\.r).sorted()
      gain = r[min(r.count - 1, Int(Float(r.count) * Self.gainQuantile))]
      measured = true
    }
    quiet.removeAll { $0.bin < b - 1500 }
    if quiet.count >= 50 {
      let q = quiet.map(\.level).sorted()
      floor = max(Self.minFloor, Self.noiseFactor * q[q.count / 5])
    }
  }

  /// A copy of the buffer, silenced where the gate is closed (5 ms fades).
  private func gated(_ buf: AVAudioPCMBuffer, start: Double) -> AVAudioPCMBuffer {
    guard let out = AVAudioPCMBuffer(pcmFormat: buf.format, frameCapacity: buf.frameLength),
          let src = buf.floatChannelData, let dst = out.floatChannelData else { return buf }
    out.frameLength = buf.frameLength
    let rate = buf.format.sampleRate
    let step = Float(1 / (0.005 * rate))
    for i in 0..<Int(buf.frameLength) {
      let target: Float = open[Int((start + Double(i) / rate) / Self.bin)] ?? true ? 1 : 0
      level = target > level ? min(target, level + step) : max(target, level - step)
      for c in 0..<Int(buf.format.channelCount) { dst[c][i] = src[c][i] * level }
    }
    return out
  }

  private func prune(before b: Int) {
    mic = mic.filter { $0.key >= b }
    call = call.filter { $0.key >= b }
    open = open.filter { $0.key >= b }
  }
}

/// Is the microphone only hearing the call? Pearson correlation of the two loudness envelopes
/// (20 ms bins, last 1.2 s), with the microphone 0–300 ms behind the call.
func envelopesMatch(mic: [Float], call: [Float], threshold: Float = 0.7) -> Bool {
  let n = min(mic.count, call.count)
  guard n >= 20, call.max() ?? 0 > 0.01 else { return false }
  var best: Float = -1
  for lag in 0...15 where n - lag >= 15 {
    let a = Array(mic[lag..<n]), b = Array(call[0..<(n - lag)])
    best = max(best, pearson(a, b))
  }
  return best >= threshold
}

func pearson(_ a: [Float], _ b: [Float]) -> Float {
  let n = Float(a.count)
  let ma = a.reduce(0, +) / n, mb = b.reduce(0, +) / n
  var num: Float = 0, da: Float = 0, db: Float = 0
  for i in a.indices {
    let x = a[i] - ma, y = b[i] - mb
    num += x * y; da += x * x; db += y * y
  }
  return da > 0 && db > 0 ? num / (da * db).squareRoot() : 0
}
