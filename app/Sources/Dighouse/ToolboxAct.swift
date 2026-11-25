import AppKit
import SwiftUI

// MARK: - Do something

/// The Toolbox's first part: everything Dighouse can do, each one a card that runs it (EASE_LOOP E4). Starting a search,
/// then the steps of a search in the open project, then what the person's other apps add.
struct ActTab: View {
    @EnvironmentObject var app: AppState
    @EnvironmentObject var store: ProjectStore

    private let projectSteps = ["full", "terrain", "screen", "check", "second", "prior", "decide", "report", "records"]
    private let two = [GridItem(.flexible(), spacing: 10, alignment: .top), GridItem(.flexible(), spacing: 10, alignment: .top)]

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            section("Start a search", "The agent chooses the ground, or you do.") {
                StartChoices()
            }
            section("In a project", store.current.map { "Each step of a search in \($0.name). Steps that are done or waiting say so." }
                    ?? "Each step of a search. Open a project from the sidebar to run them.") {
                LazyVGrid(columns: two, spacing: 10) {
                    ForEach(projectSteps.compactMap { id in ToolGuide.workflows.first { $0.id == id } }) { flow in
                        StepCard(flow: flow)
                    }
                }
            }
            section("With your other apps", "The agent can also use what your Codex app has. Press one to put a request in a new chat.") {
                MoreTools()
            }
        }
    }

    private func section<Content: View>(_ title: String, _ caption: String, @ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.system(size: 17 * Theme.scale, weight: .semibold))
                Text(caption).font(.system(size: 13 * Theme.scale)).foregroundStyle(Theme.dim).fixedSize(horizontal: false, vertical: true)
            }
            content()
        }
    }
}

/// Find something as the main card, and four equal ways to start under it. The same on the empty chat and the Toolbox.
struct StartChoices: View {
    @EnvironmentObject var app: AppState
    private let two = [GridItem(.flexible(), spacing: 10, alignment: .top), GridItem(.flexible(), spacing: 10, alignment: .top)]

    var body: some View {
        let all = ToolGuide.workflows
        VStack(alignment: .leading, spacing: 10) {
            if let main = all.first(where: { $0.id == "timed-research" }) {
                StartTile(icon: main.icon, title: main.title, text: main.summary, strong: true) { app.run(main) }
            }
            LazyVGrid(columns: two, spacing: 10) {
                ForEach(["research", "choose", "place", "surveys"].compactMap { id in all.first { $0.id == id } }) { flow in
                    StartTile(icon: flow.icon, title: flow.title, text: flow.summary) { app.run(flow) }
                }
            }
        }
    }
}

/// One step of a search: what it does, where the open project stands on it, and Run.
private struct StepCard: View {
    @EnvironmentObject var app: AppState
    let flow: ToolGuide.Workflow
    @State private var hover = false

    var body: some View {
        let state = app.state(of: flow)
        let done = ["Done", "All decided", "Prepared"].contains(state.note)
        HStack(alignment: .top, spacing: 12) {
            IconTile(name: flow.icon, size: 34)
            VStack(alignment: .leading, spacing: 4) {
                Text(flow.title).font(.system(size: 14 * Theme.scale, weight: .semibold))
                Text(flow.summary).font(.system(size: 12.5 * Theme.scale)).foregroundStyle(Theme.dim).lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 8) {
                    if !state.note.isEmpty {
                        HStack(spacing: 4) {
                            if done { Image(systemName: "checkmark").font(.system(size: 10 * Theme.scale, weight: .bold)).foregroundStyle(Theme.green) }
                            Text(state.note).font(.system(size: 12 * Theme.scale, weight: .medium)).foregroundStyle(done ? Theme.green : Theme.faint)
                        }
                    }
                    Spacer(minLength: 6)
                    Button("Run") { app.run(flow) }.buttonStyle(SecondaryButton()).disabled(!state.ready)
                        .help(state.ready ? "Run it now" : state.note)
                }
                .padding(.top, 4)
            }
        }
        .padding(14).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .surface()
        .onHover { hover = $0 }
        .animation(.easeOut(duration: 0.12), value: hover)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - What it can read: a map that zooms

/// The coverage map in a frame that zooms and moves like the project's map: the wheel or two fingers zoom toward the
/// pointer, a drag moves it, a pinch zooms, and the buttons zoom and fit. A click picks the place under the pointer.
struct ZoomableCoverage: View {
    var highlight: String?
    var surveys: [[Double]]
    let pick: (Double, Double) -> Void
    @State private var zoom: CGFloat = 1
    @State private var pan: CGSize = .zero
    @State private var dragStart: CGSize?
    @State private var pinchStart: CGFloat?
    @State private var pointer: CGPoint?
    @State private var size: CGSize = .zero
    @State private var wheel: Any?

