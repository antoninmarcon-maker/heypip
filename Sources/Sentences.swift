import Foundation

/// Turns the recogniser's running text into finished sentences, as soon as each one is complete.
///
/// SpeechAnalyzer only finalises text at a pause: someone talking without pause gives one final block
/// every ~10–20 s. The volatile (in-progress) text already contains the finished sentences, so each
/// sentence is written once more speech follows it, and the rest when the block is finalised.
/// We remember how many characters of the block are written (not how many sentences): the recogniser
/// keeps revising its text, and counting sentences loses or repeats some when it does.
final class SentenceSplitter {
  private var offset = 0

  /// Indices just after each sentence end: . ! ? … followed by a space (a lone "2." is a list number).
  static func boundaries(_ chars: [Character]) -> [Int] {
    var ends: [Int] = []
    var start = 0
    for i in chars.indices where ".!?…".contains(chars[i]) {
      let next = i + 1 < chars.count ? chars[i + 1] : " "
      guard next.isWhitespace else { continue }
      let piece = String(chars[start...i]).trimmingCharacters(in: .whitespaces)
      if piece.range(of: #"^\d{1,2}[.)]$"#, options: .regularExpression) != nil { continue }
      ends.append(i + 1)
      start = i + 1
    }
    return ends
  }

  /// Splits a piece of text into sentences, dropping fragments without any letter.
  static func sentences(_ text: String) -> [String] {
    let chars = Array(text)
    var out: [String] = []
    var start = 0
    for end in boundaries(chars) + [chars.count] where end > start {
      let s = String(chars[start..<end]).trimmingCharacters(in: .whitespacesAndNewlines)
      if s.contains(where: \.isLetter) { out.append(s) }
      start = end
    }
    return out
  }

  /// In-progress text: the sentences finished since last time, and the unfinished tail.
  func volatile(_ text: String) -> (new: [String], tail: String) {
    let chars = Array(text)
    let start = snap(chars, min(offset, chars.count))
    guard let last = Self.boundaries(chars).last(where: { $0 > start }) else {
      return ([], String(chars[start...]).trimmingCharacters(in: .whitespaces))
    }
    offset = last
    return (Self.sentences(String(chars[start..<last])), String(chars[last...]).trimmingCharacters(in: .whitespaces))
  }

  /// Final text of a block: what was not written yet. Starts a new block.
  func final(_ text: String) -> [String] {
    let chars = Array(text)
    let start = snap(chars, min(offset, chars.count))
    offset = 0
    return Self.sentences(String(chars[start...]))
  }

  /// If a revision moved the text, don't start in the middle of a word.
  private func snap(_ chars: [Character], _ i: Int) -> Int {
    var i = i
    while i > 0, i < chars.count, !chars[i - 1].isWhitespace, !".!?…".contains(chars[i - 1]) { i += 1 }
    return i
  }
}
