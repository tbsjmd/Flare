import SwiftUI
import Observation

struct Toast: Identifiable, Equatable {
    let id = UUID()
    var text: String
    var icon: String
    var tint: Color
    var flareID: UUID?
}

struct FlareRoute: Identifiable, Hashable { let id: UUID }

struct Pour: Identifiable, Equatable {
    let id = UUID()
    let amount: Int
    let recipient: String
}

/// Everything that survives relaunch.
struct Snapshot: Codable {
    var onboarded = false
    var school: String?
    var platform: String?
    var displayName = "Ben F."
    var unmasked = false
    var sparks = 320
    var lifetimeSparks = 1_240
    var solvedCount = 23
    var streakDays = 14
    var personas: [String: String] = [:]
    var courses = Course.seed
    var flares = Flare.seed()
    var ledger = LedgerEntry.seed
}

@MainActor @Observable
final class FlareStore {
    private static let key = "flare.snapshot.v1"

    var s: Snapshot { didSet { save() } }

    // Transient UI state
    var selectedCourseID = "calc"
    var pull: CGFloat = 0
    var celebrating = false
    var panicked = false
    var simOn = true
    var showComposer = false
    var showLockScreen = false
    var toast: Toast?
    var route: FlareRoute?
    var pour: Pour?

    @ObservationIgnored private var simTask: Task<Void, Never>?

    init() {
        if let data = UserDefaults.standard.data(forKey: Self.key),
           let snap = try? JSONDecoder().decode(Snapshot.self, from: data) {
            s = snap
        } else {
            s = Snapshot()
        }
        startSim()
    }

    private func save() {
        if let data = try? JSONEncoder().encode(s) { UserDefaults.standard.set(data, forKey: Self.key) }
    }

    func resetDemo() {
        withAnimation(Theme.spring) {
            s = Snapshot()
            selectedCourseID = "calc"
        }
    }

    // MARK: Reads

    var course: Course { s.courses.first { $0.id == selectedCourseID } ?? s.courses[0] }
    var unlockedCourses: [Course] { s.courses.filter { !$0.frozen } }

    func openFlares(_ courseID: String) -> [Flare] {
        s.flares.filter { $0.courseID == courseID && !$0.solved }.sorted { $0.createdAt > $1.createdAt }
    }

    func flare(_ id: UUID) -> Flare? { s.flares.first { $0.id == id } }
    private func idx(_ id: UUID) -> Int? { s.flares.firstIndex { $0.id == id } }
    private func courseIdx(_ id: String) -> Int? { s.courses.firstIndex { $0.id == id } }
    func courseNamed(_ id: String) -> Course { s.courses.first { $0.id == id } ?? s.courses[0] }

    func persona(_ courseID: String) -> String { s.personas[courseID] ?? "Cobalt Owl #19" }
    func credit(_ courseID: String) -> String { s.unmasked ? s.displayName : persona(courseID) }

    var hours: Double { Double(s.lifetimeSparks / 50) / 10 }

    var wispState: WispState {
        if celebrating { return .celebrating }
        if pull > 0 { return .stretching(pull) }
        if panicked || openFlares(course.id).count >= 6 { return .panicked }
        return .idle
    }

    // MARK: Onboarding

    func assignPersonas(school: String, platform: String) {
        s.school = school
        s.platform = platform
        var used = Set<String>()
        for c in s.courses {
            var p = Persona.random()
            while used.contains(p) { p = Persona.random() }
            used.insert(p)
            s.personas[c.id] = p
        }
    }

    func finishOnboarding() {
        withAnimation(Theme.spring) { s.onboarded = true }
    }

    func rotatePersona(_ courseID: String) {
        withAnimation(Theme.spring) { s.personas[courseID] = Persona.random() }
        Haptics.tick(0.6)
        Sound.shared.blip()
    }

    // MARK: Flares

    func open(_ id: UUID) {
        guard route == nil else { return }
        route = FlareRoute(id: id)
    }

    @discardableResult
    func sendFlare(courseID: String, problem: String, category: StuckCategory, question: String, snippet: String?, bounty: Int) -> UUID {
        let f = Flare(courseID: courseID, persona: persona(courseID), problem: problem, category: category,
                      question: question, snippet: snippet, bounty: bounty, createdAt: .now, mine: true)
        withAnimation(Theme.spring) {
            s.sparks -= bounty
            s.flares.insert(f, at: 0)
            selectedCourseID = courseID
        }
        return f.id
    }

    func respond(_ id: UUID, hint: String, walkthrough: String) {
        guard let i = idx(id) else { return }
        let r = FlareResponse(author: credit(s.flares[i].courseID), hint: hint, walkthrough: walkthrough, isMine: true)
        withAnimation(Theme.spring) { s.flares[i].responses.append(r) }
    }

    func reveal(_ flareID: UUID, _ responseID: UUID) {
        guard let i = idx(flareID), let r = s.flares[i].responses.firstIndex(where: { $0.id == responseID }) else { return }
        s.flares[i].responses[r].revealed = true
    }

    /// Wisp AI posts a Socratic rescue; the human bounty stays claimable.
    func aiRescue(_ id: UUID) {
        guard let i = idx(id), !s.flares[i].hasAI else { return }
        let rescue = courseNamed(s.flares[i].courseID).rescue
        withAnimation(Theme.spring) {
            s.flares[i].createdAt = min(s.flares[i].createdAt, Date.now.addingTimeInterval(-Flare.aiWindow))
            s.flares[i].responses.append(FlareResponse(author: "Wisp AI", hint: rescue.hint, walkthrough: rescue.walkthrough, isAI: true))
        }
        Sound.shared.drip()
        Haptics.tick(0.8)
    }

