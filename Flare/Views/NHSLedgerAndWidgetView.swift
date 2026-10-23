import SwiftUI
import UIKit

// MARK: - Spark Ledger → Verified NHS hours

struct NHSLedgerView: View {
    @Environment(FlareStore.self) private var store
    @State private var blurbIndex = 0
    @State private var blurb = ""
    @State private var copied = false
    @State private var confirmReset = false

    private var progress: Double { Double(store.s.lifetimeSparks % 500) / 500 }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Spark Ledger").font(.rounded(.largeTitle, .heavy)).foregroundStyle(Theme.vanillaCream)
                    Text("Every 500 Sparks = 1.0 verified peer-tutoring hour").font(.rounded(.subheadline)).foregroundStyle(Theme.mutedAsh)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                ring
                stats
                commonApp
                widgetCard
                history

                Button("Reset demo data", role: .destructive) { confirmReset = true }
                    .font(.rounded(.footnote, .semibold))
                    .foregroundStyle(Theme.crimsonPulse)
                    .frame(minHeight: 44)
                    .confirmationDialog("Reset all demo data?", isPresented: $confirmReset, titleVisibility: .visible) {
                        Button("Reset", role: .destructive) { store.resetDemo() }
                    } message: {
                        Text("Sparks, Flares and onboarding go back to the starting state.")
                    }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 150)
        }
        .onAppear { if blurb.isEmpty { blurb = makeBlurb(0) } }
    }

    private var ring: some View {
        ZStack {
            Circle().stroke(Color.black.opacity(0.6), lineWidth: 24)
            Circle()
                .trim(from: 0, to: max(0.002, progress))
                .stroke(AngularGradient(colors: [Theme.signalAmber, Theme.bountyGold, Theme.bioMint, Theme.signalAmber], center: .center),
                        style: StrokeStyle(lineWidth: 24, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .shadow(color: Theme.signalAmber.opacity(0.5), radius: 14)
            Circle()
                .fill(Theme.vanillaCream)
                .frame(width: 9, height: 9)
                .offset(y: -110)
                .rotationEffect(.degrees(progress * 360))
            VStack(spacing: 4) {
                Text(String(format: "%.1f", store.hours))
                    .font(.system(size: 60, weight: .bold, design: .monospaced))
                    .foregroundStyle(Theme.vanillaCream)
                    .contentTransition(.numericText())
                Text("Verified NHS Hours").font(.rounded(.subheadline, .semibold)).foregroundStyle(Theme.bioMint)
                Text("\(500 - store.s.lifetimeSparks % 500) to next hr").font(.mono(.caption2)).foregroundStyle(Theme.mutedAsh)
            }
        }
        .frame(width: 220, height: 220)
        .padding(.vertical, 12)
        .animation(Theme.spring, value: progress)
        .accessibilityElement(children: .combine)
    }

    private var stats: some View {
        HStack(spacing: 10) {
            stat("Balance", "\(store.s.sparks)", Theme.bountyGold)
            stat("Lifetime", "\(store.s.lifetimeSparks)", Theme.signalAmber)
            stat("Solved", "\(store.s.solvedCount)", Theme.bioMint)
        }
    }

    private func stat(_ label: String, _ value: String, _ tint: Color) -> some View {
        VStack(spacing: 4) {
            Text(value).font(.mono(.title3, .bold)).foregroundStyle(tint).contentTransition(.numericText())
            Text(label).font(.rounded(.caption, .semibold)).foregroundStyle(Theme.mutedAsh)
        }
        .frame(maxWidth: .infinity, minHeight: 76)
        .glass(24)
        .accessibilityElement(children: .combine)
    }

    private var commonApp: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Common App activity").font(.rounded(.headline, .bold)).foregroundStyle(Theme.vanillaCream)
                Spacer()
                Text("\(blurb.count)/150").font(.mono(.caption, .bold))
                    .foregroundStyle(blurb.count <= 150 ? Theme.bioMint : Theme.crimsonPulse)
            }
            Text(blurb)
                .font(.rounded(.body))
                .foregroundStyle(Theme.vanillaCream)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(.white.opacity(0.05)))
                .contentTransition(.opacity)
            HStack(spacing: 10) {
                Button {
                    blurbIndex += 1
                    withAnimation(Theme.spring) { blurb = makeBlurb(blurbIndex) }
                    Haptics.tick(0.5)
                } label: { Pill(text: "Generate", icon: "wand.and.stars") }
                    .buttonStyle(SquishStyle())
                Button {
                    UIPasteboard.general.string = blurb
                    withAnimation(Theme.spring) { copied = true }
                    Haptics.success()
                    Task {
                        try? await Task.sleep(for: .seconds(1.5))
                        withAnimation(Theme.spring) { copied = false }
                    }
                } label: { Pill(text: copied ? "Copied" : "Copy", icon: copied ? "checkmark" : "doc.on.doc", selected: copied, tint: Theme.bioMint) }
                    .buttonStyle(SquishStyle())
            }
        }
        .padding(20)
        .glass()
    }

    private func makeBlurb(_ i: Int) -> String {
        let h = String(format: "%.1f", store.hours)
        let n = store.s.solvedCount
        let templates = [
            "Anonymous peer tutor on flare.: solved \(n) homework SOS requests with hints, not answers. \(h) verified NHS tutoring hours.",
            "Night-shift peer tutor for AP Calc, APUSH & Chem classmates; Socratic hints only; \(n) Flares solved, \(h) NHS hours verified.",
            "Coached classmates through \(n) stuck problems 3–11:30 PM via flare., teaching setups over answers. \(h) verified service hours.",
        ]
        let t = templates[i % templates.count]
        return t.count <= 150 ? t : String(t.prefix(149)) + "…"
    }

    private var widgetCard: some View {
        Button {
            store.showLockScreen = true
            Haptics.tick(0.5)
        } label: {
            HStack(spacing: 14) {
                Image(systemName: "lock.iphone").font(.title2).foregroundStyle(Theme.signalAmber)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Lock Screen & Dynamic Island").font(.rounded(.headline, .bold)).foregroundStyle(Theme.vanillaCream)
                    Text("Preview Wisp's live class widget").font(.rounded(.footnote)).foregroundStyle(Theme.mutedAsh)
                }
                Spacer()
                Image(systemName: "chevron.right").foregroundStyle(Theme.mutedAsh)
            }
            .padding(20)
            .glass()
        }
        .buttonStyle(SquishStyle())
    }

    private var history: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Verified log").font(.rounded(.headline, .bold)).foregroundStyle(Theme.vanillaCream)
            ForEach(store.s.ledger.prefix(8)) { e in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(e.title).font(.rounded(.subheadline, .semibold)).foregroundStyle(Theme.vanillaCream)
                        Text(e.date, format: .dateTime.month().day().hour().minute()).font(.rounded(.caption)).foregroundStyle(Theme.mutedAsh)
                    }
                    Spacer()
                    Text("+\(e.sparks)").font(.mono(.subheadline, .bold)).foregroundStyle(Theme.bountyGold)
                }
                .padding(.vertical, 4)
                .accessibilityElement(children: .combine)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glass()
    }
}

