import SwiftUI

// Dighouse's own pictures: six line drawings of the trade, the sign that the agent is at work, and the
// small drawings shown where there is nothing yet. All of it is drawn here; none of it is an image file.

/// The six drawings. Each stands for a part of a search.
enum DigIcon: String, CaseIterable {
    /// The whole search: the trowel does the digging.
    case trowel
    /// Deciding what a find is: the brush cleans it so it can be seen.
    case brush
    /// Searching what is published: sifting for what matters.
    case sieve
    /// Checking a flag: a section cut through the soil shows its layers.
    case layers
    /// The bare ground: a mound seen in section.
    case mound
    /// Screening: the survey grid, one square at a time.
    case grid

    /// The name to use wherever an icon is given as text, beside system symbol names.
    var name: String { "dig." + rawValue }

    init?(name: String) {
        guard name.hasPrefix("dig.") else { return nil }
        self.init(rawValue: String(name.dropFirst(4)))
    }
}

/// One drawing as lines on a 24-point grid, scaled to the space it is given and meant to be stroked.
struct DigShape: Shape {
    let icon: DigIcon

    func path(in rect: CGRect) -> Path {
        var p = Path()
        func pt(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x, y: y) }
        /// A grain: a line with no length, which a round line cap draws as a dot.
        func dot(_ x: CGFloat, _ y: CGFloat) { p.move(to: pt(x, y)); p.addLine(to: pt(x, y)) }
        /// The outline of a rounded bar from one point to another, for a handle.
        func bar(_ a: CGPoint, _ b: CGPoint, _ width: CGFloat) {
            var line = Path()
            line.move(to: a)
            line.addLine(to: b)
            p.addPath(line.strokedPath(StrokeStyle(lineWidth: width, lineCap: .round)))
        }
        switch icon {
        case .trowel:
            // The blade points down and to the left; the tang cranks up to the handle.
            p.move(to: pt(3.4, 20.6)); p.addLine(to: pt(6.2, 10.4)); p.addLine(to: pt(13.6, 17.8)); p.closeSubpath()
            p.move(to: pt(9.9, 14.1)); p.addLine(to: pt(12.6, 11.4)); p.addLine(to: pt(14.2, 11.4))
            bar(pt(15.4, 8.6), pt(19.6, 4.4), 3.4)
        case .brush:
            bar(pt(16.0, 8.0), pt(19.8, 4.2), 3.0)
            // The band that holds the bristles, then the bristles flaring to a soft edge.
            p.move(to: pt(13.0, 7.6)); p.addLine(to: pt(16.4, 11.0)); p.addLine(to: pt(14.4, 13.0)); p.addLine(to: pt(11.0, 9.6)); p.closeSubpath()
            p.move(to: pt(11.0, 9.6)); p.addLine(to: pt(4.6, 13.6))
            p.addQuadCurve(to: pt(10.4, 19.4), control: pt(4.4, 19.6))
            p.addLine(to: pt(14.4, 13.0))
            p.move(to: pt(12.7, 11.3)); p.addLine(to: pt(7.6, 16.4))
        case .sieve:
            // A round sieve seen from a little above, with grains falling through.
            p.addEllipse(in: CGRect(x: 3.5, y: 4.6, width: 17, height: 6.4))
            p.move(to: pt(3.5, 7.8)); p.addLine(to: pt(3.5, 11.2))
            p.addCurve(to: pt(20.5, 11.2), control1: pt(3.5, 15.6), control2: pt(20.5, 15.6))
            p.addLine(to: pt(20.5, 7.8))
            p.move(to: pt(8.0, 6.3)); p.addLine(to: pt(16.0, 9.3))
            p.move(to: pt(16.0, 6.3)); p.addLine(to: pt(8.0, 9.3))
            dot(8.6, 18.0); dot(12.0, 20.6); dot(15.4, 18.0)
        case .layers:
            // A section cut through the soil: the frame of the trench face, three layers and a few stones.
            p.addRoundedRect(in: CGRect(x: 3.5, y: 3.8, width: 17, height: 16.6), cornerSize: CGSize(width: 2.2, height: 2.2))
            p.move(to: pt(3.5, 9.0)); p.addCurve(to: pt(20.5, 8.4), control1: pt(8.5, 6.8), control2: pt(14.0, 10.8))
            p.move(to: pt(3.5, 13.4)); p.addCurve(to: pt(20.5, 14.2), control1: pt(9.0, 15.8), control2: pt(15.0, 11.8))
            p.move(to: pt(3.5, 17.4)); p.addLine(to: pt(20.5, 17.2))
            dot(15.4, 6.6); dot(8.0, 11.6); dot(13.6, 15.6)
        case .mound:
            // A mound in section: the ground line, the mound on it, an earlier mound inside, and the subsoil.
            p.move(to: pt(2.5, 16.4)); p.addLine(to: pt(21.5, 16.4))
            p.move(to: pt(5.6, 16.4)); p.addCurve(to: pt(12, 6.6), control1: pt(8.8, 16.4), control2: pt(9.2, 6.6))
            p.addCurve(to: pt(18.4, 16.4), control1: pt(14.8, 6.6), control2: pt(15.2, 16.4))
            p.move(to: pt(8.6, 16.4)); p.addCurve(to: pt(12, 11.2), control1: pt(10.4, 16.4), control2: pt(10.4, 11.2))
            p.addCurve(to: pt(15.4, 16.4), control1: pt(13.6, 11.2), control2: pt(13.6, 16.4))
            dot(6.0, 19.8); dot(12.0, 20.4); dot(18.0, 19.8)
        case .grid:
            // A survey grid of nine squares, with the one being looked at marked.
            p.addRoundedRect(in: CGRect(x: 4, y: 4, width: 16, height: 16), cornerSize: CGSize(width: 1.4, height: 1.4))
            for at in [9.33, 14.67] as [CGFloat] {
                p.move(to: pt(at, 4)); p.addLine(to: pt(at, 20))
                p.move(to: pt(4, at)); p.addLine(to: pt(20, at))
            }
            p.move(to: pt(10.9, 10.9)); p.addLine(to: pt(13.1, 13.1))
            p.move(to: pt(13.1, 10.9)); p.addLine(to: pt(10.9, 13.1))
        }
        let scale = min(rect.width, rect.height) / 24
        return p.applying(CGAffineTransform(translationX: rect.midX - 12 * scale, y: rect.midY - 12 * scale).scaledBy(x: scale, y: scale))
    }
}

