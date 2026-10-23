import SwiftUI

enum AppTab: String, CaseIterable {
    case radar, ledger
    var title: String { self == .radar ? "Radar" : "Ledger" }
    var icon: String { self == .radar ? "dot.radiowaves.left.and.right" : "seal.fill" }
}

/// Bottom dock with a molten orb. Pull the orb up: it stretches out of the dock
/// on a metaball bridge with escalating haptic ticks, then snaps open the composer.
struct GooeyDockView: View {
    @Binding var tab: AppTab
    var onFlare: () -> Void

    @Environment(FlareStore.self) private var store
    @Namespace private var tabNS
    @State private var drag: CGFloat = 0
    @State private var dragging = false
    @State private var snapped = false
    @State private var lastTick = 0
    @State private var releaseLift: CGFloat = 0
    @State private var releaseAt = Date.distantPast

    private let threshold: CGFloat = 150
    private let dockH: CGFloat = 68
    private let orbR: CGFloat = 30
    private let height: CGFloat = 250

    private func lift(for d: CGFloat) -> CGFloat { 170 * (1 - exp(-d / 170)) }

    /// While dragging: follows the finger. After release: damped spring wobble back into the dock.
    private func currentLift(_ now: Date) -> CGFloat {
        if dragging { return lift(for: drag) }
        let dt = now.timeIntervalSince(releaseAt)
        return releaseLift * exp(-dt * 7) * cos(dt * 16)
    }

    var body: some View {
        TimelineView(.animation) { tl in
            let up = currentLift(tl.date)
            let t = tl.date.timeIntervalSinceReferenceDate
            ZStack(alignment: .bottom) {
                Canvas { ctx, size in drawLiquid(&ctx, size, up: up, t: t) }
                    .allowsHitTesting(false)

                HStack {
                    tabButton(.radar)
                    Spacer(minLength: 110)
                    tabButton(.ledger)
                }
                .padding(.horizontal, 36)
                .frame(height: dockH)

                orbHandle
                    .offset(y: -(dockH + 2 - 36) - up)
            }
        }
        .frame(height: height)
    }

    private var orbHandle: some View {
        Image(systemName: "flame.fill")
            .font(.title2.weight(.bold))
            .foregroundStyle(Theme.obsidianVoid.opacity(0.85))
            .frame(width: 72, height: 72)
            .contentShape(Circle())
            .gesture(
                DragGesture(minimumDistance: 4, coordinateSpace: .global)
                    .onChanged { v in
                        dragging = true
                        drag = max(0, -v.translation.height)
                        store.pull = min(1, drag / threshold)
                        let tick = Int(drag / 22)
                        if tick > lastTick { Haptics.tick(0.25 + 0.12 * CGFloat(tick)) }
                        lastTick = tick
                        if drag >= threshold, !snapped {
                            snapped = true
                            Haptics.snap()
                            Sound.shared.drip()
                            release()
                            onFlare()
                        }
                    }
                    .onEnded { _ in
                        if dragging { release() }
                        snapped = false
                    }
            )
            .onTapGesture {
                Haptics.snap()
                Sound.shared.drip()
                onFlare()
            }
            .accessibilityLabel("Send a Flare")
            .accessibilityHint("Pull up or tap to open the composer")
            .accessibilityAddTraits(.isButton)
    }

    private func release() {
        releaseLift = lift(for: drag)
        releaseAt = .now
        dragging = false
        drag = 0
        lastTick = 0
        store.pull = 0
    }

    private func tabButton(_ t: AppTab) -> some View {
        Button {
            withAnimation(Theme.spring) { tab = t }
            Haptics.tick(0.4)
        } label: {
            VStack(spacing: 3) {
                Image(systemName: t.icon).font(.title3)
                Text(t.title).font(.rounded(.caption2, .bold))
                ZStack {
                    if tab == t {
                        Capsule().fill(Theme.signalAmber).frame(width: 14, height: 4)
                            .matchedGeometryEffect(id: "dot", in: tabNS)
                    }
                }
                .frame(height: 4)
            }
            .foregroundStyle(tab == t ? Theme.vanillaCream : Theme.mutedAsh)
            .frame(minWidth: 64, minHeight: 56)
            .contentShape(Rectangle())
        }
        .buttonStyle(SquishStyle())
        .accessibilityLabel(t.title)
        .accessibilityAddTraits(tab == t ? .isSelected : [])
    }

    private func drawLiquid(_ ctx: inout GraphicsContext, _ size: CGSize, up: CGFloat, t: Double) {
        let dockTop = size.height - dockH
        let restY = dockTop - 2
        let orbY = restY - up
        let breathe = sin(t * 2.2) * 1.5
        let stretch = min(1, max(0, up) / 170)
        // Hot at the orb, cooling into glass along the bridge and the dock.
        let reach = orbR + 26 + up * 0.9
        let amberLoc = min(0.9, orbR * 0.95 / reach)

        ctx.gooey(blur: 9,
                  fill: .radialGradient(Gradient(stops: [
                      .init(color: Theme.bountyGold, location: 0),
                      .init(color: Theme.signalAmber, location: amberLoc),
                      .init(color: Theme.cooledGlass, location: 1),
                  ]), center: CGPoint(x: size.width / 2, y: orbY - orbR * 0.3), startRadius: 0, endRadius: reach),
                  in: CGRect(origin: .zero, size: size)) { g in
            let dock = CGRect(x: 16, y: dockTop, width: size.width - 32, height: dockH)
            g.fill(Path(roundedRect: dock, cornerRadius: dockH / 2, style: .continuous), with: .color(.white))
            g.blob(CGPoint(x: size.width / 2, y: orbY), orbR + breathe)
            // Bridge: thins in the middle as it stretches, like pulled toffee.
            if up > 2 {
                for k in 1...6 {
                    let u = CGFloat(k) / 7
                    let y = orbY + (restY - orbY) * u
                    let r = (orbR * 0.8) * (1 - 0.6 * stretch * sin(u * .pi))
                    g.blob(CGPoint(x: size.width / 2 + sin(t * 4 + u * 5) * 2 * stretch, y: y), r)
                }
            }
        }
        let rim = CGRect(x: 16, y: dockTop, width: size.width - 32, height: dockH)
        ctx.stroke(Path(roundedRect: rim, cornerRadius: dockH / 2, style: .continuous),
                   with: .color(.white.opacity(0.07)), lineWidth: 1)
    }
}