// MARK: - Lock Screen & Dynamic Island simulator

struct LockScreenPreviewView: View {
    @Environment(FlareStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var expanded = false

    var body: some View {
        let course = store.course.frozen ? store.courseNamed("calc") : store.course
        let open = store.openFlares(course.id)
        ZStack {
            Theme.obsidianVoid.ignoresSafeArea()
            VStack(spacing: 18) {
                phone(course, open)
                Text("Tap the island to expand. Tap the banner to jump into the Rescue Room.")
                    .font(.rounded(.footnote)).foregroundStyle(Theme.mutedAsh).multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 32)
                Button("Done") { dismiss() }
                    .buttonStyle(MoltenButtonStyle())
                    .padding(.horizontal, 40)
            }
            .padding(.vertical, 12)
        }
    }

    private func phone(_ course: Course, _ open: [Flare]) -> some View {
        ZStack(alignment: .top) {
            RoundedRectangle(cornerRadius: 46, style: .continuous)
                .fill(RadialGradient(colors: [Theme.signalAmber.opacity(0.55), Color(hex: 0x1A0A06), .black],
                                     center: .bottom, startRadius: 20, endRadius: 520))
            VStack(spacing: 0) {
                island(course, open)
                    .padding(.top, 10)
                TimelineView(.periodic(from: .now, by: 1)) { tl in
                    VStack(spacing: 0) {
                        Text(tl.date, format: .dateTime.weekday(.wide).month().day())
                            .font(.rounded(.subheadline, .semibold))
                        Text(tl.date, format: .dateTime.hour(.defaultDigits(amPM: .omitted)).minute())
                            .font(.system(size: 72, weight: .bold, design: .rounded))
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                    }
                    .foregroundStyle(Theme.vanillaCream.opacity(0.92))
                }
                .padding(.top, expanded ? 12 : 24)
                HStack(spacing: 14) {
                    gauge("\(course.active)", "active", progress: Double(course.active) / 24)
                    gauge("\(open.count)", "open", progress: Double(open.count) / 8)
                    gauge("\(store.s.sparks)", "sparks", progress: Double(store.s.sparks % 500) / 500)
                }
                .padding(.top, 12)
                Spacer()
                if let f = open.first { banner(f, course) }
            }
            .padding(14)
        }
        .frame(width: 320, height: 640)
        .overlay(RoundedRectangle(cornerRadius: 46, style: .continuous).strokeBorder(.white.opacity(0.15), lineWidth: 2))
    }

