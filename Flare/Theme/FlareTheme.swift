import SwiftUI

// MARK: - Tokens

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255,
                  opacity: opacity)
    }
}

enum Theme {
    static let obsidianVoid = Color(hex: 0x07080B)
    static let smokedGlass = Color(hex: 0x12151C)
    static let signalAmber = Color(hex: 0xFF5520)
    static let bountyGold = Color(hex: 0xFFB800)
    static let bioMint = Color(hex: 0x00E599)
    static let crimsonPulse = Color(hex: 0xFF2E54)
    static let vanillaCream = Color(hex: 0xF4F6FA)
    static let mutedAsh = Color(hex: 0x949BA8)
    /// Cooled amber: what the molten orb fades into where it melts into the dock.
    static let cooledGlass = Color(hex: 0x1B1F28)

    static let molten = LinearGradient(colors: [bountyGold, signalAmber], startPoint: .topLeading, endPoint: .bottomTrailing)

    static let spring = Animation.spring(response: 0.46, dampingFraction: 0.74)
    static let snappy = Animation.interpolatingSpring(stiffness: 240, damping: 22)
    static let radius: CGFloat = 32
}

extension Font {
    /// Display headings, numbers, brand. Scales with Dynamic Type.
    static func rounded(_ style: Font.TextStyle, _ weight: Font.Weight = .semibold) -> Font {
        .system(style, design: .rounded, weight: weight)
    }
    /// Countdowns, Spark balances, radar counts only.
    static func mono(_ style: Font.TextStyle, _ weight: Font.Weight = .medium) -> Font {
        .system(style, design: .monospaced, weight: weight)
    }
}

// MARK: - Surfaces & controls

struct GlassBackground: ViewModifier {
    var radius: CGFloat
    var tint: Color?

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        content.background {
            shape.fill(.ultraThinMaterial)
                .overlay(shape.fill(Theme.smokedGlass.opacity(0.8)))
                .overlay(shape.fill((tint ?? .clear).opacity(0.08)))
                .overlay(shape.strokeBorder(
                    LinearGradient(colors: [.white.opacity(0.16), .white.opacity(0.02)], startPoint: .top, endPoint: .bottom),
                    lineWidth: 1))
        }
    }
}

extension View {
    func glass(_ radius: CGFloat = Theme.radius, tint: Color? = nil) -> some View {
        modifier(GlassBackground(radius: radius, tint: tint))
    }
}

struct SquishStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .animation(Theme.snappy, value: configuration.isPressed)
    }
}

struct MoltenButtonStyle: ButtonStyle {
    var tint: Color = Theme.signalAmber
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.rounded(.headline, .bold))
            .foregroundStyle(Theme.obsidianVoid)
            .frame(maxWidth: .infinity, minHeight: 56)
            .padding(.horizontal, 16)
            .background(Capsule().fill(tint)
                .shadow(color: tint.opacity(isEnabled ? 0.45 : 0), radius: configuration.isPressed ? 6 : 16, y: 4))
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .opacity(isEnabled ? 1 : 0.4)
            .animation(Theme.snappy, value: configuration.isPressed)
    }
}

struct Pill: View {
    var text: String
    var icon: String?
    var selected = false
    var tint: Color = Theme.signalAmber

    var body: some View {
        HStack(spacing: 6) {
            if let icon { Image(systemName: icon) }
            Text(text)
        }
        .font(.rounded(.subheadline))
        .foregroundStyle(selected ? Theme.obsidianVoid : Theme.vanillaCream)
        .padding(.horizontal, 16)
        .frame(minHeight: 44)
        .background {
            Capsule().fill(selected ? AnyShapeStyle(tint) : AnyShapeStyle(Theme.smokedGlass))
                .overlay(Capsule().strokeBorder(.white.opacity(selected ? 0 : 0.08)))
        }
        .contentShape(Capsule())
        .animation(Theme.spring, value: selected)
    }
}

struct SectionLabel: View {
    var text: String
    init(_ text: String) { self.text = text }
    var body: some View {
        Text(text.uppercased())
            .font(.rounded(.caption, .bold))
            .tracking(1.2)
            .foregroundStyle(Theme.mutedAsh)
    }
}

