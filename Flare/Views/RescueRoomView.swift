import SwiftUI

struct RescueRoomView: View {
    let flareID: UUID

    @Environment(FlareStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var hint = ""
    @State private var walk = ""
    @State private var shakes: CGFloat = 0
    @State private var blocked = false
    @State private var now = Date.now

    /// Short raw answers (or "answer is B") are blocked: responders must teach.
    static func isRawAnswer(_ text: String) -> Bool {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if t.count < 20 { return true }
        return t.range(of: #"(?i)\b(the\s+)?answer\s*(is|=|:)\s*\(?[a-e0-9-]"#, options: .regularExpression) != nil
    }

    var body: some View {
        ZStack {
            Theme.obsidianVoid.ignoresSafeArea()
            if let f = store.flare(flareID) {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {
                        topBar(f)
                        questionCard(f)
                        if !f.solved { timerCard(f) }
                        ForEach(f.responses) { r in responseCard(f, r) }
                        if f.solved {
                            solvedBanner
                        } else {
                            if !f.mine { responder(f) }
                            solveSection(f)
                        }
                    }
                    .padding(16)
                    .padding(.bottom, 40)
                }
            }
            if let pour = store.pour {
                PourOverlay(pour: pour).transition(.opacity)
            }
        }
        .task(id: flareID) {
            while !Task.isCancelled {
                now = .now
                if let f = store.flare(flareID), !f.solved, !f.hasAI, f.aiDeadline <= now { store.aiRescue(flareID) }
                try? await Task.sleep(for: .seconds(1))
            }
        }
    }

    // MARK: Sections

    private func topBar(_ f: Flare) -> some View {
        let course = store.courseNamed(f.courseID)
        return HStack(spacing: 10) {
            Button { dismiss() } label: {
                Image(systemName: "chevron.down").font(.body.weight(.bold)).foregroundStyle(Theme.vanillaCream)
                    .frame(width: 44, height: 44).glass(22)
            }
            .buttonStyle(SquishStyle())
            .accessibilityLabel("Close Rescue Room")
            VStack(alignment: .leading, spacing: 2) {
                Text("Rescue Room").font(.rounded(.headline, .bold)).foregroundStyle(Theme.vanillaCream)
                Text("\(course.short) · \(course.teacher) · \(course.assignment)").font(.rounded(.caption)).foregroundStyle(Theme.mutedAsh)
            }
            Spacer()
            HStack(spacing: 4) {
                Image(systemName: "sparkle")
                Text("\(f.bounty)")
            }
            .font(.mono(.subheadline, .bold))
            .foregroundStyle(Theme.bountyGold)
            .padding(.horizontal, 14)
            .frame(minHeight: 44)
            .glass(22, tint: Theme.bountyGold)
        }
    }

    private func questionCard(_ f: Flare) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Circle().fill(Theme.molten).frame(width: 12, height: 12)
                Text(f.mine ? "You (\(f.persona))" : f.persona).font(.rounded(.subheadline, .semibold)).foregroundStyle(Theme.mutedAsh)
                    .lineLimit(1).minimumScaleFactor(0.7)
                Spacer()
                Text(f.problem).font(.rounded(.caption, .bold)).foregroundStyle(Theme.obsidianVoid)
                    .padding(.horizontal, 10).padding(.vertical, 5).background(Capsule().fill(Theme.signalAmber))
                Label(f.category.rawValue, systemImage: f.category.icon)
                    .font(.rounded(.caption, .bold)).foregroundStyle(Theme.vanillaCream)
                    .lineLimit(1).fixedSize()
                    .padding(.horizontal, 10).padding(.vertical, 5).background(Capsule().fill(.white.opacity(0.08)))
            }
            Text(f.question).font(.rounded(.title3, .bold)).foregroundStyle(Theme.vanillaCream)
            if let snippet = f.snippet {
                Text(snippet)
                    .font(.mono(.callout, .semibold))
                    .foregroundStyle(Theme.bountyGold)
                    .frame(maxWidth: .infinity, minHeight: 64)
                    .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Color.black))
                    .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(.white.opacity(0.08)))
            }
        }
        .padding(20)
        .glass()
    }

    private func timerCard(_ f: Flare) -> some View {
        let remaining = max(0, Int(f.aiDeadline.timeIntervalSince(now)))
        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(f.hasAI ? "Wisp AI stepped in" : "Wisp AI steps in if nobody answers")
                        .font(.rounded(.footnote, .semibold)).foregroundStyle(Theme.mutedAsh)
                    Text(f.hasAI ? "Human bounty still open" : String(format: "%d:%02d", remaining / 60, remaining % 60))
                        .font(.system(f.hasAI ? .headline : .largeTitle, design: .monospaced, weight: .semibold))
                        .foregroundStyle(f.hasAI ? Theme.bioMint : Theme.vanillaCream)
                        .contentTransition(.numericText(countsDown: true))
                        .animation(Theme.snappy, value: remaining)
                }
                Spacer()
                WispMascotView(state: f.hasAI ? .celebrating : (remaining < 60 ? .panicked : .idle), size: 40, glow: 0.6)
                    .frame(width: 64, height: 76)
            }
            if !f.hasAI {
                Button { store.aiRescue(f.id) } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "bolt.fill")
                        VStack(alignment: .leading, spacing: 0) {
                            Text("Fast-Forward Timer").font(.rounded(.subheadline, .bold))
                            Text("Trigger AI Socratic Rescue").font(.rounded(.caption))
                        }
                        Spacer()
                    }
                    .foregroundStyle(Theme.bountyGold)
                    .padding(.horizontal, 18)
                    .frame(minHeight: 52)
                    .background(Capsule().strokeBorder(Theme.bountyGold.opacity(0.5)))
                    .contentShape(Capsule())
                }
                .buttonStyle(SquishStyle())
            }
        }
        .padding(20)
        .glass()
    }

    private func responseCard(_ f: Flare, _ r: FlareResponse) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Circle().fill(r.isAI ? AnyShapeStyle(Theme.molten) : AnyShapeStyle(Theme.bioMint)).frame(width: 12, height: 12)
                Text(r.isAI ? "Wisp AI · Socratic Rescue" : (r.isMine ? "\(store.credit(f.courseID)) (you)" : r.author))
                    .font(.rounded(.subheadline, .semibold)).foregroundStyle(Theme.vanillaCream)
                Spacer()
            }
            SectionLabel("1 · Hint / Formula")
            Text(r.hint).font(.rounded(.body)).foregroundStyle(Theme.vanillaCream)
            SectionLabel("2 · Walkthrough")
            Text(r.walkthrough)
                .font(.rounded(.body))
                .foregroundStyle(Theme.vanillaCream)
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .blur(radius: r.revealed ? 0 : 9)
                .overlay {
                    MeltShape(progress: r.revealed ? 1 : 0)
                        .fill(.ultraThinMaterial)
                        .overlay(MeltShape(progress: r.revealed ? 1 : 0).fill(Theme.signalAmber.opacity(0.06)))
                        .allowsHitTesting(false)
                }
                .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(.white.opacity(0.04)))
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .accessibilityHidden(!r.revealed)
            if !r.revealed {
                Button {
                    withAnimation(.spring(response: 1.1, dampingFraction: 0.85)) { store.reveal(f.id, r.id) }
                    Sound.shared.drip()
                    Haptics.tick(0.7)
                } label: {
                    Pill(text: "Tried hint, melt glass to reveal walkthrough", icon: "drop.fill")
                }
                .buttonStyle(SquishStyle())
            }
        }
        .padding(20)
        .glass(tint: r.isAI ? Theme.signalAmber : Theme.bioMint)
        .transition(.scale(scale: 0.9).combined(with: .opacity))
    }

    private func responder(_ f: Flare) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Send a Socratic rescue").font(.rounded(.headline, .bold)).foregroundStyle(Theme.vanillaCream)
            inputField("1 · The Hint / Formula", placeholder: "Visible right away. Point at the idea, not the answer.", text: $hint)
            inputField("2 · The Walkthrough", placeholder: "Frosted until they try your hint. Explain the setup step by step.", text: $walk)
            if blocked {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "hand.raised.fill")
                    Text("flare blocks raw answers. Explain the setup so your classmate actually learns.")
                }
                .font(.rounded(.footnote, .semibold))
                .foregroundStyle(Theme.crimsonPulse)
                .transition(.move(edge: .top).combined(with: .opacity))
                .accessibilityAddTraits(.updatesFrequently)
            }
            Button(action: submit) {
                HStack(spacing: 8) {
                    Image(systemName: "paperplane.fill")
                    Text("Send Rescue")
                }
            }
            .buttonStyle(MoltenButtonStyle(tint: blocked ? Theme.crimsonPulse : Theme.signalAmber))
        }
        .padding(20)
        .glass(tint: blocked ? Theme.crimsonPulse : nil)
        .modifier(ShakeEffect(shakes: shakes))
    }

    private func inputField(_ label: String, placeholder: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                SectionLabel(label)
                Spacer()
                Text("\(text.wrappedValue.count)").font(.mono(.caption2)).foregroundStyle(Theme.mutedAsh)
            }
            TextField(placeholder, text: text, axis: .vertical)
                .lineLimit(2...6)
                .font(.rounded(.body))
                .foregroundStyle(Theme.vanillaCream)
                .padding(14)
                .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(.white.opacity(0.05)))
        }
    }

    private func submit() {
        if Self.isRawAnswer(hint) || Self.isRawAnswer(walk) {
            withAnimation(.easeOut(duration: 0.6)) { shakes += 1 }
            withAnimation(Theme.spring) { blocked = true }
            Sound.shared.buzz()
            Haptics.error()
            return
        }
        store.respond(flareID, hint: hint, walkthrough: walk)
        withAnimation(Theme.spring) { blocked = false }
        hint = ""
        walk = ""
        Sound.shared.chime()
        Haptics.success()
    }

    private func solveSection(_ f: Flare) -> some View {
        @Bindable var store = store
        let iAnswered = f.responses.contains { $0.isMine }
        let canSolve = f.mine ? !f.responses.isEmpty : iAnswered
        return VStack(alignment: .leading, spacing: 14) {
            if !f.mine {
                Toggle(isOn: $store.s.unmasked) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Unmask for class cred").font(.rounded(.subheadline, .semibold)).foregroundStyle(Theme.vanillaCream)
                        Text(store.s.unmasked ? "Credited as \(store.s.displayName)" : "Staying anonymous as \(store.persona(f.courseID))")
                            .font(.rounded(.caption)).foregroundStyle(Theme.mutedAsh)
                            .contentTransition(.opacity)
                    }
                }
                .tint(Theme.bioMint)
            }
            Button { store.solve(f.id) } label: {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.seal.fill")
                    Text("Mark Solved & Award Spark Bounty")
                }
            }
            .buttonStyle(MoltenButtonStyle(tint: Theme.bioMint))
            .disabled(!canSolve)
            if !canSolve {
                Text(f.mine ? "Waiting for a classmate. Wisp AI covers you when the timer hits zero."
                            : "Send a rescue first. In this demo you then play the asker and award the bounty.")
                    .font(.rounded(.caption)).foregroundStyle(Theme.mutedAsh)
            }
        }
        .padding(20)
        .glass()
    }

    private var solvedBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.seal.fill").font(.title2).foregroundStyle(Theme.bioMint)
            VStack(alignment: .leading, spacing: 2) {
                Text("Solved").font(.rounded(.headline, .bold)).foregroundStyle(Theme.vanillaCream)
                Text("Bounty paid. This Flare is closed.").font(.rounded(.footnote)).foregroundStyle(Theme.mutedAsh)
            }
            Spacer()
        }
        .padding(20)
        .glass(tint: Theme.bioMint)
    }
}

