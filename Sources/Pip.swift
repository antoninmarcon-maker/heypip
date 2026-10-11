import SwiftUI

/// Pip, our little friend: a blue earbud with eyes. Every state of the app shows on its face.
enum PipMood: Equatable {
  case idle        // ready: floats and blinks
  case preparing   // loading the speech model, starting or stopping: looks up, thinking
  case listening   // recording and someone is talking: sound waves come into its ear
  case quiet       // recording, nobody talking: calm, eyes follow the room
  case paused      // recording paused: asleep, z z z
  case whisper     // the agent has a note: leans in, « … »
  case done        // meeting saved: happy, little check
  case error       // something went wrong: x eyes, red « ! »
}

struct Pip: View {
  var mood: PipMood
  var size: CGFloat = 80

  private let ink = Color(red: 0.06, green: 0.08, blue: 0.25)

  var body: some View {
    TimelineView(.animation(minimumInterval: 1 / 30)) { ctx in
      let t = ctx.date.timeIntervalSinceReferenceDate
      let s = size / 80
      let float: CGFloat = mood == .paused ? CGFloat(sin(t * 1.0)) * 1.2 * s : CGFloat(sin(t * 2.1)) * 2.2 * s
      let bounce: CGFloat = mood == .listening ? CGFloat(abs(sin(t * 7))) * -1.6 * s : 0
      let lean: Double = mood == .whisper ? 9 : (mood == .paused ? -6 : 0)
      ZStack {
        if mood == .listening { waves(t: t, s: s) }
        if mood == .quiet {
          // still listening, nobody talking: one faint wave that breathes
          Arc().stroke(Color(red: 0.47, green: 0.60, blue: 1.0).opacity(0.25 + 0.2 * (0.5 + 0.5 * sin(t * 1.6))), style: StrokeStyle(lineWidth: 2.2 * s, lineCap: .round))
            .frame(width: 18 * s, height: 26 * s).offset(x: -42 * s, y: 4 * s)
        }
        ZStack {
          Capsule()
            .fill(LinearGradient(colors: [palette.mid, palette.dark], startPoint: .top, endPoint: .bottom))
            .frame(width: 14 * s, height: 30 * s)
            .rotationEffect(.degrees(-6))
            .offset(x: 13 * s, y: 30 * s)
          Ellipse()
            .fill(LinearGradient(colors: [palette.light, palette.mid], startPoint: .topLeading, endPoint: .bottomTrailing))
            .frame(width: 70 * s, height: 54 * s)
            .overlay(Ellipse().fill(Color.white.opacity(0.35)).frame(width: 20 * s, height: 9 * s).rotationEffect(.degrees(-20)).offset(x: -15 * s, y: -17 * s))
          Circle().fill(palette.dark.opacity(0.55)).frame(width: 13 * s, height: 13 * s).offset(x: -27 * s, y: 4 * s)
          HStack(spacing: 14 * s) { eye(t: t, s: s); eye(t: t, s: s) }
            .offset(x: 3 * s, y: -2 * s)
          HStack(spacing: 30 * s) {
            Ellipse().fill(Color.pink.opacity(mood == .paused ? 0.3 : 0.55)).frame(width: 9 * s, height: 5 * s)
            Ellipse().fill(Color.pink.opacity(mood == .paused ? 0.3 : 0.55)).frame(width: 9 * s, height: 5 * s)
          }
          .offset(x: 3 * s, y: 9 * s)
          mouth(s: s)
        }
        .rotationEffect(.degrees(lean), anchor: .bottom)
        .offset(y: float + bounce)
        badge(t: t, s: s)
      }
      .frame(width: size * 1.3, height: size)
      .animation(.spring(response: 0.35, dampingFraction: 0.7), value: mood)
    }
  }

  private var palette: (light: Color, mid: Color, dark: Color) {
    switch mood {
    case .paused: return (Color(red: 0.58, green: 0.63, blue: 0.80), Color(red: 0.36, green: 0.42, blue: 0.66), Color(red: 0.26, green: 0.31, blue: 0.52))
    case .error: return (Color(red: 0.62, green: 0.58, blue: 0.95), Color(red: 0.36, green: 0.30, blue: 0.85), Color(red: 0.25, green: 0.20, blue: 0.66))
    default: return (Color(red: 0.47, green: 0.60, blue: 1.0), Color(red: 0.17, green: 0.35, blue: 1.0), Color(red: 0.11, green: 0.24, blue: 0.80))
    }
  }

  // MARK: eyes

