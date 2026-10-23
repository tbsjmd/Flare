import Foundation

enum StuckCategory: String, Codable, CaseIterable, Identifiable {
    case setup = "Setup / Formula"
    case concept = "Concept"
    case calculation = "Calculation Error"

    var id: String { rawValue }
    var icon: String {
        switch self {
        case .setup: "function"
        case .concept: "lightbulb.fill"
        case .calculation: "plusminus"
        }
    }
}

struct Course: Identifiable, Codable, Hashable {
    var id: String
    var name: String
    var short: String
    var teacher: String
    var assignment: String
    var topic: String
    var active: Int
    var joined: Int
    var frozen: Bool
    var startedPct: Int
    var solvedTonight = 0
}

struct FlareResponse: Identifiable, Codable, Hashable {
    var id = UUID()
    var author: String
    var hint: String
    var walkthrough: String
    var isAI = false
    var isMine = false
    var revealed = false
}

struct Flare: Identifiable, Codable, Hashable {
    var id = UUID()
    var courseID: String
    var persona: String
    var problem: String
    var category: StuckCategory
    var question: String
    var snippet: String?
    var bounty: Int
    var createdAt: Date
    var responses: [FlareResponse] = []
    var solved = false
    var mine = false

    static let aiWindow: TimeInterval = 8 * 60
    var aiDeadline: Date { createdAt.addingTimeInterval(Self.aiWindow) }
    var hasAI: Bool { responses.contains { $0.isAI } }
}

struct LedgerEntry: Identifiable, Codable, Hashable {
    var id = UUID()
    var date: Date
    var title: String
    var sparks: Int
}

struct Classmate: Identifiable, Hashable {
    let id: Int
    let persona: String
    let activity: String
    let minutes: Int
    let ring: Int
    let phase: Double

    var caption: String { "\(persona) is \(activity) for \(minutes)m." }
}

// MARK: - Personas

enum Persona {
    static let adjectives = ["Cobalt", "Vortex", "Ember", "Lunar", "Quartz", "Saffron", "Velvet", "Nova", "Static", "Prism", "Mossy", "Neon"]
    static let animals = ["Owl", "Badger", "Lynx", "Heron", "Fox", "Otter", "Moth", "Koi", "Falcon", "Panda", "Gecko", "Wren"]

    static func make(_ seed: Int) -> String {
        let h = abs(seed)
        return "\(adjectives[h % adjectives.count]) \(animals[(h / 7) % animals.count]) #\(String(format: "%02d", h % 97 + 1))"
    }

    static func random() -> String { make(Int.random(in: 0..<1_000_000)) }
}

// MARK: - Seed content

extension Course {
    static let seed: [Course] = [
        Course(id: "calc", name: "AP Calculus AB", short: "AP Calc", teacher: "Mr. Alvarez", assignment: "Problem Set #7", topic: "Implicit Diff", active: 16, joined: 5, frozen: false, startedPct: 82),
        Course(id: "apush", name: "AP US History", short: "APUSH", teacher: "Ms. Okafor", assignment: "DBQ Draft", topic: "Reconstruction", active: 11, joined: 5, frozen: false, startedPct: 64),
        Course(id: "chem", name: "Honors Chemistry", short: "H Chem", teacher: "Dr. Patel", assignment: "Lab 4 Worksheet", topic: "Stoichiometry", active: 9, joined: 5, frozen: false, startedPct: 71),
        Course(id: "finlit", name: "Financial Literacy", short: "Fin Lit", teacher: "Mrs. Greene", assignment: "Budget Builder", topic: "Compound Interest", active: 3, joined: 3, frozen: true, startedPct: 40),
    ]

    private static let activities: [String: [String]] = [
        "calc": ["viewing Problem Set #7 (Implicit Diff)", "stuck on Q3", "drafting Q4a", "checking Q1 against the key"],
        "apush": ["sourcing Doc C", "outlining the DBQ thesis", "reading Reconstruction notes", "drafting body paragraph 2"],
        "chem": ["balancing Lab 4 equations", "finding the limiting reagent", "converting grams to moles", "on Q2 percent yield"],
        "finlit": ["building a monthly budget", "on compound interest Q3", "comparing savings accounts"],
    ]

    /// Stable anonymous classmates for the radar (deterministic per course + index).
    var classmates: [Classmate] {
        let base = id.unicodeScalars.reduce(0) { $0 + Int($1.value) }
        let acts = Self.activities[id] ?? ["working on \(assignment)"]
        return (0..<min(active, 18)).map { i in
            let h = (base &* 31 &+ i &* 7919 &+ i &* i &* 131) & 0x7fff_ffff
            return Classmate(id: i, persona: Persona.make(h), activity: acts[h % acts.count],
                             minutes: 3 + h % 41, ring: i % 3, phase: Double(h % 628) / 100)
        }
    }

