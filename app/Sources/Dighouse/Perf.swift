import Foundation

/// Measuring how quickly the app answers. Off unless Dighouse is launched with -measure YES (and -measureTour YES for
/// the scripted tour). A watcher thread notes every time the main thread stops answering for more than 250 ms, with
/// what the app was doing then, and the tour times the common actions. Everything goes to perf.log in Application Support.
enum Perf {
    static let on = UserDefaults.standard.bool(forKey: "measure")
    static let tour = UserDefaults.standard.bool(forKey: "measureTour")
    static var file: URL { Paths.support.appendingPathComponent("perf.log") }
    /// What the app is doing, named in the stall lines.
    nonisolated(unsafe) static var label = "idle"
    private static let queue = DispatchQueue(label: "perf.log")

    static func log(_ line: String) {
        guard on else { return }
        let stamp = Date().formatted(.iso8601.time(includingFractionalSeconds: true))
        queue.async {
            let data = Data((stamp + " " + line + "\n").utf8)
            if let handle = try? FileHandle(forWritingTo: file) {
                handle.seekToEndOfFile(); handle.write(data); try? handle.close()
            } else {
                try? data.write(to: file)
            }
        }
    }

    static func startWatching() {
        guard on else { return }
        log("watching, build \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?")")
        Thread.detachNewThread {
            while true {
                let sent = Date()
                let answered = DispatchSemaphore(value: 0)
                DispatchQueue.main.async { answered.signal() }
                if answered.wait(timeout: .now() + 0.25) == .timedOut {
                    answered.wait()
                    log("stall \(Int(Date().timeIntervalSince(sent) * 1000)) ms during \(label)")
                }
                Thread.sleep(forTimeInterval: 0.05)
            }
        }
    }

    /// Do one thing, then wait until it is ready and the window has settled, and log how long it took.
    @MainActor
    static func step(_ name: String, ready: @escaping () -> Bool = { true }, _ action: () -> Void) async {
        label = name
        let start = Date()
        action()
        var waited = 0
        while !ready() && waited < 1000 { try? await Task.sleep(for: .milliseconds(20)); waited += 1 }
        let readyMs = Int(Date().timeIntervalSince(start) * 1000)
        try? await Task.sleep(for: .milliseconds(1500))
        log("step \(name): ready in \(readyMs) ms" + (waited >= 1000 ? " (not ready after 20 s)" : ""))
        label = "idle"
    }
}

extension AppState {
    /// The scripted tour: Home, the largest project and each of its tabs, the Toolbox, Settings, New project, and the
    /// longest chat. Run with -measure YES -measureTour YES; it leaves the app on Home.
    func measureTour() async {
        guard Perf.on, Perf.tour else { return }
        for _ in 0..<90 where !engine.ready { try? await Task.sleep(for: .seconds(1)) }
        try? await Task.sleep(for: .seconds(3))
        Perf.log("tour start: \(store.projects.count) projects")
        await Perf.step("Home") { self.route = .home }
        let sizes: [Int] = await Task.detached { [refs = store.projects] in refs.map { ProjectStore.glance($0.path).finds } }.value
        if let i = sizes.indices.max(by: { sizes[$0] < sizes[$1] }) {
            let p = store.projects[i]
            await Perf.step("Open the largest project (\(sizes[i]) finds)",
                            ready: { self.store.current?.path == p.path && self.store.candidates.count >= sizes[i] }) { self.open(p) }
            for tab in [WorkTab.records, .notes, .sources, .data, .map] { await Perf.step("Tab \(tab.rawValue)") { self.tab = tab } }
            // ⌘+ and ⌘− on the largest project, with the map showing: the size a person feels.
            let size = textSize
            await Perf.step("Bigger text (⌘+)") { self.textSize = "large" }
            await Perf.step("Smaller text (⌘−)") { self.textSize = size }
            // What a running search costs: the project is polled every 2 seconds, and read again whenever a file changes.
            var start = Date()
            for _ in 0..<10 { store.reloadIfChanged() }
            Perf.log("poll with nothing changed: \(Int(Date().timeIntervalSince(start) * 100)) ms each")
            start = Date()
            for _ in 0..<5 { store.reloadNow() }
            Perf.log("read the project again after a change: \(Int(Date().timeIntervalSince(start) * 200)) ms each")
        }
        // Clicking between ordinary projects, the way a person goes back and forth.
        let small = store.projects.indices.filter { sizes.indices.contains($0) && sizes[$0] > 0 && sizes[$0] < 400 }.prefix(3).map { store.projects[$0] }
        for p in small + small.prefix(1) {
            await Perf.step("Switch to \(p.name)", ready: { self.store.current?.path == p.path && !self.store.candidates.isEmpty }) { self.open(p) }
        }
        await Perf.step("Home from a project") { self.goHome() }
        await Perf.step("Toolbox") { self.route = .toolbox }
        await Perf.step("Settings") { self.route = .settings }
        await Perf.step("New project") { self.route = .newProject }
        store.close()
        await chat.open(project: nil)
        for _ in 0..<100 where chat.generalThreads.isEmpty { try? await Task.sleep(for: .milliseconds(100)) }
        // The longest chat on this Mac: a timed session.
        if let thread = chat.generalThreads.first(where: { $0.title.hasPrefix("Timed research session") }) ?? chat.generalThreads.first {
            route = .chat
            var opened = false
            // Ready when its steps are on screen; the engine's fresh copy may still be on its way.
            await Perf.step("Open the chat \(thread.title)", ready: { opened || (self.chat.active == thread.id && !self.chat.items.isEmpty) }) {
                Task { @MainActor in await self.chat.select(thread); opened = true }
            }
            if let other = chat.generalThreads.first(where: { $0.id != thread.id }) {
                await chat.select(other)
                await Perf.step("Go back to \(thread.title)", ready: { self.chat.active == thread.id && !self.chat.items.isEmpty }) {
                    Task { @MainActor in await self.chat.select(thread) }
                }
            }
        }
        // What a running agent does to a long chat: a new step every few hundred milliseconds.
        if !chat.items.isEmpty {
            let count = chat.items.count
            await Perf.step("Ten new steps in a chat of \(count) items") {
                Task { @MainActor in
                    for i in 0..<10 {
                        self.chat.items.append(ChatItem(id: "perf-\(i)", kind: .step, text: "Looked at tile r00\(i)", icon: "eye", state: .done))
                        try? await Task.sleep(for: .milliseconds(300))
                    }
                }
            }
            try? await Task.sleep(for: .seconds(2))
            chat.items.removeAll { $0.id.hasPrefix("perf-") }
        }
        await Perf.step("Home again") { self.route = .home }
        Perf.log("tour end")
    }
}