  @ViewBuilder private func eye(t: Double, s: CGFloat) -> some View {
    switch mood {
    case .paused:
      Capsule().fill(ink).frame(width: 11 * s, height: 2.2 * s).offset(y: 2 * s)
    case .done:
      HappyArc().stroke(ink, style: StrokeStyle(lineWidth: 2.6 * s, lineCap: .round)).frame(width: 11 * s, height: 6 * s)
    case .error:
      ZStack {
        Capsule().fill(ink).frame(width: 11 * s, height: 2.4 * s).rotationEffect(.degrees(45))
        Capsule().fill(ink).frame(width: 11 * s, height: 2.4 * s).rotationEffect(.degrees(-45))
      }
    default:
      let blink = t.truncatingRemainder(dividingBy: 3.5) < 0.12
      let look: CGPoint = {
        switch mood {
        case .whisper: return CGPoint(x: 2.2, y: 1)
        case .preparing: return CGPoint(x: 1.2, y: -2.4)
        case .quiet: return CGPoint(x: sin(t * 0.5) * 2.2, y: 1)
        default: return CGPoint(x: sin(t * 0.7) * 1.4, y: 1)
        }
      }()
      ZStack {
        Ellipse().fill(Color.white).frame(width: 12 * s, height: (blink ? 1.5 : 14) * s)
        if !blink {
          Circle().fill(ink).frame(width: 7 * s, height: 7 * s).offset(x: look.x * s, y: look.y * s)
          Circle().fill(Color.white).frame(width: 2.4 * s, height: 2.4 * s).offset(x: (look.x + 1.4) * s, y: (look.y - 2) * s)
        }
      }
    }
  }

  // MARK: mouth

  @ViewBuilder private func mouth(s: CGFloat) -> some View {
    switch mood {
    case .whisper:
      Ellipse().fill(ink).frame(width: 6 * s, height: 7 * s).offset(x: 6 * s, y: 13 * s)
    case .error:
      Smile().stroke(ink, style: StrokeStyle(lineWidth: 2.2 * s, lineCap: .round))
        .frame(width: 10 * s, height: 5 * s).rotationEffect(.degrees(180)).offset(x: 3 * s, y: 15 * s)
    case .paused, .preparing:
      Capsule().fill(ink).frame(width: 6 * s, height: 2 * s).offset(x: 3 * s, y: 14 * s)
    case .done:
      Smile().stroke(ink, style: StrokeStyle(lineWidth: 2.4 * s, lineCap: .round))
        .frame(width: 14 * s, height: 7 * s).offset(x: 3 * s, y: 13 * s)
    default:
      Smile().stroke(ink, style: StrokeStyle(lineWidth: 2.2 * s, lineCap: .round))
        .frame(width: 10 * s, height: 5 * s).offset(x: 3 * s, y: 13 * s)
    }
  }

  // MARK: what floats around Pip

  @ViewBuilder private func badge(t: Double, s: CGFloat) -> some View {
    switch mood {
    case .whisper: bubble(t: t, s: s)
    case .paused: sleeping(t: t, s: s)
    case .preparing: thinking(t: t, s: s)
    case .done:
      Image(systemName: "checkmark.circle.fill").font(.system(size: 15 * s, weight: .bold))
        .foregroundStyle(Color.white, Color(red: 0.24, green: 0.78, blue: 0.47)).offset(x: 34 * s, y: -26 * s)
    case .error:
      Text("!").font(.system(size: 14 * s, weight: .black)).foregroundStyle(.white)
        .frame(width: 20 * s, height: 20 * s).background(Circle().fill(Color.red)).offset(x: 34 * s, y: -26 * s)
    default: EmptyView()
    }
  }

  /// Sound arriving into Pip's ear, from the left.
  private func waves(t: Double, s: CGFloat) -> some View {
    ZStack {
      ForEach(0..<3) { i in
        let phase = (t * 0.9 + Double(i) / 3).truncatingRemainder(dividingBy: 1)
        Arc().stroke(Color(red: 0.47, green: 0.60, blue: 1.0).opacity(0.9 * (1 - phase)), style: StrokeStyle(lineWidth: 2.2 * s, lineCap: .round))
          .frame(width: (10 + 22 * (1 - phase)) * s, height: (16 + 26 * (1 - phase)) * s)
          .offset(x: (-34 - 18 * (1 - phase)) * s, y: 4 * s)
      }
    }
  }

  /// « … »: Pip has something to tell you.
  private func bubble(t: Double, s: CGFloat) -> some View {
    HStack(spacing: 3 * s) {
      ForEach(0..<3) { i in
        Circle().fill(Color.white).frame(width: 4.5 * s, height: 4.5 * s)
          .opacity(0.4 + 0.6 * abs(sin(t * 4 + Double(i) * 0.8)))
      }
    }
    .padding(.horizontal, 7 * s).padding(.vertical, 5 * s)
    .background(Capsule().fill(Color(red: 0.17, green: 0.35, blue: 1.0)))
    .offset(x: 36 * s, y: -30 * s)
  }

  /// z z z rising while paused.
  private func sleeping(t: Double, s: CGFloat) -> some View {
    ZStack {
      ForEach(0..<3) { i in
        let phase = (t * 0.45 + Double(i) / 3).truncatingRemainder(dividingBy: 1)
        Text("z").font(.system(size: (8 + 5 * phase) * s, weight: .heavy, design: .rounded))
          .foregroundStyle(Color.white.opacity(1 - phase))
          .offset(x: (28 + 12 * phase) * s, y: (-16 - 26 * phase) * s)
      }
    }
  }