    /// Socratic text Wisp AI (and simulated classmates) use for this course.
    var rescue: (hint: String, walkthrough: String) {
        switch id {
        case "calc": ("Treat y as a function of x. Every time you differentiate a y-term, the chain rule tags on a dy/dx.",
                      "Differentiate both sides term by term: d/dx(x²y) = 2xy + x²·y′ by the product rule. Do the same for 3xy³, move every y′ term to one side, factor y′ out, then divide.")
        case "apush": ("Source before you argue: who wrote each document, when, and why does that point of view matter?",
                       "Group the docs into 2–3 buckets (political, economic, social). Write one claim per bucket that answers the prompt, cite two docs each, and explain one author's purpose.")
        case "chem": ("Convert every reactant to moles first, then compare against the coefficients in the balanced equation.",
                      "Divide each reactant's moles by its coefficient; the smaller number is the limiting reagent. Use its moles and the mole ratio to get product moles, then convert to grams.")
        default: ("Compound interest is A = P(1 + r/n)^(nt). Name every variable before plugging anything in.",
                  "P is the deposit, r the rate as a decimal, n the compounds per year, t the years. Monthly means n = 12. Compute r/n first, then the exponent nt, then multiply.")
        }
    }

    var samples: [String] {
        switch id {
        case "calc": ["x²y + 3xy³ = 7   find dy/dx", "sin(xy) = y   at (π, 1)", "x² + y² = 25   tangent at (3, 4)"]
        case "apush": ["Doc C · Freedmen's Bureau, 1866", "Prompt: Was Reconstruction a failure?"]
        case "chem": ["2H₂ + O₂ → 2H₂O   5.0 g H₂ · 32 g O₂", "N₂ + 3H₂ → 2NH₃   % yield?"]
        default: ["$2,000 at 4.5%, monthly, 6 yrs", "Budget: $1,200 / mo take-home"]
        }
    }

    /// Questions the live sim pops as incoming Flares.
    var incoming: [(question: String, problem: String, category: StuckCategory)] {
        switch id {
        case "calc": [("Where does the extra dy/dx come from on the y³ term?", "Q2", .concept),
                      ("My tangent slope is undefined at (3, 4). Did I flip something?", "Q4a", .calculation),
                      ("How do I set up Q3 when x and y are multiplied together?", "Q3", .setup)]
        case "apush": [("How many docs do I actually need to cite per paragraph?", "Q1", .setup),
                       ("Is the Freedmen's Bureau doc for or against my thesis?", "Q3", .concept)]
        case "chem": [("Which reactant runs out first in Q2? I get both.", "Q2", .calculation),
                      ("Why do we divide by the coefficient?", "Q1", .concept)]
        default: [("Do I use 4.5 or 0.045 for r?", "Q3", .setup)]
        }
    }
}

extension Flare {
    static func seed(now: Date = .now) -> [Flare] {
        func ago(_ m: Double) -> Date { now.addingTimeInterval(-m * 60) }
        let calc = Course.seed[0].rescue
        return [
            Flare(courseID: "calc", persona: "Cobalt Owl #19", problem: "Q3", category: .setup,
                  question: "How do I even start implicit diff when y is on both sides?",
                  snippet: "x²y + 3xy³ = 7   find dy/dx", bounty: 150, createdAt: ago(5)),
            Flare(courseID: "calc", persona: "Vortex Badger #84", problem: "Q4a", category: .concept,
                  question: "Why does dy/dx get multiplied onto every y term but not the x terms?",
                  snippet: "sin(xy) = y   at (π, 1)", bounty: 120, createdAt: ago(3),
                  responses: [FlareResponse(author: "Ember Lynx #33", hint: calc.hint, walkthrough: calc.walkthrough)]),
            Flare(courseID: "calc", persona: "Lunar Heron #07", problem: "Q1", category: .calculation,
                  question: "Got 2x/3y² but the key says −2x/3y². Where's my sign error?", bounty: 75, createdAt: ago(1)),
            Flare(courseID: "calc", persona: "Quartz Fox #52", problem: "Q2", category: .setup,
                  question: "Tangent line at (1, 2): do I plug the point in before or after solving for y′?", bounty: 200, createdAt: ago(6.5)),
            Flare(courseID: "apush", persona: "Saffron Otter #41", problem: "Q1", category: .setup,
                  question: "What counts as a contextualization sentence for Reconstruction?", bounty: 100, createdAt: ago(4)),
            Flare(courseID: "apush", persona: "Velvet Moth #12", problem: "Q3", category: .concept,
                  question: "How do I use Doc C if it contradicts my thesis?", snippet: "Doc C · Freedmen's Bureau, 1866", bounty: 90, createdAt: ago(2)),
            Flare(courseID: "chem", persona: "Nova Koi #66", problem: "Q2", category: .calculation,
                  question: "Limiting reagent keeps coming out as O₂. Is that right?", snippet: "2H₂ + O₂ → 2H₂O   5.0 g H₂ · 32 g O₂", bounty: 125, createdAt: ago(7)),
            Flare(courseID: "chem", persona: "Static Wren #28", problem: "Q1", category: .concept,
                  question: "Why do we compare moles instead of grams?", bounty: 60, createdAt: ago(2.5)),
            Flare(courseID: "chem", persona: "Prism Gecko #90", problem: "Q4a", category: .setup,
                  question: "Percent yield: which number goes on top?", bounty: 80, createdAt: ago(0.5)),
        ]
    }
}

extension LedgerEntry {
    static let seed: [LedgerEntry] = [
        LedgerEntry(date: .now.addingTimeInterval(-86_400), title: "Solved Q2 · AP Calc", sparks: 150),
        LedgerEntry(date: .now.addingTimeInterval(-2 * 86_400), title: "Solved Q1 · H Chem", sparks: 90),
        LedgerEntry(date: .now.addingTimeInterval(-4 * 86_400), title: "Solved DBQ setup · APUSH", sparks: 120),
    ]
}
