import SwiftUI

enum WispState: Equatable {
    case idle
    case stretching(CGFloat)
    case panicked
    case celebrating
}

/// Wisp: a sentient droplet of molten amber, drawn as Canvas metaballs.
struct WispMascotView: View {
    var state: WispState = .idle
    var size: CGFloat = 120
    var glow: Double = 0.5
    /// -1...1 in each axis; where the eyes look.
    var gaze: CGPoint = .zero
    var frozen = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(paused: frozen)) { tl in
            let t = tl.date.timeIntervalSinceReferenceDate
            Canvas { ctx, sz in draw(&ctx, sz, t) }
        }
        .frame(width: size * 1.6, height: size * 1.9)
        .shadow(color: (frozen ? Theme.mutedAsh : Theme.signalAmber).opacity(frozen ? 0.15 : 0.3 + glow * 0.5),
                radius: 14 + glow * 28)
        .accessibilityElement()
        .accessibilityLabel("Wisp")
        .accessibilityValue(label)
    }

    private var label: String {
        switch state {
        case .idle: frozen ? "frozen" : "idle"
        case .stretching: "stretching"
        case .panicked: "panicked"
        case .celebrating: "celebrating"
        }
    }

    // MARK: Drawing

    private func draw(_ ctx: inout GraphicsContext, _ sz: CGSize, _ t: Double) {
        let amp = reduceMotion ? 0.25 : 1.0
        let r = size * 0.34
        var stretch: CGFloat = 0, panic = false, party = false
        switch state {
        case .stretching(let p): stretch = min(max(p, 0), 1)
        case .panicked: panic = true
        case .celebrating: party = true
        case .idle: break
        }
        let c = CGPoint(x: sz.width / 2, y: sz.height * 0.42 + (party ? r * 0.35 : 0))
        var blobs: [(CGPoint, CGFloat)] = [(c, r)]

        // Celebrating: melts into a wide happy puddle.
        if party {
            let wob = sin(t * 9) * r * 0.05
            blobs += [(CGPoint(x: c.x - r * 0.62, y: c.y + r * 0.22 + wob), r * 0.72),
                      (CGPoint(x: c.x + r * 0.62, y: c.y + r * 0.22 - wob), r * 0.72)]
        }

        // Orbiting satellites keep the surface rippling.
        let speed = panic ? 2.4 : 0.9
        for i in 0..<4 {
            let a = t * speed * amp + Double(i) * .pi / 2
            let d = r * (0.4 + 0.12 * sin(t * 2.1 + Double(i)) * amp)
            var p = CGPoint(x: c.x + cos(a) * d * (party ? 1.4 : 1), y: c.y + sin(a) * d * (party ? 0.55 : 1))
            if panic {
                p.x += sin(t * 31 + Double(i) * 2) * r * 0.1
                p.y += cos(t * 27 + Double(i)) * r * 0.1
            }
            blobs.append((p, r * 0.62))
        }

        // Flame tip that licks upward.
        if !party {
            let sway = sin(t * 1.7) * r * 0.22 * amp + (panic ? sin(t * 40) * r * 0.1 : 0)
            let tip = CGPoint(x: c.x + sway, y: c.y - r * 0.95 - sin(t * 2.6) * r * 0.1 * amp)
            blobs.append((CGPoint(x: (c.x + tip.x) / 2, y: (c.y + tip.y) / 2), r * 0.6))
            blobs.append((tip, r * 0.4))
            blobs.append((CGPoint(x: tip.x + sway * 0.6, y: tip.y - r * 0.4 - sin(t * 3.3) * r * 0.08), r * 0.2))
        }

        // Idle: a droplet pinches off the bottom and falls away.
        if state == .idle, !frozen, !reduceMotion {
            let ph = (t * 0.33).truncatingRemainder(dividingBy: 1)
            blobs.append((CGPoint(x: c.x + r * 0.28, y: c.y + r * 0.8 + ph * ph * r * 1.4), r * 0.22 * (1 - ph * 0.6)))
        }

        // Stretching: a molten rope pulled toward the dock.
        let len = r * 2.6 * stretch
        if stretch > 0 {
            for k in 1...7 {
                let u = CGFloat(k) / 7
                blobs.append((CGPoint(x: c.x + sin(t * 3 + u * 4) * r * 0.06, y: c.y + len * u),
                              r * (0.55 - 0.28 * u) * (1 + 0.25 * stretch)))
            }
        }

        let colors: [Color] = frozen
            ? [Theme.vanillaCream.opacity(0.7), Theme.mutedAsh.opacity(0.6)]
            : [Theme.bountyGold, Theme.signalAmber, panic ? Theme.crimsonPulse : Theme.signalAmber]
        let rect = CGRect(origin: .zero, size: sz)
        ctx.gooey(blur: r * 0.28,
                  fill: .linearGradient(Gradient(colors: colors),
                                        startPoint: CGPoint(x: c.x, y: c.y - r * 1.6),
                                        endPoint: CGPoint(x: c.x, y: c.y + r * 1.2 + len)),
                  in: rect) { g in
            for (p, rad) in blobs { g.blob(p, rad) }
        }

        // Specular glint.
        ctx.fill(Path(ellipseIn: CGRect(x: c.x - r * 0.62, y: c.y - r * 0.6, width: r * 0.34, height: r * 0.22)),
                 with: .color(.white.opacity(frozen ? 0.25 : 0.35)))

        drawEyes(&ctx, c: c, r: r, t: t, stretch: stretch, panic: panic, party: party)
        if party { drawSparks(&ctx, c: c, r: r, t: t) }
    }

    private func drawEyes(_ ctx: inout GraphicsContext, c: CGPoint, r: CGFloat, t: Double,
                          stretch: CGFloat, panic: Bool, party: Bool) {
        let blink = (t + Double(size) * 0.37).truncatingRemainder(dividingBy: 3.8)
        let open: CGFloat = frozen ? 0.12 : (blink < 0.16 ? abs(blink - 0.08) / 0.08 : 1)
        let w = r * (panic ? 0.24 : 0.2)
        let h = r * (panic ? 0.5 : 0.44) * max(0.12, open)
        let g = CGPoint(x: gaze.x * r * 0.18, y: gaze.y * r * 0.14 + stretch * r * 0.3)
        for side in [-1.0, 1.0] {
            let e = CGPoint(x: c.x + side * r * 0.33 + g.x, y: c.y - r * 0.08 + g.y)
            if party {
                var arc = Path()
                arc.addArc(center: CGPoint(x: e.x, y: e.y + w * 0.6), radius: w,
                           startAngle: .degrees(205), endAngle: .degrees(335), clockwise: false)
                ctx.stroke(arc, with: .color(Theme.vanillaCream), style: StrokeStyle(lineWidth: w * 0.6, lineCap: .round))
            } else {
                ctx.fill(Path(roundedRect: CGRect(x: e.x - w / 2, y: e.y - h / 2, width: w, height: h), cornerRadius: w / 2),
                         with: .color(Theme.vanillaCream))
            }
        }
    }

    private func drawSparks(_ ctx: inout GraphicsContext, c: CGPoint, r: CGFloat, t: Double) {
        for i in 0..<14 {
            let ph = (t * 0.8 + Double(i) * 0.071).truncatingRemainder(dividingBy: 1)
            let a = Double(i) * 2 * .pi / 14 + 0.3
            let d = r * (0.9 + ph * 1.5)
            let s = r * 0.12 * (1 - ph)
            let p = CGPoint(x: c.x + cos(a) * d, y: c.y - abs(sin(a)) * d * 0.9)
            ctx.fill(Path(ellipseIn: CGRect(x: p.x - s, y: p.y - s, width: s * 2, height: s * 2)),
                     with: .color(Theme.bountyGold.opacity(1 - ph)))
        }
    }
}
