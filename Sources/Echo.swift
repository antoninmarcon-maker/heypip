import Foundation

// Without headphones the microphone also hears the call from the speakers, so « Them » comes back on « You ».
// Two guards, both cheap and local:
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
