import SwiftUI

struct RadarHomeView: View {
    var zoom: Namespace.ID

    @Environment(FlareStore.self) private var store
    @Namespace private var pillNS
    @State private var selectedMate: Int?

    private let rings: [CGFloat] = [92, 122, 150]

    var body: some View {
        let course = store.course
        ScrollView(showsIndicators: false) {
            VStack(spacing: 20) {
                header(course)
                courseSwitcher
                if course.frozen {
                    ClassVaultView(course: course)
                        .transition(.opacity.combined(with: .scale(scale: 0.96)))
                } else {
                    radar(course)
                    streakBar(course)
                    carousel(course)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 150)
        }
        .scrollClipDisabled()
    }

    // MARK: Header

    private func header(_ course: Course) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                HStack(spacing: 0) {
                    Text("flare").foregroundStyle(Theme.vanillaCream)
                    Text(".").foregroundStyle(Theme.signalAmber)
                }
                .font(.system(size: 36, weight: .heavy, design: .rounded))
                .accessibilityElement(children: .combine)
                .accessibilityLabel("flare")
                Spacer()
                HStack(spacing: 5) {
                    Image(systemName: "sparkle")
                    Text("\(store.s.sparks)")
                        .font(.mono(.subheadline, .bold))
                        .contentTransition(.numericText())
                }
                .foregroundStyle(Theme.bountyGold)
                .padding(.horizontal, 14)
                .frame(minHeight: 44)
                .glass(22)
                .accessibilityElement(children: .combine)
                .accessibilityLabel("\(store.s.sparks) Sparks")
                Button {
                    store.showLockScreen = true
                    Haptics.tick(0.5)
                } label: {
                    Image(systemName: "lock.iphone")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Theme.vanillaCream)
                        .frame(width: 44, height: 44)
                        .glass(22)
                }
                .buttonStyle(SquishStyle())
                .accessibilityLabel("Preview Lock Screen and Dynamic Island")
            }
            Button { store.rotatePersona(course.id) } label: {
                HStack(spacing: 6) {
                    Circle().fill(Theme.molten).frame(width: 8, height: 8)
                    Text("You're \(store.persona(course.id)) in \(course.short)")
                        .contentTransition(.opacity)
                    Image(systemName: "arrow.triangle.2.circlepath")
                }
                .font(.rounded(.footnote, .semibold))
                .foregroundStyle(Theme.mutedAsh)
                .frame(minHeight: 32)
            }
            .buttonStyle(SquishStyle())
            .accessibilityHint("Rotates your anonymous persona for this class")
        }
    }

    // MARK: Course switcher

    private var courseSwitcher: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(store.s.courses) { c in coursePill(c) }
            }
        }
        .scrollClipDisabled()
    }

    private func coursePill(_ c: Course) -> some View {
        let selected = c.id == store.selectedCourseID
        return Button {
            withAnimation(Theme.spring) {
                store.selectedCourseID = c.id
                selectedMate = nil
            }
            Haptics.tick(0.45)
        } label: {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 5) {
                    if c.frozen { Image(systemName: "lock.fill").font(.caption2) }
                    Text(c.name).font(.rounded(.subheadline, .bold))
                }
                Group {
                    if c.frozen {
                        Text("\(c.joined)/5 joined · vault frozen")
                    } else {
                        Text("\(c.active) active · \(store.openFlares(c.id).count) Flares open")
                    }
                }
                .font(.mono(.caption2))
                .opacity(0.8)
                .contentTransition(.numericText())
            }
            .foregroundStyle(selected ? Theme.obsidianVoid : Theme.vanillaCream)
            .padding(.horizontal, 18)
            .padding(.vertical, 10)
            .background {
                if selected {
                    Capsule().fill(c.frozen ? AnyShapeStyle(Theme.vanillaCream) : AnyShapeStyle(Theme.molten))
                        .matchedGeometryEffect(id: "pill", in: pillNS)
                } else {
                    Capsule().fill(Theme.smokedGlass)
                        .overlay(Capsule().strokeBorder(.white.opacity(0.07)))
                }
            }
        }
        .buttonStyle(SquishStyle())
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    // MARK: Radar

    private func radar(_ course: Course) -> some View {
        let mates = course.classmates
        let side: CGFloat = 330
        let center = CGPoint(x: side / 2, y: side / 2)
        return VStack(spacing: 14) {
            TimelineView(.animation) { tl in
                let t = tl.date.timeIntervalSinceReferenceDate
                let points = mates.map { position($0, t: t, center: center) }
                ZStack {
                    ForEach(0..<3, id: \.self) { k in
                        Circle()
                            .stroke(Theme.signalAmber.opacity(0.16 - Double(k) * 0.04), lineWidth: 1)
                            .frame(width: rings[k] * 2, height: rings[k] * 2)
                            .scaleEffect(1 + 0.03 * sin(t * 1.2 + Double(k)))
                    }
                    Canvas { ctx, size in
                        ctx.gooey(blur: 5,
                                  fill: .radialGradient(Gradient(colors: [Theme.bountyGold, Theme.signalAmber]),
                                                        center: center, startRadius: 60, endRadius: 170),
                                  in: CGRect(origin: .zero, size: size)) { g in
                            for (m, p) in zip(mates, points) {
                                g.blob(p, m.id == selectedMate ? 11 : 7.5)
                                let tail = position(m, t: t - 0.35, center: center)
                                g.blob(tail, 4)
                            }
                        }
                        if let sel = selectedMate, let i = mates.firstIndex(where: { $0.id == sel }) {
                            let p = points[i]
                            ctx.stroke(Path(ellipseIn: CGRect(x: p.x - 17, y: p.y - 17, width: 34, height: 34)),
                                       with: .color(Theme.vanillaCream.opacity(0.7)), lineWidth: 1.5)
                        }
                    }
                    ForEach(Array(zip(mates, points)), id: \.0.id) { m, p in
                        Button {
                            withAnimation(Theme.spring) { selectedMate = selectedMate == m.id ? nil : m.id }
                            Haptics.tick(0.5)
                            Sound.shared.blip()
                        } label: {
                            Color.clear.frame(width: 44, height: 44).contentShape(Circle())
                        }
                        .position(p)
                        .accessibilityLabel(m.caption)
                    }
                    WispMascotView(state: store.wispState, size: 104,
                                   glow: min(1, Double(course.active) / 20), gaze: gaze(points, mates, t: t, center: center))
                        .offset(y: 104 * 1.9 * 0.08)
                        .allowsHitTesting(false)
                }
                .frame(width: side, height: side)
            }
            .frame(maxWidth: .infinity)
            .animation(Theme.spring, value: mates.count)

            caption(course, mates)
        }
    }

    private func position(_ m: Classmate, t: Double, center: CGPoint) -> CGPoint {
        let speeds = [0.22, -0.14, 0.1]
        let a = m.phase + t * speeds[m.ring]
        let r = rings[m.ring] + sin(t * 1.3 + m.phase) * 4
        return CGPoint(x: center.x + cos(a) * r, y: center.y + sin(a) * r)
    }

    private func gaze(_ points: [CGPoint], _ mates: [Classmate], t: Double, center: CGPoint) -> CGPoint {
        if let sel = selectedMate, let i = mates.firstIndex(where: { $0.id == sel }) {
            return CGPoint(x: (points[i].x - center.x) / 150, y: (points[i].y - center.y) / 150)
        }
        return CGPoint(x: sin(t * 0.5) * 0.4, y: cos(t * 0.37) * 0.25)
    }

    private func caption(_ course: Course, _ mates: [Classmate]) -> some View {
        Group {
            if let sel = selectedMate, let m = mates.first(where: { $0.id == sel }) {
                Text(m.caption)
            } else {
                HStack(spacing: 6) {
                    Text("\(course.active)").font(.mono(.subheadline, .bold)).contentTransition(.numericText())
                    Text("classmates on \(course.assignment) right now")
                }
            }
        }
        .font(.rounded(.subheadline, .medium))
        .foregroundStyle(Theme.vanillaCream)
        .multilineTextAlignment(.center)
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .glass(24)
        .animation(Theme.spring, value: selectedMate)
    }

    // MARK: Streak

    private func streakBar(_ course: Course) -> some View {
        let remaining = max(0, 2 - course.solvedTonight)
        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "flame.fill").foregroundStyle(Theme.molten)
                Text("\(course.startedPct)% of \(course.short) started \(course.assignment)")
                    .font(.rounded(.subheadline, .bold))
                    .foregroundStyle(Theme.vanillaCream)
            }
            LiquidBar(progress: Double(course.startedPct) / 100)
            Text(remaining > 0
                 ? "Solve \(remaining) more Flare\(remaining == 1 ? "" : "s") before midnight to keep the \(store.s.streakDays)-Day Streak alive."
                 : "Streak secured. \(store.s.streakDays) days and counting.")
                .font(.rounded(.footnote))
                .foregroundStyle(remaining > 0 ? Theme.mutedAsh : Theme.bioMint)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glass()
    }

    // MARK: Carousel

    private func carousel(_ course: Course) -> some View {
        let open = store.openFlares(course.id)
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Open Flares").font(.rounded(.title3, .bold)).foregroundStyle(Theme.vanillaCream)
                Spacer()
                Text("\(open.count)").font(.mono(.subheadline, .bold)).foregroundStyle(Theme.signalAmber)
                    .contentTransition(.numericText())
            }
            if open.isEmpty {
                VStack(spacing: 6) {
                    Image(systemName: "moon.stars.fill").font(.title2).foregroundStyle(Theme.mutedAsh)
                    Text("Quiet night in \(course.short).").font(.rounded(.subheadline, .semibold)).foregroundStyle(Theme.vanillaCream)
                    Text("Pull up the molten orb to pop a Flare.").font(.rounded(.footnote)).foregroundStyle(Theme.mutedAsh)
                }
                .frame(maxWidth: .infinity)
                .padding(24)
                .glass()
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 12) {
                        ForEach(open) { f in
                            Button {
                                Haptics.tick(0.6)
                                store.open(f.id)
                            } label: {
                                FlareCard(flare: f)
                            }
                            .buttonStyle(SquishStyle())
                            .matchedTransitionSource(id: f.id, in: zoom)
                            .transition(.scale(scale: 0.8).combined(with: .opacity))
                        }
                    }
                    .scrollTargetLayout()
                }
                .scrollTargetBehavior(.viewAligned)
                .scrollClipDisabled()
            }
        }
    }
}

