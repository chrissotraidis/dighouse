import SwiftUI

/// The first-project tutorial: six steps on a site everyone knows. Each step is one sentence and one control to press,
/// and the control wears a ring. Where it stands is worked out from the project itself, so leaving and coming back,
/// or quitting the app, resumes at the same step.
enum Tutorial {
    /// The control a step points at.
    enum Target { case start, create, getTerrain, screen, records, notes, review, record }

    struct Step {
        let number: Int
        let title: String
        let words: String
        var target: Target? = nil
        /// The agent is at work and there is nothing to press.
        var working = false
        var done = false
    }

    static let count = 6

    /// Serpent Mound, in an area small enough to fetch in a minute and screen in four tiles.
    static let point = StartingPoint(
        id: "tutorial", kind: .learn, title: "Serpent Mound", place: "Ohio, United States", about: "", source: "USGS 3DEP",
        name: "First project: Serpent Mound",
        question: "How clearly does the serpent show in the bare ground, and is it already published?",
        box: ["-83.43193", "39.02385", "-83.42847", "39.02655"])
}

extension AppState {
    /// The step the tutorial is on, or nil when it is not showing: it is off, or another page or project is open.
    var tutorialStep: Tutorial.Step? {
        guard tutorialOn else { return nil }
        guard let path = tutorialProject, FileManager.default.fileExists(atPath: path + "/PROJECT.md") else {
            guard route == .newProject, draftProject.id == Tutorial.point.id else { return nil }
            return .init(number: 1, title: "Choose the place",
                         words: "Start with a place everyone knows: Serpent Mound in Ohio. Its name, question and area are filled in. Press Create project.",
                         target: .create)
        }
        guard route == .chat, store.current?.path == path else { return nil }
        let working = chat.running
        let unscreened = store.tiles.filter { $0.status == "unscreened" }.count
        if store.candidates.contains(where: { !$0.decisions.isEmpty }) {
            return .init(number: 6, title: "Done",
                         words: "That was a whole search: the ground, the tiles, a find, its record and your decision. Next, try a place nobody has checked, from Home.",
                         done: true)
        }
        if store.tiles.isEmpty {
            return working
                ? .init(number: 2, title: "Get the ground", words: "The agent is downloading the laser scans and taking the trees away. It takes about a minute.", working: true)
                : .init(number: 2, title: "Get the ground", words: "The agent downloads the laser scans for this spot and takes the trees away. Press Get the ground.", target: .getTerrain)
        }
        if working, tutorialReached < 4 {
            return .init(number: 3, title: "Look at the tiles",
                         words: unscreened > 0 || store.candidates.isEmpty ? "The agent is looking at each tile for shapes people built. Its steps show in the chat."
                            : "The agent marked a find and is checking it. Wait for it to finish.", working: true)
        }
        if unscreened > 0 {
            return .init(number: 3, title: "Look at the tiles",
                         words: "The ground is cut into squares called tiles. The agent looks at each one for shapes people built. Press Next: Look at the tiles, at the top.",
                         target: .screen)
        }
        if store.candidates.isEmpty {
            return .init(number: 3, title: "Look at the tiles",
                         words: "The agent looked at every tile and marked nothing this time. Type: look at the tiles again and mark the winding bank.")
        }
        switch max(tutorialReached, 4) {
        case 4:
            return .init(number: 4, title: "Open the find", words: "The agent marked a find. Press Records to see its pictures and how it was checked.", target: .records)
        case 5:
            return .init(number: 5, title: "Read the research record",
                         words: "Everything looked at and read is written in the research record, so anyone can pick this project up. Press Notes.", target: .notes)
        default:
            if reviewing {
                return .init(number: 6, title: "Make a decision", words: "Check the suggestion against the pictures. Then record what you think the find is.", target: .record)
            }
            return tab == .records
                ? .init(number: 6, title: "Make a decision", words: "Now make the call yourself: a person decides, never the agent. Press Review and decide.", target: .review)
                : .init(number: 6, title: "Make a decision", words: "Read the top of the record. Then go back to Records to decide what the find is.", target: .records)
        }
    }

    /// The control that wears the ring now. On Home, before the tutorial has begun, that is its own card.
    var tutorialTarget: Tutorial.Target? {
        if let step = tutorialStep { return step.target }
        return route == .home && offersTutorial && !tutorialOn ? .start : nil
    }

