// Renders docs/media/hero.png (README banner) and docs/media/social-preview.png (GitHub social preview, 1280×640).
// With `fr`: hero.fr.png and social-preview.fr.png, for README.fr.md and the French site.
// swiftc -parse-as-library scripts/make-hero.swift Sources/Pip.swift -o /tmp/pip-hero && /tmp/pip-hero [fr]
import AppKit
import SwiftUI

let french = CommandLine.arguments.contains("fr")

struct Hero: View {
  var width: CGFloat = 1400
  var height: CGFloat = 500
  var titleTop: CGFloat = 230
  let blue = Color(red: 0.36, green: 0.55, blue: 1.0)
  var body: some View {
    ZStack(alignment: .top) {
      LinearGradient(colors: [Color(red: 0.07, green: 0.09, blue: 0.20), Color.black], startPoint: .top, endPoint: .bottom)
      // the menu bar and the island coming out of the notch
      Rectangle().fill(Color.white.opacity(0.06)).frame(height: 44)
      UnevenRoundedRectangle(bottomLeadingRadius: 30, bottomTrailingRadius: 30)
        .fill(Color.black)
        .frame(width: 640, height: 150)
        .overlay(
          HStack(spacing: 18) {
            Pip(mood: .whisper, size: 74)
            VStack(alignment: .leading, spacing: 6) {
              Text("Claude").font(.system(size: 19, weight: .semibold)).foregroundStyle(blue)
              Text(french ? "Demande quand ils veulent lancer." : "Ask when they plan to launch.").font(.system(size: 26, weight: .semibold)).foregroundStyle(.white)
            }
            Spacer()
          }
          .padding(.horizontal, 34).padding(.top, 40)
        )
        .shadow(color: blue.opacity(0.25), radius: 40, y: 10)
      VStack(spacing: 14) {
        Text("Pip").font(.system(size: 96, weight: .heavy, design: .rounded)).foregroundStyle(.white)
        Text(french ? "Ton IA te souffle quoi dire pendant tes appels." : "Your AI whispers in your ear during calls.").font(.system(size: 30, weight: .medium)).foregroundStyle(.white.opacity(0.85))
        HStack(spacing: 10) {
          ForEach(french ? ["Vit dans ton encoche", "Transcrit sur ton Mac", "Marche avec Claude Code", "Open source"] : ["Lives in your notch", "Transcribes on your Mac", "Works with Claude Code", "Open source"], id: \.self) { t in
            Text(t).font(.system(size: 17, weight: .medium)).foregroundStyle(.white.opacity(0.8))
              .padding(.horizontal, 14).padding(.vertical, 8)
              .background(Capsule().fill(Color.white.opacity(0.08)))
          }
        }
        .padding(.top, 6)
      }
      .padding(.top, titleTop)
    }
    .frame(width: width, height: height)
  }
}

@main
struct MakeHero {
  @MainActor static func main() throws {
    for (view, file, scale) in [(Hero(), french ? "docs/media/hero.fr.png" : "docs/media/hero.png", 2.0), (Hero(width: 1280, height: 640, titleTop: 270), french ? "docs/media/social-preview.fr.png" : "docs/media/social-preview.png", 1.0)] {
      let r = ImageRenderer(content: view)
      r.scale = scale
      guard let cg = r.cgImage, let png = NSBitmapImageRep(cgImage: cg).representation(using: .png, properties: [:]) else { fatalError() }
      try png.write(to: URL(fileURLWithPath: file))
    }
    print("ok")
  }
}
