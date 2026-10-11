// Renders docs/media/moods.png: every state of Pip (with `fr`: moods.fr.png, for README.fr.md).
// swiftc -parse-as-library scripts/make-moods.swift Sources/Pip.swift -o /tmp/pip-moods && /tmp/pip-moods [fr]
import AppKit
import SwiftUI

let french = CommandLine.arguments.contains("fr")

struct Sheet: View {
  let moods: [(PipMood, String)] = french
    ? [(.idle, "prêt"), (.preparing, "se prépare"), (.listening, "écoute"), (.quiet, "personne ne parle"),
       (.paused, "en pause"), (.whisper, "a une note"), (.done, "enregistré"), (.error, "problème")]
    : [(.idle, "ready"), (.preparing, "getting ready"), (.listening, "listening"), (.quiet, "nobody talking"),
       (.paused, "paused"), (.whisper, "has a note"), (.done, "saved"), (.error, "problem")]
  var body: some View {
    LazyVGrid(columns: Array(repeating: GridItem(.fixed(190)), count: 4), spacing: 26) {
      ForEach(moods, id: \.1) { mood, label in
        VStack(spacing: 10) {
          Pip(mood: mood, size: 92)
          Text(label).font(.system(size: 15, weight: .medium)).foregroundStyle(.white.opacity(0.8))
        }
        .frame(width: 190, height: 170)
        .background(RoundedRectangle(cornerRadius: 20).fill(Color(white: 0.08)))
      }
    }
    .padding(28)
    .background(Color.black)
  }
}

@main
struct MakeMoods {
  @MainActor static func main() throws {
    let r = ImageRenderer(content: Sheet())
    r.scale = 2
    guard let cg = r.cgImage, let png = NSBitmapImageRep(cgImage: cg).representation(using: .png, properties: [:]) else { fatalError() }
    try png.write(to: URL(fileURLWithPath: french ? "docs/media/moods.fr.png" : "docs/media/moods.png"))
    print("ok")
  }
}
