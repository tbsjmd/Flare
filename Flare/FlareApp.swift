import SwiftUI

@main
struct FlareApp: App {
    @State private var store = FlareStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
                .preferredColorScheme(.dark)
        }
    }
}

struct RootView: View {
    @Environment(FlareStore.self) private var store
    @State private var tab = AppTab.radar
    @Namespace private var zoom

    var body: some View {
        @Bindable var store = store
        ZStack {
            Theme.obsidianVoid.ignoresSafeArea()
            if store.s.onboarded {
                ZStack(alignment: .bottom) {
                    Group {
                        switch tab {
                        case .radar: RadarHomeView(zoom: zoom)
                        case .ledger: NHSLedgerView()
                        }
                    }
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
                    .safeAreaInset(edge: .top) {
                        HStack {
                            Spacer()
                            SimPill()
                        }
                        .padding(.horizontal, 16)
                    }
                    GooeyDockView(tab: $tab) { store.showComposer = true }
                }
                .transition(.opacity)
            } else {
                OnboardingView().transition(.opacity)
            }
        }
        .overlay(alignment: .top) { toast }
        .sheet(isPresented: $store.showComposer) {
            FlareComposerSheet().environment(store)
        }
        .fullScreenCover(item: $store.route) { route in
            RescueRoomView(flareID: route.id)
                .environment(store)
                .navigationTransition(.zoom(sourceID: route.id, in: zoom))
        }
        .fullScreenCover(isPresented: $store.showLockScreen) {
            LockScreenPreviewView().environment(store)
        }
        #if DEBUG
        .task { await runDemoStep() }
        #endif
    }

    #if DEBUG
    /// Headless test harness: `simctl launch <device> com.benfriedman.flare -demo <step>`.
    private func runDemoStep() async {
        assert(RescueRoomView.isRawAnswer("B"))
        assert(RescueRoomView.isRawAnswer("the answer is B, trust me on this one"))
        assert(!RescueRoomView.isRawAnswer("Use the product rule on x²y, then collect the y′ terms."))
        let args = ProcessInfo.processInfo.arguments
        guard let i = args.firstIndex(of: "-demo"), i + 1 < args.count else { return }
        let step = args[i + 1]
        if !store.s.onboarded {
            store.assignPersonas(school: "William H. Hall High School", platform: "Canvas")
            store.s.onboarded = true
        }
        try? await Task.sleep(for: .milliseconds(600))
        let first = store.openFlares("calc").first { !$0.responses.isEmpty } ?? store.openFlares("calc")[0]
        switch step {
        case "composer": store.showComposer = true
        case "rescue": store.open(first.id)
        case "ai":
            store.aiRescue(first.id)
            if let r = store.flare(first.id)?.responses.first { store.reveal(first.id, r.id) }
            store.open(first.id)
        case "solve":
            store.respond(first.id, hint: "Differentiate every y-term with the chain rule.", walkthrough: "Product rule on x²y, then move all y′ terms left and factor.")
            store.open(first.id)
            try? await Task.sleep(for: .seconds(1))
            store.solve(first.id)
        case "vault": store.selectedCourseID = "finlit"
        case "ledger": tab = .ledger
        case "lock": store.showLockScreen = true
        case "incoming": store.incomingFlare()
        case "stretch": store.pull = 0.7
        default: break
        }
    }
    #endif

    @ViewBuilder private var toast: some View {
        if let t = store.toast {
            Button {
                if let id = t.flareID { store.open(id) }
                withAnimation(Theme.spring) { store.toast = nil }
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: t.icon).font(.title3).foregroundStyle(t.tint)
                    Text(t.text)
                        .font(.rounded(.subheadline, .semibold))
                        .foregroundStyle(Theme.vanillaCream)
                        .multilineTextAlignment(.leading)
                    Spacer(minLength: 0)
                    if t.flareID != nil { Image(systemName: "chevron.right").foregroundStyle(Theme.mutedAsh) }
                }
                .padding(16)
                .glass(26, tint: t.tint)
            }
            .buttonStyle(SquishStyle())
            .padding(.horizontal, 16)
            .transition(.move(edge: .top).combined(with: .opacity))
        }
    }
}

/// Floating demo control: drives the built-in classmate simulation.
struct SimPill: View {
    @Environment(FlareStore.self) private var store

    var body: some View {
        HStack(spacing: 0) {
            Button {
                withAnimation(Theme.snappy) { store.simOn.toggle() }
                Haptics.tick(0.5)
            } label: {
                HStack(spacing: 6) {
                    Circle().fill(store.simOn ? Theme.bioMint : Theme.mutedAsh).frame(width: 7, height: 7)
                    Text("Live Sim: \(store.simOn ? "ON" : "OFF")")
                }
                .padding(.leading, 14)
                .padding(.trailing, 10)
                .frame(minHeight: 44)
            }
            .accessibilityLabel("Live simulation \(store.simOn ? "on" : "off")")
            Capsule().fill(.white.opacity(0.15)).frame(width: 1, height: 16)
            Button { store.incomingFlare() } label: {
                HStack(spacing: 5) {
                    Image(systemName: "bolt.fill").foregroundStyle(Theme.bountyGold)
                    Text("Trigger Incoming Flare")
                }
                .padding(.leading, 10)
                .padding(.trailing, 14)
                .frame(minHeight: 44)
            }
        }
        .buttonStyle(SquishStyle())
        .font(.rounded(.caption, .semibold))
        .foregroundStyle(Theme.vanillaCream)
        .background(Capsule().fill(Theme.smokedGlass).overlay(Capsule().strokeBorder(.white.opacity(0.1))))
    }
}
