import SwiftUI

struct FlareComposerSheet: View {
    @Environment(FlareStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var courseID = ""
    @State private var problem = "Q1"
    @State private var category = StuckCategory.setup
    @State private var question = ""
    @State private var strokes: [Stroke] = []
    @State private var snippet: String?
    @State private var bounty: Double = 100

    private let problems = ["Q1", "Q2", "Q3", "Q4a"]

    private var course: Course { store.courseNamed(courseID) }
    private var canAfford: Bool { store.s.sparks >= Int(bounty) }
    private var canSend: Bool { !question.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && canAfford }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Send a Flare").font(.rounded(.title2, .bold)).foregroundStyle(Theme.vanillaCream)
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark").font(.body.weight(.bold)).foregroundStyle(Theme.mutedAsh)
                        .frame(width: 44, height: 44).glass(22)
                }
                .buttonStyle(SquishStyle())
                .accessibilityLabel("Close")
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 24) {
                    bountyWisp
                    field
                    pills("Course", items: store.unlockedCourses.map { ($0.id, $0.short, nil) }, selected: courseID) { courseID = $0 }
                    pills("Problem", items: problems.map { ($0, $0, nil) }, selected: problem) { problem = $0 }
                    pills("Stuck on", items: StuckCategory.allCases.map { ($0.rawValue, $0.rawValue, $0.icon) }, selected: category.rawValue) {
                        category = StuckCategory(rawValue: $0) ?? .setup
                    }
                    VStack(alignment: .leading, spacing: 10) {
                        SectionLabel("Scratchpad")
                        ScratchpadView(strokes: $strokes, snippet: $snippet, samples: course.samples)
                    }
                    slider
                }
                .padding(20)
            }

            VStack(spacing: 8) {
                if !canAfford {
                    Text("You have \(store.s.sparks) Sparks. Lower the bounty to send.")
                        .font(.rounded(.footnote)).foregroundStyle(Theme.crimsonPulse)
                }
                Button(action: send) {
                    HStack(spacing: 8) {
                        Image(systemName: "flame.fill")
                        Text("Pop Flare · \(Int(bounty)) Sparks")
                    }
                }
                .buttonStyle(MoltenButtonStyle())
                .disabled(!canSend)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
        .background(Theme.obsidianVoid)
        .presentationDetents([.large])
        .presentationCornerRadius(Theme.radius)
        .presentationBackground(Theme.obsidianVoid)
        .presentationDragIndicator(.visible)
        .onAppear {
            courseID = store.course.frozen ? (store.unlockedCourses.first?.id ?? "calc") : store.course.id
        }
    }

    private var bountyWisp: some View {
        let k = (bounty - 25) / 225
        return VStack(spacing: 0) {
            WispMascotView(state: .idle, size: 90, glow: 0.2 + k * 0.8)
                .scaleEffect(0.7 + k * 0.5)
                .animation(Theme.spring, value: bounty)
                .frame(height: 150)
            Text("Wisp glows hotter as your bounty grows")
                .font(.rounded(.caption)).foregroundStyle(Theme.mutedAsh)
        }
        .frame(maxWidth: .infinity)
    }

    private var field: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel("What's stuck?")
            TextField("e.g. How do I start implicit diff when y is on both sides?", text: $question, axis: .vertical)
                .lineLimit(2...4)
                .font(.rounded(.body, .medium))
                .foregroundStyle(Theme.vanillaCream)
                .padding(18)
                .glass(24)
            Text("Posted as \(store.persona(courseID)). Nobody sees your name.")
                .font(.rounded(.caption)).foregroundStyle(Theme.mutedAsh)
        }
    }

    private func pills(_ title: String, items: [(id: String, label: String, icon: String?)], selected: String,
                       pick: @escaping (String) -> Void) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(title)
            FlowLayout {
                ForEach(items, id: \.id) { item in
                    Button {
                        withAnimation(Theme.spring) { pick(item.id) }
                        Haptics.tick(0.4)
                    } label: {
                        Pill(text: item.label, icon: item.icon, selected: item.id == selected)
                    }
                    .buttonStyle(SquishStyle())
                }
            }
        }
    }

    private var slider: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                SectionLabel("Spark bounty")
                Spacer()
                HStack(spacing: 4) {
                    Image(systemName: "sparkle")
                    Text("\(Int(bounty))").contentTransition(.numericText())
                }
                .font(.mono(.headline, .bold))
                .foregroundStyle(Theme.bountyGold)
            }
            Slider(value: $bounty, in: 25...250, step: 25) {
                Text("Spark bounty")
            } minimumValueLabel: {
                Text("25").font(.mono(.caption)).foregroundStyle(Theme.mutedAsh)
            } maximumValueLabel: {
                Text("250").font(.mono(.caption)).foregroundStyle(Theme.mutedAsh)
            }
            .tint(Theme.signalAmber)
            .onChange(of: bounty) { Haptics.tick(0.2 + bounty / 400) }
            Text("Balance: \(store.s.sparks) Sparks").font(.mono(.caption)).foregroundStyle(Theme.mutedAsh)
        }
    }

    private func send() {
        let id = store.sendFlare(courseID: courseID, problem: problem, category: category,
                                 question: question.trimmingCharacters(in: .whitespacesAndNewlines),
                                 snippet: snippet, bounty: Int(bounty))
        Haptics.snap()
        Sound.shared.chime()
        dismiss()
        Task {
            try? await Task.sleep(for: .milliseconds(550))
            store.open(id)
        }
    }
}