// MARK: - Bounty pour

/// Molten Sparks pour from the top into a pool, Wisp celebrates, then it all drains away.
struct PourOverlay: View {
    let pour: Pour

    @Environment(FlareStore.self) private var store
    @State private var start = Date.now

    var body: some View {
        TimelineView(.animation) { tl in
            let e = tl.date.timeIntervalSince(start)
            ZStack {
                Color.black.opacity(min(0.65, e * 1.6)).ignoresSafeArea()
                Canvas { ctx, size in
                    let pool = min(1, e / 1.4) * 140
                    let cx = size.width / 2
                    ctx.gooey(blur: 12,
                              fill: .linearGradient(Gradient(colors: [Theme.bountyGold, Theme.signalAmber]),
                                                    startPoint: .zero, endPoint: CGPoint(x: 0, y: size.height)),
                              in: CGRect(origin: .zero, size: size)) { g in
                        g.fill(Path(CGRect(x: -20, y: size.height - pool, width: size.width + 40, height: pool + 20)), with: .color(.white))
                        for i in 0..<16 {
                            let x = Double(i) / 16 * size.width
                            g.blob(CGPoint(x: x, y: size.height - pool + sin(e * 4 + Double(i)) * 10), 22)
                        }
                        if e < 1.9 {
                            for k in 0..<14 {
                                let ph = (e * 1.3 + Double(k) / 14).truncatingRemainder(dividingBy: 1)
                                g.blob(CGPoint(x: cx + sin(Double(k) * 2.3) * 10, y: ph * (size.height - pool)), 13 - ph * 4)
                            }
                        }
                    }
                }
                .ignoresSafeArea()
                .allowsHitTesting(false)

                VStack(spacing: 10) {
                    WispMascotView(state: .celebrating, size: 110, glow: 1)
                    Text("+\(pour.amount) Sparks")
                        .font(.system(size: 52, weight: .heavy, design: .monospaced))
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                        .padding(.horizontal, 20)
                        .foregroundStyle(Theme.bountyGold)
                        .scaleEffect(min(1, 0.4 + e * 1.2))
                    Text("Bounty poured to \(pour.recipient)")
                        .font(.rounded(.headline))
                        .foregroundStyle(Theme.vanillaCream)
                }
                .opacity(min(1, e * 2.5))
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { withAnimation(Theme.spring) { store.pour = nil } }
        .task {
            try? await Task.sleep(for: .seconds(2.8))
            withAnimation(Theme.spring) { store.pour = nil }
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isModal)
    }
}