    var body: some View {
        GeometryReader { geo in
            CoverageMap(highlight: highlight, surveys: surveys, europeInset: false, onPick: pick)
                .frame(width: geo.size.width * zoom, height: geo.size.height * zoom)
                .offset(pan)
                .frame(width: geo.size.width, height: geo.size.height, alignment: .topLeading)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .contentShape(Rectangle())
                .simultaneousGesture(DragGesture(minimumDistance: 4)
                    .onChanged { g in
                        if dragStart == nil { dragStart = pan }
                        pan = clamped(CGSize(width: (dragStart?.width ?? 0) + g.translation.width, height: (dragStart?.height ?? 0) + g.translation.height))
                    }
                    .onEnded { _ in dragStart = nil })
                .simultaneousGesture(MagnifyGesture()
                    .onChanged { g in
                        if pinchStart == nil { pinchStart = zoom }
                        zoom(to: (pinchStart ?? 1) * g.magnification, at: CGPoint(x: geo.size.width / 2, y: geo.size.height / 2))
                    }
                    .onEnded { _ in pinchStart = nil })
                .onContinuousHover { phase in
                    if case .active(let p) = phase { pointer = p } else { pointer = nil }
                }
                .onAppear { size = geo.size; listen() }
                .onChange(of: geo.size) { _, new in size = new; pan = clamped(pan) }
                .onDisappear { if let wheel { NSEvent.removeMonitor(wheel) }; wheel = nil }
        }
        .aspectRatio(348.0 / 133.0, contentMode: .fit)
        .overlay(alignment: .topTrailing) {
            HStack(spacing: 2) {
                Button { zoom(to: zoom / 1.6, at: center) } label: { Image(systemName: "minus") }
                    .buttonStyle(IconButton(size: 26)).disabled(zoom <= 1).help("Zoom out")
                Button { zoom(to: zoom * 1.6, at: center) } label: { Image(systemName: "plus") }
                    .buttonStyle(IconButton(size: 26)).disabled(zoom >= 12).help("Zoom in. The scroll wheel zooms toward the pointer.")
                Button { withAnimation(Motion.ease(0.2)) { zoom = 1; pan = .zero } } label: { Image(systemName: "arrow.down.right.and.arrow.up.left") }
                    .buttonStyle(IconButton(size: 26)).disabled(zoom <= 1).help("The whole world")
            }
            .padding(4).background(RoundedRectangle(cornerRadius: 9).fill(Theme.raised.opacity(0.92)))
            .padding(8)
        }
    }

    private var center: CGPoint { CGPoint(x: size.width / 2, y: size.height / 2) }

    private func zoom(to value: CGFloat, at p: CGPoint) {
        let next = min(max(value, 1), 12)
        guard next != zoom else { return }
        // Keep the place under the pointer where it is.
        let k = next / zoom
        pan = clamped(CGSize(width: p.x - (p.x - pan.width) * k, height: p.y - (p.y - pan.height) * k), zoom: next)
        zoom = next
    }

    private func clamped(_ offset: CGSize, zoom z: CGFloat? = nil) -> CGSize {
        let z = z ?? zoom
        let w = size.width * z, h = size.height * z
        return CGSize(width: min(0, max(size.width - w, offset.width)), height: min(0, max(size.height - h, offset.height)))
    }

    /// The wheel zooms only while the pointer is over the map, so the page scrolls as usual elsewhere.
    private func listen() {
        guard wheel == nil else { return }
        wheel = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { event in
            guard let p = pointer, event.window?.isKeyWindow == true else { return event }
            let flip: CGFloat = event.isDirectionInvertedFromDevice ? -1 : 1
            let dx = event.scrollingDeltaX * flip, dy = event.scrollingDeltaY * flip
            if abs(dy) >= abs(dx), dy != 0 {
                let step = event.hasPreciseScrollingDeltas ? exp(Double(dy) * 0.006) : pow(1.15, Double(dy))
                // Zoomed all the way out, scrolling on goes to the page, so the map never traps it.
                if zoom <= 1, step < 1 { return event }
                zoom(to: zoom * CGFloat(step), at: p)
            } else if dx != 0 {
                if zoom <= 1 { return event }
                pan = clamped(CGSize(width: pan.width + dx * (event.hasPreciseScrollingDeltas ? 1 : 12), height: pan.height))
            }
            return nil
        }
    }
}

extension Reach {
    /// The name of the place with open data under a point, as the data sources name where they reach: a national
    /// ground model's country, the United States, or Irish waters. Nil elsewhere, where only worldwide sources reach.
    static func place(lon: Double, lat: Double) -> String? {
        if let hit = national.first(where: { contains($0.ring, lon, lat) }) { return hit.name }
        if let hit = registers.first(where: { contains($0.ring, lon, lat) }) { return hit.name }
        if contains(unitedStates, lon, lat) { return "United States" }
        if let irish = sonar.last, contains(irish, lon, lat) { return "Irish waters" }
        return nil
    }

    /// Whether a ring of longitude, latitude pairs holds a point (the even-odd rule).
    static func contains(_ ring: [Double], _ lon: Double, _ lat: Double) -> Bool {
        var inside = false
        var j = ring.count - 2
        var i = 0
        while i + 1 < ring.count {
            let (xi, yi, xj, yj) = (ring[i], ring[i + 1], ring[j], ring[j + 1])
            if (yi > lat) != (yj > lat), lon < (xj - xi) * (lat - yi) / (yj - yi) + xi { inside.toggle() }
            j = i
            i += 2
        }
        return inside
    }
}
