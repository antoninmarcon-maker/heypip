import Foundation

// Without headphones the microphone also hears the call from the speakers, so « Them » comes back on « You ».
// Two guards, both cheap and local:
//  - EchoText: a « You » sentence that repeats what « Them » said a moment ago is an echo, not something you said.
//  - Levels.micIsEcho(): the microphone's loudness follows the call's loudness a few hundred ms later.
// Talking over the call still counts as « You »: your voice breaks both the word match and the loudness match.

/// Recent words from « Them », to recognise their echo in what the microphone transcribed.
final class EchoText {
  /// How long a « You » sentence waits before it is written, so « Them »'s words for it have arrived.
  static let wait: TimeInterval = 2
  /// How far back « Them »'s words count.
  static let window: TimeInterval = 8
  private var heard: [(time: Date, words: Set<String>)] = []

  func reset() { heard = [] }

  /// Words « Them » just said (finished sentences and the text still in progress).
  func them(_ text: String, at time: Date = Date()) {
    let w = Set(Self.words(text))
    guard !w.isEmpty else { return }
    heard.append((time, w))
    heard.removeAll { time.timeIntervalSince($0.time) > Self.window + Self.wait }
  }

  /// Is this « You » text, transcribed at `time`, mostly « Them »'s words from just before (or just after)?
  func isEcho(_ text: String, at time: Date = Date()) -> Bool {
    let mine = Self.words(text)
    guard !mine.isEmpty else { return false }
    let theirs = heard.filter { $0.time.timeIntervalSince(time) <= Self.wait && time.timeIntervalSince($0.time) <= Self.window }
      .reduce(into: Set<String>()) { $0.formUnion($1.words) }
    guard !theirs.isEmpty else { return false }
    let found = mine.filter(theirs.contains).count
    // a short « oui » / « d'accord » is only an echo when every word matches
    return mine.count <= 2 ? found == mine.count : Double(found) / Double(mine.count) >= 0.6
  }

  /// Lowercase words without accents or punctuation: « Ça marche ! » → ["ca", "marche"].
  static func words(_ text: String) -> [String] {
    text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
      .split { !$0.isLetter && !$0.isNumber }
      .map(String.init)
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