struct FlareCard: View {
    let flare: Flare

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Circle().fill(Theme.molten).frame(width: 9, height: 9)
                Text(flare.mine ? "You" : flare.persona)
                    .font(.rounded(.caption, .semibold))
                    .foregroundStyle(Theme.mutedAsh)
                    .lineLimit(1)
                Spacer(minLength: 4)
                HStack(spacing: 3) {
                    Image(systemName: "sparkle")
                    Text("\(flare.bounty)")
                }
                .font(.mono(.caption, .bold))
                .foregroundStyle(Theme.bountyGold)
            }
            Text(flare.question)
                .font(.rounded(.subheadline, .semibold))
                .foregroundStyle(Theme.vanillaCream)
                .lineLimit(3, reservesSpace: true)
                .multilineTextAlignment(.leading)
            HStack(spacing: 6) {
                tag(flare.problem)
                tag(flare.category.rawValue)
                Spacer(minLength: 0)
                if !flare.responses.isEmpty {
                    Image(systemName: "bubble.left.fill").font(.caption2).foregroundStyle(Theme.bioMint)
                    Text("\(flare.responses.count)").font(.mono(.caption2, .bold)).foregroundStyle(Theme.bioMint)
                }
            }
        }
        .padding(18)
        .frame(width: 260)
        .glass(28)
        .accessibilityElement(children: .combine)
    }

    private func tag(_ s: String) -> some View {
        Text(s)
            .font(.rounded(.caption2, .bold))
            .foregroundStyle(Theme.vanillaCream.opacity(0.85))
            .lineLimit(1)
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(Capsule().fill(.white.opacity(0.07)))
    }
}
