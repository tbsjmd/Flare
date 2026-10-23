import SwiftUI

struct OnboardingView: View {
    @Environment(FlareStore.self) private var store
    @State private var appeared = false
    @State private var query = ""
    @State private var school: String?
    @State private var syncing: String?
    @State private var synced = false
    @State private var gaze = CGPoint.zero

    private let schools = ["William H. Hall High School", "Staples High School", "Conard High School", "New Trier High School"]
    private let platforms = [("Google Classroom", "graduationcap.fill"), ("Canvas", "square.grid.2x2.fill"), ("PowerSchool", "bolt.horizontal.fill")]

    private var filtered: [String] {
        query.isEmpty ? schools : schools.filter { $0.localizedCaseInsensitiveContains(query) }
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 22) {
                WispMascotView(state: synced ? .celebrating : .idle, size: 120, glow: 0.7, gaze: gaze)
                    .scaleEffect(x: appeared ? 1 : 1.8, y: appeared ? 1 : 0.05, anchor: .bottom)
                    .opacity(appeared ? 1 : 0)
                    .padding(.bottom, -56)

                VStack(spacing: 6) {
                    HStack(spacing: 0) {
                        Text("flare").foregroundStyle(Theme.vanillaCream)
                        Text(".").foregroundStyle(Theme.signalAmber)
                    }
                    .font(.system(size: 52, weight: .heavy, design: .rounded))
                    Text("Homework SOS for the 3:00–11:30 PM window.")
                        .font(.rounded(.body, .medium))
                        .foregroundStyle(Theme.mutedAsh)
                        .multilineTextAlignment(.center)
                }

                HStack(spacing: 8) {
                    Image(systemName: "checkmark.shield.fill").foregroundStyle(Theme.bioMint)
                    Text("Zero Room Tracking. Synced by Course & Assignment only.")
                }
                .font(.rounded(.footnote, .semibold))
                .foregroundStyle(Theme.vanillaCream)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .glass(24, tint: Theme.bioMint)

                if synced { personas.transition(.scale(scale: 0.95).combined(with: .opacity)) } else { picker }
            }
            .padding(20)
            .padding(.bottom, 40)
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { v in gaze = CGPoint(x: max(-1, min(1, v.translation.width / 140)), y: max(-1, min(1, v.translation.height / 140))) }
                .onEnded { _ in withAnimation(Theme.spring) { gaze = .zero } }
        )
        .onAppear {
            withAnimation(.spring(response: 0.9, dampingFraction: 0.55).delay(0.15)) { appeared = true }
            Task {
                try? await Task.sleep(for: .milliseconds(250))
                Sound.shared.drip()
            }
        }
    }

    private var picker: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionLabel("Your school")
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass").foregroundStyle(Theme.mutedAsh)
                TextField("Search high schools", text: $query)
                    .font(.rounded(.body))
                    .foregroundStyle(Theme.vanillaCream)
                    .autocorrectionDisabled()
            }
            .padding(.horizontal, 18)
            .frame(minHeight: 52)
            .glass(26)

            FlowLayout {
                ForEach(filtered, id: \.self) { s in
                    Button {
                        withAnimation(Theme.spring) { school = s }
                        Haptics.tick(0.5)
                    } label: {
                        Pill(text: s, icon: "building.columns.fill", selected: school == s)
                    }
                    .buttonStyle(SquishStyle())
                }
            }

            if school != nil {
                SectionLabel("1-tap course sync")
                    .padding(.top, 6)
                ForEach(platforms, id: \.0) { name, icon in
                    Button { sync(name) } label: {
                        HStack(spacing: 12) {
                            Image(systemName: icon).foregroundStyle(Theme.signalAmber).frame(width: 24)
                            Text(name).font(.rounded(.headline)).foregroundStyle(Theme.vanillaCream)
                            Spacer()
                            if syncing == name {
                                Image(systemName: "faceid")
                                    .font(.title2)
                                    .foregroundStyle(Theme.bioMint)
                                    .symbolEffect(.pulse, options: .repeating)
                            } else {
                                Image(systemName: "chevron.right").foregroundStyle(Theme.mutedAsh)
                            }
                        }
                        .padding(.horizontal, 20)
                        .frame(minHeight: 60)
                        .glass(30)
                    }
                    .buttonStyle(SquishStyle())
                    .disabled(syncing != nil)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                Text("Simulated sync. flare. only reads course, teacher and assignment names.")
                    .font(.rounded(.caption))
                    .foregroundStyle(Theme.mutedAsh)
            }
        }
    }

    private var personas: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionLabel("Your anonymous personas")
            VStack(spacing: 0) {
                ForEach(store.s.courses) { c in
                    HStack {
                        Text(c.name).font(.rounded(.subheadline, .semibold)).foregroundStyle(Theme.vanillaCream)
                        Spacer()
                        Text(store.persona(c.id)).font(.rounded(.subheadline, .bold)).foregroundStyle(Theme.bountyGold)
                    }
                    .padding(.vertical, 12)
                }
            }
            .padding(.horizontal, 20)
            .glass()
            Text("A different persona in every class. Nobody sees your name unless you choose to unmask.")
                .font(.rounded(.footnote))
                .foregroundStyle(Theme.mutedAsh)
            Button {
                Haptics.snap()
                store.finishOnboarding()
            } label: {
                Text("Enter the radar")
            }
            .buttonStyle(MoltenButtonStyle())
        }
    }

    private func sync(_ platform: String) {
        guard let school else { return }
        withAnimation(Theme.spring) { syncing = platform }
        Haptics.tick(0.6)
        Task {
            try? await Task.sleep(for: .seconds(1.1))
            store.assignPersonas(school: school, platform: platform)
            withAnimation(Theme.spring) { synced = true }
            Haptics.success()
            Sound.shared.chime()
        }
    }
}
