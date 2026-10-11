// Renders Pip into Resources/AppIcon.icns: swiftc -parse-as-library scripts/make-icon.swift Sources/Pip.swift -o /tmp/pip-icon && /tmp/pip-icon
import AppKit
import SwiftUI

struct IconView: View {
  var body: some View {
    ZStack {
      RoundedRectangle(cornerRadius: 230, style: .continuous)
        .fill(LinearGradient(colors: [Color(white: 0.16), Color(white: 0.03)], startPoint: .top, endPoint: .bottom))
        .frame(width: 1024 - 2 * 100, height: 1024 - 2 * 100)
        .shadow(color: .black.opacity(0.35), radius: 24, y: 12)
      Pip(mood: .idle, size: 520).offset(x: 30, y: -10)
    }
    .frame(width: 1024, height: 1024)
  }
}

@main
struct MakeIcon {
  @MainActor static func main() throws {
    let renderer = ImageRenderer(content: IconView())
    renderer.scale = 1
    guard let cg = renderer.cgImage else { fatalError("render failed") }
    let rep = NSBitmapImageRep(cgImage: cg)
    let png = rep.representation(using: .png, properties: [:])!
    let dir = URL(fileURLWithPath: "Resources/AppIcon.iconset")
    try? FileManager.default.removeItem(at: dir)
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    let master = URL(fileURLWithPath: "Resources/icon-1024.png")
    try png.write(to: master)
    for (name, px) in [("16x16", 16), ("16x16@2x", 32), ("32x32", 32), ("32x32@2x", 64), ("128x128", 128), ("128x128@2x", 256),
                       ("256x256", 256), ("256x256@2x", 512), ("512x512", 512), ("512x512@2x", 1024)] {
      let p = Process()
      p.executableURL = URL(fileURLWithPath: "/usr/bin/sips")
      p.arguments = ["-z", "\(px)", "\(px)", master.path, "--out", dir.appendingPathComponent("icon_\(name).png").path]
      p.standardOutput = nil
      try p.run(); p.waitUntilExit()
    }
    print("ok")
  }
}