    /// Whether Home offers the tutorial: to someone with no project or only their first, and to anyone part-way through it.
    var offersTutorial: Bool {
        !tutorialDone && (store.projects.count < 2 || tutorialProject != nil)
    }

    /// Begin the tutorial, or carry on from where it was left.
    func startTutorial() {
        showWelcome = false
        if tutorialDone { tutorialProject = nil; tutorialReached = 0; tutorialDone = false }
        tutorialOn = true
        if let path = tutorialProject, FileManager.default.fileExists(atPath: path + "/PROJECT.md") {
            store.register(path: path)
            if let project = store.projects.first(where: { $0.path == path }) { open(project) }
        } else {
            tutorialProject = nil
            tutorialReached = 0
            startProject(from: Tutorial.point)
        }
    }

    /// Move the tutorial on when the person has done what the step asked. Called whenever the project or the page changes.
    func advanceTutorial() {
        guard tutorialOn, let path = tutorialProject, store.current?.path == path else { return }
        let found = !store.tiles.isEmpty && !store.tiles.contains { $0.status == "unscreened" } && !store.candidates.isEmpty && !chat.running
        if tutorialReached < 4, found {
            tutorialReached = 4
            tab = .map   // so that pressing Records is the person's own step
        } else if tutorialReached == 4, tab == .records {
            tutorialReached = 5
        } else if tutorialReached == 5, tab == .notes {
            tutorialReached = 6
            notesPart = "record"
        }
        if store.candidates.contains(where: { !$0.decisions.isEmpty }) { tutorialDone = true }
    }
}

/// The tutorial's bar under the top bar: which step this is, one sentence, and a way out.
struct CoachBar: View {
    @EnvironmentObject var app: AppState
    // The step depends on the run and on the project's files, so the bar follows those too.
    @EnvironmentObject var chat: ChatModel
    @EnvironmentObject var store: ProjectStore

    var body: some View {
        if let step = app.tutorialStep {
            HStack(alignment: .center, spacing: 12) {
                Group {
                    if step.working { DigIndicator(size: 16) } else { Glyph(name: "dig.trowel", size: 16 * Theme.scale).foregroundStyle(Theme.tan) }
                }
                .frame(width: 30)
                VStack(alignment: .leading, spacing: 2) {
                    Text(step.done ? "First project: done" : "First project · Step \(step.number) of \(Tutorial.count) · \(step.title)")
                        .font(.system(size: 12 * Theme.scale, weight: .semibold)).foregroundStyle(Theme.tan)
                    Text(step.words).font(.system(size: 13.5 * Theme.scale)).fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 12)
                if step.done {
                    Button("Finish") { app.tutorialOn = false; app.goHome() }.buttonStyle(PrimaryButton())
                } else {
                    Button("Leave") { app.tutorialOn = false }.buttonStyle(SecondaryButton())
                        .help("Leave the tutorial. Home and the Help menu bring it back at this step.")
                }
            }
            .padding(.horizontal, 16).padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.tan.opacity(0.1))
            .overlay(alignment: .bottom) { Hairline() }
            .accessibilityElement(children: .contain)
            .accessibilityLabel("First project tutorial")
        }
    }
}

/// The ring around the control the tutorial is pointing at. It breathes, unless Reduce Motion is on.
private struct CoachRing: ViewModifier {
    let target: Tutorial.Target?
    var radius: CGFloat = 10
    @EnvironmentObject var app: AppState
    @EnvironmentObject var chat: ChatModel
    @EnvironmentObject var store: ProjectStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var out = false

    func body(content: Content) -> some View {
        let on = target != nil && app.tutorialTarget == target
        content
            .overlay {
                if on {
                    RoundedRectangle(cornerRadius: radius, style: .continuous)
                        .strokeBorder(Theme.accent, lineWidth: 2)
                        .padding(-4)
                        .shadow(color: Theme.accent.opacity(0.8), radius: out ? 9 : 2)
                        .allowsHitTesting(false)
                        .onAppear {
                            guard !reduceMotion else { return }
                            withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) { out = true }
                        }
                        .onDisappear { out = false }
                }
            }
            .accessibilityHint(on ? "The tutorial's next step" : "")
    }
}

extension View {
    /// Marks a control the tutorial can point at.
    func coach(_ target: Tutorial.Target?, radius: CGFloat = 10) -> some View {
        modifier(CoachRing(target: target, radius: radius))
    }
}

