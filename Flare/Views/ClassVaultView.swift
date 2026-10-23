import SwiftUI
import UIKit

/// Frozen class: 5 classmates must join before the radar melts open.
struct ClassVaultView: View {
    let course: Course

    @Environment(FlareStore.self) private var store
    @State private var melt: CGFloat = 0
    @State private var copied = false

    private var link: String { "flare.app/join/" + "\(course.id)-\(course.teacher.split(separator: " ").last ?? "")".uppercased() }

    var body: some View {
        ZStack {
            VStack(spacing: 10) {
                WispMascotView(state: .idle, size: 100, glow: 0.1, frozen: melt == 0)
                Text("\(course.assignment) · \(course.topic)").font(.rounded(.subheadline)).foregroundStyle(Theme.mutedAsh)
            }
            .blur(radius: 8 * (1 - melt))

            card
                .mask(MeltShape(progress: melt))
        }
        .frame(maxWidth: .infinity, minHeight: 440)
    }

    private var card: some View {
        VStack(spacing: 18) {
            Image(systemName: "lock.fill")
                .font(.system(size: 34, weight: .bold))
                .foregroundStyle(Theme.vanillaCream)
                .symbolEffect(.bounce, value: course.joined)
            VStack(spacing: 4) {
                Text("\(course.joined) of 5 Classmates Joined")
                    .font(.mono(.title3, .bold))
                    .foregroundStyle(Theme.vanillaCream)
                    .contentTransition(.numericText())
                Text("to Melt Vault").font(.rounded(.subheadline, .semibold)).foregroundStyle(Theme.mutedAsh)
            }
            HStack(spacing: 10) {
                ForEach(0..<5, id: \.self) { i in
                    Circle()
                        .fill(i < course.joined ? AnyShapeStyle(Theme.molten) : AnyShapeStyle(.white.opacity(0.08)))
                        .frame(width: 22, height: 22)
                        .scaleEffect(i < course.joined ? 1 : 0.8)
                        .shadow(color: Theme.signalAmber.opacity(i < course.joined ? 0.6 : 0), radius: 8)
                }
            }
            .accessibilityElement()
            .accessibilityLabel("\(course.joined) of 5 joined")

            Text("\(course.name) unlocks when 5 classmates are here, so nobody's Flare goes unanswered.")
                .font(.rounded(.footnote))
                .foregroundStyle(Theme.mutedAsh)
                .multilineTextAlignment(.center)

            Button {
                UIPasteboard.general.string = "https://\(link)"
                withAnimation(Theme.spring) { copied = true }
                Haptics.tick(0.6)
                Task {
                    try? await Task.sleep(for: .seconds(1.6))
                    withAnimation(Theme.spring) { copied = false }
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: copied ? "checkmark" : "link")
                    Text(copied ? "Invite link copied" : link).font(.mono(.footnote, .semibold)).lineLimit(1)
                    Spacer(minLength: 0)
                    Image(systemName: "doc.on.doc")
                }
                .foregroundStyle(copied ? Theme.bioMint : Theme.vanillaCream)
                .padding(.horizontal, 18)
                .frame(minHeight: 50)
                .background(Capsule().fill(.white.opacity(0.06)))
                .contentShape(Capsule())
            }
            .buttonStyle(SquishStyle())
            .accessibilityLabel(copied ? "Invite link copied" : "Copy invite link")

            Button(action: join) {
                HStack(spacing: 8) {
                    Image(systemName: "person.badge.plus")
                    Text("Simulate Classmate Joining (+1)")
                }
            }
            .buttonStyle(MoltenButtonStyle())
            .disabled(course.joined >= 5)
        }
        .padding(24)
        .glass(tint: Theme.vanillaCream)
    }

    private func join() {
        guard store.joinVault(course.id) else { return }
        let id = course.id
        Haptics.snap()
        Sound.shared.drip()
        withAnimation(.spring(duration: 1.6, bounce: 0)) {
            melt = 1
        } completion: {
            store.unlockVault(id)
        }
    }
}