  /// Three dots turning above Pip's head while it gets ready.
  private func thinking(t: Double, s: CGFloat) -> some View {
    ZStack {
      ForEach(0..<3) { i in
        let a = t * 3 + Double(i) * 2.09
        Circle().fill(Color.white.opacity(0.85)).frame(width: 4 * s, height: 4 * s)
          .offset(x: (30 + 7 * cos(a)) * s, y: (-28 + 7 * sin(a)) * s)
      }
    }
  }
}

private struct Smile: Shape {
  func path(in r: CGRect) -> Path {
    var p = Path()
    p.move(to: CGPoint(x: r.minX, y: r.minY))
    p.addQuadCurve(to: CGPoint(x: r.maxX, y: r.minY), control: CGPoint(x: r.midX, y: r.maxY * 1.6))
    return p
  }
}

/// ^ eyes when Pip is happy.
private struct HappyArc: Shape {
  func path(in r: CGRect) -> Path {
    var p = Path()
    p.move(to: CGPoint(x: r.minX, y: r.maxY))
    p.addQuadCurve(to: CGPoint(x: r.maxX, y: r.maxY), control: CGPoint(x: r.midX, y: r.minY - r.height * 0.6))
    return p
  }
}

/// The right half of an ellipse, opening to the right: a sound wave.
private struct Arc: Shape {
  func path(in r: CGRect) -> Path {
    var p = Path()
    p.addArc(center: CGPoint(x: r.maxX, y: r.midY), radius: r.height / 2, startAngle: .degrees(130), endAngle: .degrees(230), clockwise: false)
    return p
  }
}

/// Pip printed in halftone, like the stamps on sachapraljak.com: blue ink dots on the black island, bigger where Pip
/// is darker, white eyes printed on top, the smile left unprinted. Shown next to the notch while no meeting runs.
/// Drawn from Pip's shapes (same 80-unit layout as `Pip`), never animated.
struct PipPrint: View {
  var size: CGFloat = 28

  private static let ink = Color(red: 0.36, green: 0.53, blue: 1.0)

  var body: some View {
    Canvas { ctx, canvas in
      let s = size / 80                              // points per Pip unit
      let step: CGFloat = 1.25 / s                    // one dot every 1.25 pt
      let center = CGPoint(x: canvas.width / 2 - 2 * s, y: canvas.height / 2 - 7 * s)
      var y = -30.0 as CGFloat
      while y <= 47 {
        var x = -37.0 as CGFloat
        while x <= 37 {
          if let tone = Self.tone(x: x, y: y) {
            let r = step * 0.5 * (0.55 + 0.45 * tone) * s
            let p = CGPoint(x: center.x + x * s, y: center.y + y * s)
            ctx.fill(Path(ellipseIn: CGRect(x: p.x - r, y: p.y - r, width: 2 * r, height: 2 * r)), with: .color(Self.ink))
          }
          x += step
        }
        y += step
      }
      // the eyes, printed in white with the pupils left black
      for ex in [-10.0, 16.0] as [CGFloat] {
        let e = CGRect(x: center.x + (ex - 5.5) * s, y: center.y + (-2 - 6.5) * s, width: 11 * s, height: 13 * s)
        ctx.fill(Path(ellipseIn: e), with: .color(.white))
        let pr: CGFloat = 3.6 * s
        let pc = CGPoint(x: center.x + (ex + 1) * s, y: center.y + 0 * s)
        ctx.fill(Path(ellipseIn: CGRect(x: pc.x - pr, y: pc.y - pr, width: 2 * pr, height: 2 * pr)), with: .color(.black))
      }
    }
    .frame(width: size * 1.25, height: size * 1.1)
    .accessibilityLabel("Pip")
  }

  /// How much ink at (x, y) in Pip units (0 = centre of the body): nil = paper, 0 = lightest, 1 = darkest.
  private static func tone(x: CGFloat, y: CGFloat) -> CGFloat? {
    func inEllipse(_ cx: CGFloat, _ cy: CGFloat, _ rx: CGFloat, _ ry: CGFloat) -> Bool {
      let dx = (x - cx) / rx, dy = (y - cy) / ry
      return dx * dx + dy * dy <= 1
    }
    // unprinted: around the eyes (printed in white on top) and the smile
    if inEllipse(-10, -2, 7.5, 8.5) || inEllipse(16, -2, 7.5, 8.5) { return nil }
    let smile = hypot(x - 3, y - 8)
    if smile > 4.5, smile < 7, y > 11 { return nil }

    if inEllipse(0, 0, 35, 27) {
      // light from the top left, a highlight on the forehead
      var t = 0.45 + 0.3 * (y / 27) + 0.15 * (x / 35)
      if inEllipse(-15, -17, 11, 6) { t -= 0.25 }
      return min(1, max(0, t))
    }
    // the stem: a capsule 14 × 30 tilted 6°, below the body on the right
    let a = 6 * CGFloat.pi / 180
    let dx = x - 13, dy = y - 30
    let u = dx * cos(a) - dy * sin(a), v = dx * sin(a) + dy * cos(a)
    let along = min(max(v, -8), 8)
    if hypot(u, v - along) <= 7 { return 0.85 }
    return nil
  }
}