/// Wrapping row of pills.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        arrange(width: proposal.width ?? .infinity, subviews: subviews).size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(width: bounds.width, subviews: subviews)
        for (view, origin) in zip(subviews, result.origins) {
            view.place(at: CGPoint(x: bounds.minX + origin.x, y: bounds.minY + origin.y), proposal: .unspecified)
        }
    }

    private func arrange(width: CGFloat, subviews: Subviews) -> (size: CGSize, origins: [CGPoint]) {
        var origins: [CGPoint] = []
        var x: CGFloat = 0, y: CGFloat = 0, rowH: CGFloat = 0, maxX: CGFloat = 0
        for view in subviews {
            let s = view.sizeThatFits(.unspecified)
            if x > 0, x + s.width > width { x = 0; y += rowH + spacing; rowH = 0 }
            origins.append(CGPoint(x: x, y: y))
            x += s.width + spacing
            rowH = max(rowH, s.height)
            maxX = max(maxX, x - spacing)
        }
        return (CGSize(width: maxX, height: y + rowH), origins)
    }
}

// MARK: - Liquid primitives

extension GraphicsContext {
    /// Metaball pass: everything drawn in `body` is blurred, alpha-thresholded so
    /// overlapping blobs fuse like liquid, then painted with `fill`.
    func gooey(blur: CGFloat, fill: GraphicsContext.Shading, in rect: CGRect, _ body: (inout GraphicsContext) -> Void) {
        drawLayer { layer in
            var g = layer
            g.addFilter(.alphaThreshold(min: 0.5, color: .white))
            g.addFilter(.blur(radius: blur))
            g.drawLayer { body(&$0) }
            layer.blendMode = .sourceAtop
            layer.fill(Path(rect), with: fill)
        }
    }

    func blob(_ center: CGPoint, _ r: CGFloat) {
        fill(Path(ellipseIn: CGRect(x: center.x - r, y: center.y - r, width: r * 2, height: r * 2)), with: .color(.white))
    }
}

/// Covers its rect at progress 0; drains downward with a dripping edge as progress → 1.
struct MeltShape: Shape {
    var progress: CGFloat
    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    func path(in r: CGRect) -> Path {
        let drip: CGFloat = 40
        let top = r.minY + progress * (r.height + drip * 2) - drip
        var p = Path()
        p.move(to: CGPoint(x: r.minX, y: r.maxY))
        let steps = 60
        for i in 0...steps {
            let u = CGFloat(i) / CGFloat(steps)
            let wave = max(0, sin(u * .pi * 7) * 0.6 + sin(u * .pi * 13 + 1.3) * 0.4)
            let y = top - wave * wave * drip * min(1, progress * 5)
            p.addLine(to: CGPoint(x: r.minX + r.width * u, y: min(r.maxY, y)))
        }
        p.addLine(to: CGPoint(x: r.maxX, y: r.maxY))
        p.closeSubpath()
        return p
    }
}

/// Viscous horizontal shake; animate `shakes` by +1.
struct ShakeEffect: GeometryEffect {
    var shakes: CGFloat
    var animatableData: CGFloat {
        get { shakes }
        set { shakes = newValue }
    }

    func effectValue(size: CGSize) -> ProjectionTransform {
        let decay = 1 - shakes.truncatingRemainder(dividingBy: 1)
        return ProjectionTransform(CGAffineTransform(translationX: sin(shakes * .pi * 6) * 12 * decay, y: 0))
    }
}

struct LiquidBar: View {
    var progress: Double

    var body: some View {
        TimelineView(.animation) { tl in
            let t = tl.date.timeIntervalSinceReferenceDate
            Canvas { ctx, size in
                let h = size.height
                let edge = size.width * progress
                var p = Path()
                p.move(to: .zero)
                for i in 0...16 {
                    let y = h * Double(i) / 16
                    p.addLine(to: CGPoint(x: edge + sin(y / h * .pi * 2 + t * 3) * 4, y: y))
                }
                p.addLine(to: CGPoint(x: 0, y: h))
                p.closeSubpath()
                ctx.fill(p, with: .linearGradient(Gradient(colors: [Theme.signalAmber, Theme.bountyGold]),
                                                  startPoint: .zero, endPoint: CGPoint(x: size.width, y: 0)))
            }
        }
        .frame(height: 14)
        .background(Theme.obsidianVoid.opacity(0.7))
        .clipShape(Capsule())
        .accessibilityElement()
        .accessibilityValue("\(Int(progress * 100)) percent")
    }
}