    func solve(_ id: UUID) {
        guard let i = idx(id), !s.flares[i].solved else { return }
        let f = s.flares[i]
        let course = courseNamed(f.courseID)
        let recipient: String
        if !f.mine && f.responses.contains(where: \.isMine) {
            recipient = credit(f.courseID)
            s.sparks += f.bounty
            s.lifetimeSparks += f.bounty
            s.solvedCount += 1
            s.ledger.insert(LedgerEntry(date: .now, title: "Solved \(f.problem) · \(course.short)", sparks: f.bounty), at: 0)
        } else if let human = f.responses.last(where: { !$0.isAI && !$0.isMine }) {
            recipient = human.author
        } else {
            recipient = "you (Wisp AI refunds bounties)"
            s.sparks += f.bounty
        }
        withAnimation(Theme.spring) {
            s.flares[i].solved = true
            if let c = courseIdx(f.courseID) {
                s.courses[c].solvedTonight += 1
                if s.courses[c].solvedTonight == 2 { s.streakDays += 1 }
            }
            pour = Pour(amount: f.bounty, recipient: recipient)
        }
        celebrate()
        Sound.shared.chime()
        Haptics.success()
    }

    // MARK: Vault

    /// Returns true when the vault just reached 5/5.
    func joinVault(_ courseID: String) -> Bool {
        guard let c = courseIdx(courseID), s.courses[c].frozen else { return false }
        withAnimation(Theme.spring) { s.courses[c].joined = min(5, s.courses[c].joined + 1) }
        Sound.shared.blip()
        Haptics.tick(0.7)
        return s.courses[c].joined >= 5
    }

    func unlockVault(_ courseID: String) {
        guard let c = courseIdx(courseID) else { return }
        withAnimation(Theme.spring) {
            s.courses[c].frozen = false
            s.courses[c].active = max(s.courses[c].active, s.courses[c].joined)
            s.sparks += 100
            s.lifetimeSparks += 100
            s.ledger.insert(LedgerEntry(date: .now, title: "Pioneer bonus · \(s.courses[c].short) vault", sparks: 100), at: 0)
        }
        showToast(Toast(text: "+100 Pioneer Sparks · \(s.courses[c].short) vault melted", icon: "sparkles", tint: Theme.bountyGold))
        celebrate()
        Sound.shared.chime()
        Haptics.success()
    }

    // MARK: Feedback

    func showToast(_ t: Toast) {
        withAnimation(Theme.spring) { toast = t }
        Task {
            try? await Task.sleep(for: .seconds(4))
            if toast?.id == t.id { withAnimation(Theme.spring) { toast = nil } }
        }
    }

    func celebrate() {
        celebrating = true
        Task {
            try? await Task.sleep(for: .seconds(2.6))
            celebrating = false
        }
    }

    // MARK: Live classmate simulation

    func incomingFlare() {
        let pool = unlockedCourses
        guard let c = pool.first(where: { $0.id == selectedCourseID }) ?? pool.randomElement(),
              let q = c.incoming.randomElement() else { return }
        let f = Flare(courseID: c.id, persona: Persona.random(), problem: q.problem, category: q.category,
                      question: q.question, snippet: c.samples.randomElement(), bounty: [50, 75, 100, 125, 150, 200].randomElement()!,
                      createdAt: .now)
        withAnimation(Theme.spring) {
            s.flares.insert(f, at: 0)
            if s.flares.count > 40 { s.flares.removeLast(s.flares.count - 40) }
        }
        showToast(Toast(text: "Incoming Flare · \(f.persona) · \(c.short) \(f.problem) · \(f.bounty) Sparks",
                        icon: "flame.fill", tint: Theme.signalAmber, flareID: f.id))
        panicked = true
        Task {
            try? await Task.sleep(for: .seconds(2.2))
            panicked = false
        }
        Sound.shared.blip()
        Haptics.tick(0.9)
    }

    private func startSim() {
        simTask = Task { [weak self] in
            var tick = 0
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(4))
                guard let self, self.simOn, self.s.onboarded else { continue }
                tick += 1
                self.simTick(tick)
            }
        }
    }

    private func simTick(_ tick: Int) {
        // A classmate joins or leaves a radar.
        if let c = s.courses.indices.filter({ !s.courses[$0].frozen }).randomElement() {
            let delta = Bool.random() ? 1 : -1
            withAnimation(Theme.spring) { s.courses[c].active = min(24, max(2, s.courses[c].active + delta)) }
        }
        // A classmate answers one of your own Flares.
        if let i = s.flares.firstIndex(where: { $0.mine && !$0.solved && !$0.responses.contains { !$0.isAI }
                                                && Date.now.timeIntervalSince($0.createdAt) > 10 }) {
            let rescue = courseNamed(s.flares[i].courseID).rescue
            let author = Persona.random()
            withAnimation(Theme.spring) {
                s.flares[i].responses.append(FlareResponse(author: author, hint: rescue.hint, walkthrough: rescue.walkthrough))
            }
            showToast(Toast(text: "\(author) answered your Flare", icon: "bubble.left.and.text.bubble.right.fill",
                            tint: Theme.bioMint, flareID: s.flares[i].id))
            Sound.shared.chime()
        }
        if tick % 5 == 0 { incomingFlare() }
    }
}