// MARK: - Scratchpad

struct Stroke {
    var points: [CGPoint]
    var erase: Bool
}

struct ScratchpadView: View {
    @Binding var strokes: [Stroke]
    @Binding var snippet: String?
    var samples: [String]

    @State private var erasing = false
    @State private var drawing = false
    @State private var sampleIndex = 0

    var body: some View {
        VStack(spacing: 10) {
            Canvas { ctx, size in
                for x in stride(from: 12.0, to: size.width, by: 22) {
                    for y in stride(from: 12.0, to: size.height, by: 22) {
                        ctx.fill(Path(ellipseIn: CGRect(x: x - 0.8, y: y - 0.8, width: 1.6, height: 1.6)),
                                 with: .color(.white.opacity(0.08)))
                    }
                }
                if let snippet {
                    ctx.draw(Text(snippet).font(.mono(.callout, .semibold)).foregroundStyle(Theme.vanillaCream.opacity(0.9)),
                             at: CGPoint(x: size.width / 2, y: 34))
                }
                ctx.drawLayer { layer in
                    for s in strokes {
                        var path = Path()
                        path.addLines(s.points)
                        let style = StrokeStyle(lineWidth: s.erase ? 28 : 3, lineCap: .round, lineJoin: .round)
                        if s.erase {
                            layer.blendMode = .clear
                            layer.stroke(path, with: .color(.black), style: style)
                            layer.blendMode = .normal
                        } else {
                            var glow = layer
                            glow.addFilter(.blur(radius: 5))
                            glow.stroke(path, with: .color(Theme.signalAmber), style: StrokeStyle(lineWidth: 9, lineCap: .round, lineJoin: .round))
                            layer.stroke(path, with: .color(Theme.bountyGold), style: style)
                        }
                    }
                }
            }
            .frame(height: 230)
            .background(Color.black)
            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 28, style: .continuous).strokeBorder(.white.opacity(0.08)))
            .highPriorityGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { v in
                        if drawing {
                            strokes[strokes.count - 1].points.append(v.location)
                        } else {
                            drawing = true
                            strokes.append(Stroke(points: [v.location, v.location], erase: erasing))
                        }
                    }
                    .onEnded { _ in drawing = false }
            )
            .accessibilityLabel("Scratchpad drawing area")

            HStack(spacing: 8) {
                toolButton(icon: "pencil.tip", label: "Ink", active: !erasing) { erasing = false }
                toolButton(icon: "eraser.fill", label: "Eraser", active: erasing) { erasing = true }
                toolButton(icon: "arrow.uturn.backward", label: "Undo", active: false) { if !strokes.isEmpty { strokes.removeLast() } }
                toolButton(icon: "trash", label: "Clear", active: false) { strokes.removeAll(); snippet = nil }
            }
            Button {
                snippet = samples[sampleIndex % max(1, samples.count)]
                sampleIndex += 1
                Haptics.tick(0.5)
                Sound.shared.blip()
            } label: {
                Pill(text: "Load Sample Homework Snippet", icon: "doc.text.viewfinder")
            }
            .buttonStyle(SquishStyle())
        }
    }

    private func toolButton(icon: String, label: String, active: Bool, action: @escaping () -> Void) -> some View {
        Button {
            withAnimation(Theme.snappy) { action() }
            Haptics.tick(0.35)
        } label: {
            Image(systemName: icon)
                .font(.body.weight(.semibold))
                .foregroundStyle(active ? Theme.obsidianVoid : Theme.vanillaCream)
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(Capsule().fill(active ? AnyShapeStyle(Theme.molten) : AnyShapeStyle(Theme.smokedGlass)))
        }
        .buttonStyle(SquishStyle())
        .accessibilityLabel(label)
        .accessibilityAddTraits(active ? .isSelected : [])
    }
}