    private func island(_ course: Course, _ open: [Flare]) -> some View {
        Button {
            withAnimation(Theme.spring) { expanded.toggle() }
            Haptics.tick(0.5)
        } label: {
            HStack(spacing: 8) {
                WispMascotView(state: expanded ? .celebrating : .idle, size: expanded ? 30 : 16, glow: 0.8)
                    .frame(width: expanded ? 48 : 26, height: expanded ? 56 : 28)
                if expanded {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(course.short).font(.rounded(.subheadline, .bold))
                        Text("\(course.active) Active • \(open.count) Flares Open").font(.mono(.caption, .semibold))
                    }
                    .foregroundStyle(Theme.vanillaCream)
                    .transition(.opacity)
                    Spacer(minLength: 0)
                } else {
                    Text("\(course.short) • \(course.active) • \(open.count)")
                        .font(.mono(.caption2, .semibold))
                        .foregroundStyle(Theme.bountyGold)
                }
            }
            .padding(.horizontal, expanded ? 16 : 10)
            .frame(width: expanded ? 290 : 190, height: expanded ? 78 : 36)
            .background(RoundedRectangle(cornerRadius: expanded ? 30 : 18, style: .continuous).fill(.black))
        }
        .buttonStyle(SquishStyle())
        .accessibilityLabel("Dynamic Island: \(course.short), \(course.active) active, \(open.count) Flares open")
    }

    private func gauge(_ value: String, _ label: String, progress: Double) -> some View {
        ZStack {
            Circle().stroke(.white.opacity(0.15), lineWidth: 5)
            Circle().trim(from: 0, to: min(1, progress)).stroke(Theme.vanillaCream, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                .rotationEffect(.degrees(-90))
            VStack(spacing: 0) {
                Text(value).font(.mono(.caption, .bold)).minimumScaleFactor(0.6)
                Text(label).font(.rounded(.caption2))
            }
            .foregroundStyle(Theme.vanillaCream)
        }
        .frame(width: 60, height: 60)
    }

    private func banner(_ f: Flare, _ course: Course) -> some View {
        Button {
            let id = f.id
            dismiss()
            Task {
                try? await Task.sleep(for: .milliseconds(450))
                store.open(id)
            }
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Theme.obsidianVoid)
                    Image(systemName: "flame.fill").foregroundStyle(Theme.molten)
                }
                .frame(width: 38, height: 38)
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text("flare.").font(.rounded(.caption, .bold))
                        Spacer()
                        Text("now").font(.rounded(.caption2))
                    }
                    .foregroundStyle(Theme.vanillaCream.opacity(0.7))
                    Text("\(f.persona) popped a Flare").font(.rounded(.subheadline, .bold))
                    Text("\(course.short) \(f.problem) · \(course.topic) · \(f.bounty) Sparks").font(.rounded(.caption))
                        .lineLimit(1)
                }
                .foregroundStyle(Theme.vanillaCream)
            }
            .padding(14)
            .glass(24)
        }
        .buttonStyle(SquishStyle())
        .accessibilityHint("Opens the Rescue Room")
    }
}