/// An icon by name: one of Dighouse's drawings ("dig.trowel") or a system symbol. Size is a type size, as for a font,
/// and the colour is whatever the text around it uses.
struct Glyph: View {
    let name: String
    var size: CGFloat = 13
    var weight: Font.Weight = .regular

    var body: some View {
        if let icon = DigIcon(name: name) {
            DigShape(icon: icon)
                .stroke(style: StrokeStyle(lineWidth: max(1, size * (weight == .regular ? 0.074 : 0.092)), lineCap: .round, lineJoin: .round))
                .frame(width: size * 1.3, height: size * 1.3)
                .accessibilityHidden(true)
        } else {
            Image(systemName: name).font(.system(size: size, weight: weight))
        }
    }
}

/// The sign that the agent is at work: a trowel scraping along the ground and throwing up grains of soil.
extension Label where Title == Text, Icon == Glyph {
    /// A label whose icon may be one of Dighouse's drawings as well as a system symbol.
    init(_ title: String, glyph: String, size: CGFloat = 12) {
        self.init { Text(title) } icon: { Glyph(name: glyph, size: size * Theme.scale) }
    }
}

/// It takes the place of the system spinner everywhere. With Reduce Motion on it holds still.
struct DigIndicator: View {
    /// Its height in points. It is a little under twice as wide.
    var size: CGFloat = 16
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static let period = 1.5

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30, paused: reduceMotion)) { timeline in
            let now = timeline.date.timeIntervalSinceReferenceDate
            let phase = reduceMotion ? 0.36 : now.truncatingRemainder(dividingBy: Self.period) / Self.period
            Canvas { context, area in Self.draw(context, area, phase: phase, still: reduceMotion) }
        }
        .frame(width: size * 1.8, height: size)
        .accessibilityElement()
        .accessibilityLabel("Working")
    }

    /// One frame. The trowel crosses in the first three quarters of the phase, then lifts away and comes back to the start.
    static func draw(_ context: GraphicsContext, _ area: CGSize, phase: Double, still: Bool) {
        let w = area.width, h = area.height
        let ground = h * 0.9, grain = h * 0.075
        func ease(_ t: Double) -> Double { t * t * (3 - 2 * t) }
        let crossing = 0.76
        let across = ease(min(phase / crossing, 1))
        let from = w * 0.06, to = w * 0.66
        let tip = CGPoint(x: from + (to - from) * across, y: ground - grain * 1.6)

        // Six grains of soil lie on the ground. Each hops as the blade passes over it, turning green at the top of its hop.
        let count = 6
        for i in 0..<count {
            let x = w * 0.1 + (w * 0.8) * Double(i) / Double(count - 1)
            // When the tip reaches this grain, as a share of the crossing.
            let reach = min(max((x - from) / (to - from), 0), 1)
            let since = still ? -1 : (phase - reach * crossing * 0.92) / 0.3
            var y = ground - grain, lift = 0.0
            if since > 0, since < 1, x <= to + w * 0.08 {
                lift = sin(.pi * since)
                y -= lift * h * (0.42 + 0.14 * Double((i * 7) % 3))
            }
            let dot = CGRect(x: x - grain, y: y - grain, width: grain * 2, height: grain * 2)
            context.fill(Path(ellipseIn: dot), with: .color(Theme.tan.opacity(0.55 + 0.45 * lift)))
            if lift > 0.05 { context.fill(Path(ellipseIn: dot), with: .color(Theme.green.opacity(lift))) }
        }

        // The trowel fades out at the end of its crossing and back in at the start.
        let alpha = still || phase < crossing ? 1 : phase < crossing + 0.12 ? 1 - (phase - crossing) / 0.12 : (phase - crossing - 0.12) / 0.12
        let at = phase < crossing + 0.12 || still ? tip : CGPoint(x: from, y: tip.y)
        var trowel = context
        trowel.opacity = max(0, min(1, alpha))
        // Along the blade, up and to the right; and across it.
        let u = CGPoint(x: 0.80, y: -0.60), v = CGPoint(x: 0.60, y: 0.80)
        func along(_ a: Double, _ b: Double = 0) -> CGPoint { CGPoint(x: at.x + (u.x * a + v.x * b) * h, y: at.y + (u.y * a + v.y * b) * h) }
        var blade = Path()
        blade.move(to: at); blade.addLine(to: along(0.44, -0.14)); blade.addLine(to: along(0.44, 0.14)); blade.closeSubpath()
        trowel.fill(blade, with: .color(Theme.tan))
        var tang = Path()
        tang.move(to: along(0.42)); tang.addLine(to: along(0.56, -0.07))
        trowel.stroke(tang, with: .color(Theme.tan), style: StrokeStyle(lineWidth: max(1, h * 0.07), lineCap: .round))
        var handle = Path()
        handle.move(to: along(0.60, -0.07)); handle.addLine(to: along(0.90, -0.07))
        trowel.stroke(handle, with: .color(Theme.text.opacity(0.85)), style: StrokeStyle(lineWidth: h * 0.15, lineCap: .round))
    }
}

/// The drawing at the head of a place with nothing in it yet: one of the six, large, on a round of bare ground.
struct EmptyDrawing: View {
    let name: String
    var size: CGFloat = 64

    var body: some View {
        Glyph(name: name, size: size * 0.5)
            .foregroundStyle(Theme.tan)
            .frame(width: size, height: size)
            .background(Circle().fill(Theme.ink.opacity(0.05)))
            .overlay(Circle().strokeBorder(Theme.ink.opacity(0.09)))
    }
}

/// A place in a list with nothing in it yet: a small drawing and one line of words.
struct EmptyLine: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 10) {
            EmptyDrawing(name: icon, size: 34)
            Text(text).font(.system(size: 13 * Theme.scale)).foregroundStyle(Theme.faint).fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 6)
    }
}

