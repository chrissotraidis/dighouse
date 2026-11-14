import AppKit
import SwiftUI

// MARK: - Buttons

private struct Pressable<Label: View>: View {
    let label: Label
    let pressed: Bool
    let fill: (Bool, Bool) -> Color
    let text: Color
    let outline: Color
    @State private var hover = false
    @Environment(\.isEnabled) private var enabled

    var body: some View {
        label
            .labelStyle(ButtonLabelStyle())
            .font(.system(size: 13 * Theme.scale, weight: .medium))
            .lineLimit(1).fixedSize(horizontal: true, vertical: false)
            .foregroundStyle(text.opacity(enabled ? 1 : 0.4))
            .padding(.horizontal, 12).frame(height: 30)
            .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(fill(hover && enabled, pressed).opacity(enabled ? 1 : 0.35)))
            .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(outline.opacity(enabled ? 1 : 0.5)))
            .shadow(color: .black.opacity(enabled ? 0.18 : 0), radius: 1, y: 1)
            .contentShape(RoundedRectangle(cornerRadius: 8))
            .scaleEffect(pressed ? 0.98 : 1)
            .onHover { hover = $0 }
            .animation(.easeOut(duration: 0.12), value: hover)
    }
}

/// An icon and a word in a button: the icon a little smaller and quieter than the word.
private struct ButtonLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 6) {
            configuration.icon.font(.system(size: 11.5 * Theme.scale, weight: .semibold)).opacity(0.85)
            configuration.title
        }
    }
}

/// The one main action on a screen: white, like the send button.
struct PrimaryButton: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        Pressable(label: configuration.label, pressed: configuration.isPressed,
                  fill: { hover, pressed in Theme.primary.opacity(pressed ? 0.72 : hover ? 0.86 : 1) },
                  text: .black, outline: .clear)
    }
}

/// A quiet filled button for everything else.
struct SecondaryButton: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        Pressable(label: configuration.label, pressed: configuration.isPressed,
                  fill: { hover, pressed in Theme.ink.opacity(pressed ? 0.16 : hover ? 0.12 : 0.07) },
                  text: Theme.text, outline: Theme.ink.opacity(0.12))
    }
}

/// A square icon button that lights up on hover.
struct IconButton: ButtonStyle {
    var size: CGFloat = 30
    var active = false

    func makeBody(configuration: Configuration) -> some View {
        Face(configuration: configuration, size: size, active: active)
    }

    private struct Face: View {
        let configuration: Configuration
        let size: CGFloat
        let active: Bool
        @State private var hover = false
        @Environment(\.isEnabled) private var enabled

        var body: some View {
            configuration.label
                .font(.system(size: 14 * Theme.scale, weight: .medium))
                .foregroundStyle((active ? Theme.text : Theme.dim).opacity(enabled ? 1 : 0.35))
                .frame(width: size, height: size)
                .background(RoundedRectangle(cornerRadius: 8).fill(
                    configuration.isPressed ? Theme.ink.opacity(0.14) : (hover || active) ? Theme.hover : .clear))
                .contentShape(Rectangle())
                .onHover { hover = $0 }
        }
    }
}

/// A full-width row in a list or sidebar.
struct RowButton: ButtonStyle {
    var selected = false

    func makeBody(configuration: Configuration) -> some View {
        Face(configuration: configuration, selected: selected)
    }

    private struct Face: View {
        let configuration: Configuration
        let selected: Bool
        @State private var hover = false

        var body: some View {
            configuration.label
                .padding(.horizontal, 10).frame(minHeight: 32)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 8).fill(
                    selected ? Theme.ink.opacity(0.1) : (hover || configuration.isPressed) ? Theme.hover : .clear))
                .contentShape(Rectangle())
                .onHover { hover = $0 }
        }
    }
}

// MARK: - Small pieces

extension View {
    /// A text field that matches the dark surface.
    func field() -> some View {
        self.textFieldStyle(.plain)
            .padding(.horizontal, 11).padding(.vertical, 8)
            .background(RoundedRectangle(cornerRadius: 9).fill(Theme.ink.opacity(0.05)))
            .overlay(RoundedRectangle(cornerRadius: 9).strokeBorder(Theme.line))
    }

    /// A grouped surface with a hairline edge.
    func panel(padding: CGFloat = 0, radius: CGFloat = 14) -> some View {
        self.padding(padding)
            .background(RoundedRectangle(cornerRadius: radius).fill(Theme.ink.opacity(0.035)))
            .overlay(RoundedRectangle(cornerRadius: radius).strokeBorder(Theme.line))
    }
}

// MARK: - Menus

/// One line of an in-app menu: a choice, a divider between groups, or a heading.
/// Every menu in the app is a list of these, so they all look and behave alike.
struct MenuEntry: Identifiable {
    let id = UUID()
    var title = ""
    var icon: String? = nil
    /// A second line under the title.
    var detail: String? = nil
    /// A short word on the right, such as "3 left".
    var note: String? = nil
    /// Draws the note in amber, for something that needs attention.
    var warn = false
    /// Marks the current choice.
    var checked = false
    /// Why the choice cannot be used now. It is shown under the title, and the row is greyed.
    var blocked: String? = nil
    var isDivider = false
    var isHeader = false
    var action: () -> Void = {}

    static var divider: MenuEntry { MenuEntry(isDivider: true) }
    static func header(_ title: String) -> MenuEntry { MenuEntry(title: title, isHeader: true) }
}

/// One choice in a menu: icon on the left, a tick on the right for the current choice.
struct MenuRow: View {
    let entry: MenuEntry
    var selected = false
    let action: () -> Void
    @State private var hover = false

    private var second: String? { entry.blocked ?? entry.detail }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                if let icon = entry.icon {
                    if second != nil { IconTile(name: icon, size: 30) } else {
                        Glyph(name: icon, size: 12.5 * Theme.scale).foregroundStyle(Theme.tan).frame(width: 18)
                    }
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.title).font(.system(size: 13.5 * Theme.scale, weight: second == nil ? .regular : .medium)).lineLimit(1)
                    if let second {
                        Text(second).font(.system(size: 12.5 * Theme.scale)).foregroundStyle(Theme.dim)
                            .lineLimit(3).multilineTextAlignment(.leading).fixedSize(horizontal: false, vertical: true)
                    }
                }
                Spacer(minLength: 8)
                if let note = entry.note {
                    Text(note).font(.system(size: 12 * Theme.scale)).foregroundStyle(entry.warn ? Theme.amber : Theme.faint).lineLimit(1).fixedSize()
                }
                if entry.checked {
                    Image(systemName: "checkmark").font(.system(size: 11 * Theme.scale, weight: .semibold)).foregroundStyle(Theme.accent)
                }
            }
            .padding(.horizontal, 10).padding(.vertical, second == nil ? 0 : 6).frame(minHeight: 30)
            .background(RoundedRectangle(cornerRadius: 8).fill(
                selected || entry.checked ? Theme.ink.opacity(0.09) : hover && entry.blocked == nil ? Theme.hover : .clear))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain).disabled(entry.blocked != nil).opacity(entry.blocked == nil ? 1 : 0.55)
        .onHover { hover = $0 }
        .accessibilityAddTraits(entry.checked ? .isSelected : [])
    }
}

/// The body of every in-app menu: rows with the same padding, icons on the left and dividers between groups.
struct MenuPanel: View {
    let entries: [MenuEntry]
    var width: CGFloat = 240
    /// Taller menus than this scroll.
    var maxHeight: CGFloat = 420
    let close: () -> Void

    /// A plain row is 31 points and a row with a second line about 50.
    private var height: CGFloat {
        entries.reduce(0) { $0 + ($1.isDivider ? 9 : $1.isHeader ? 24 : ($1.detail ?? $1.blocked) == nil ? 31 : 50) * ($1.isDivider ? 1 : Theme.scale) }
    }

    var body: some View {
        Group {
            if height > maxHeight { ScrollView { rows }.frame(height: maxHeight) } else { rows }
        }
        .padding(6).frame(width: width).foregroundStyle(Theme.text)
    }

    private var rows: some View {
        VStack(alignment: .leading, spacing: 1) {
            ForEach(entries) { entry in
                if entry.isDivider {
                    Hairline().padding(.vertical, 4)
                } else if entry.isHeader {
                    Text(entry.title).font(.system(size: 12 * Theme.scale, weight: .medium)).foregroundStyle(Theme.faint)
                        .padding(.horizontal, 10).padding(.top, 5).padding(.bottom, 3)
                } else {
                    MenuRow(entry: entry) { close(); entry.action() }
                }
            }
        }
    }
}

/// A menu drawn as a pill with its current choice and a chevron.
struct PillMenu: View {
    let title: String
    var quiet = false
    var width: CGFloat = 240
    let entries: () -> [MenuEntry]
    @State private var open = false

    var body: some View {
        Button { open.toggle() } label: {
            HStack(spacing: 5) {
                Text(title).lineLimit(1)
                Image(systemName: "chevron.down").font(.system(size: 8.5 * Theme.scale, weight: .bold))
            }
            .font(.system(size: 12.5 * Theme.scale))
            .foregroundStyle(quiet ? Theme.dim : Theme.text)
            .padding(.horizontal, quiet ? 8 : 12).frame(height: 28)
            .background(Capsule().fill(Theme.ink.opacity(quiet ? (open ? 0.08 : 0) : 0.05)))
            .overlay(Capsule().strokeBorder(quiet ? .clear : Theme.ink.opacity(0.16)))
            .contentShape(Capsule())
        }
        .buttonStyle(.plain).fixedSize()
        .popover(isPresented: $open, arrowEdge: .bottom) {
            MenuPanel(entries: entries(), width: width) { open = false }.popoverSurface()
        }
    }
}

/// A short coloured status label.
struct Badge: View {
    let text: String
    var color = Theme.dim

    var body: some View {
        Text(text).font(.system(size: 11.5 * Theme.scale, weight: .medium)).foregroundStyle(color)
            .lineLimit(1).fixedSize()
            .padding(.horizontal, 8).frame(height: 22)
            .background(Capsule().fill(color.opacity(0.14)))
    }
}

/// An icon on a small rounded tile: one of Dighouse's drawings or a system symbol.
struct IconTile: View {
    let name: String
    var size: CGFloat = 34

    var body: some View {
        Glyph(name: name, size: size * 0.44, weight: .medium).foregroundStyle(Theme.tan)
            .frame(width: size, height: size)
            .background(RoundedRectangle(cornerRadius: size * 0.27).fill(Theme.ink.opacity(0.07)))
    }
}

struct Hairline: View {
    var vertical = false

    var body: some View {
        Rectangle().fill(Theme.line).frame(width: vertical ? 1 : nil, height: vertical ? nil : 1)
    }
}

/// Lays children out left to right and wraps them onto new lines, so buttons wrap and their labels do not.
struct Flow: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, row: CGFloat = 0, widest: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x > 0, x + size.width > width { x = 0; y += row + spacing; row = 0 }
            x += size.width + spacing
            row = max(row, size.height)
            widest = max(widest, x - spacing)
        }
        return CGSize(width: proposal.width ?? widest, height: y + row)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, row: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x > bounds.minX, x + size.width > bounds.maxX { x = bounds.minX; y += row + spacing; row = 0 }
            view.place(at: CGPoint(x: x, y: y + (0)), proposal: ProposedViewSize(size))
            x += size.width + spacing
            row = max(row, size.height)
        }
    }
}

/// Lets an empty part of the top bar move the window, and zoom it on a double click.
struct WindowDragArea: NSViewRepresentable {
    final class Area: NSView {
        override func mouseDown(with event: NSEvent) {
            if event.clickCount == 2 { window?.performZoom(nil) } else { window?.performDrag(with: event) }
        }
    }

    func makeNSView(context: Context) -> NSView { Area() }
    func updateNSView(_ view: NSView, context: Context) {}
}

// MARK: - Markdown

/// Renders the Markdown agents write: paragraphs, headings, lists and code blocks.
struct MarkdownText: View {
    let text: String

    private enum Block {
        case paragraph(String), heading(String), bullet(String, String), code(String), table([[String]])
    }

    private var blocks: [Block] {
        var out: [Block] = []
        var paragraph: [String] = []
        var code: [String]?
        var table: [[String]] = []
        func flush() {
            if !paragraph.isEmpty { out.append(.paragraph(paragraph.joined(separator: " "))); paragraph = [] }
            if !table.isEmpty { out.append(.table(table)); table = [] }
        }
        for raw in text.components(separatedBy: "\n") {
            let line = raw.trimmingCharacters(in: .whitespaces)
            if line.hasPrefix("```") {
                if let done = code { out.append(.code(done.joined(separator: "\n"))); code = nil } else { flush(); code = [] }
                continue
            }
            if code != nil { code?.append(raw); continue }
            if line.isEmpty { flush(); continue }
            if line.hasPrefix("|"), line.hasSuffix("|"), line.count > 1 {
                if table.isEmpty { flush() }
                let cells = line.dropFirst().dropLast().split(separator: "|", omittingEmptySubsequences: false)
                    .map { $0.trimmingCharacters(in: .whitespaces) }
                // The row of dashes under the header only marks it as a header.
                if !cells.allSatisfy({ !$0.isEmpty && $0.allSatisfy { "-: ".contains($0) } }) { table.append(cells) }
                continue
            }
            if !table.isEmpty { flush() }
            if line.hasPrefix("#") {
                flush()
                out.append(.heading(line.drop { $0 == "#" }.trimmingCharacters(in: .whitespaces)))
            } else if line.hasPrefix("- ") || line.hasPrefix("* ") || line.hasPrefix("• ") {
                flush()
                out.append(.bullet("•", String(line.dropFirst(2))))
            } else if let dot = line.firstIndex(of: "."), line[..<dot].allSatisfy(\.isNumber), !line[..<dot].isEmpty,
                      line[line.index(after: dot)...].hasPrefix(" ") {
                flush()
                out.append(.bullet(String(line[...dot]), String(line[line.index(dot, offsetBy: 2)...])))
            } else if raw.hasPrefix("  "), paragraph.isEmpty, case .bullet(let mark, let text)? = out.last {
                // An indented line under a list item is the rest of that item.
                out[out.count - 1] = .bullet(mark, text + " " + line)
            } else {
                paragraph.append(line)
            }
        }
        if let open = code { out.append(.code(open.joined(separator: "\n"))) }
        flush()
        return out
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(Array(blocks.enumerated()), id: \.offset) { _, block in
                switch block {
                case .paragraph(let s):
                    Text(s.inlineMarkdown).lineSpacing(4).fixedSize(horizontal: false, vertical: true)
                case .heading(let s):
                    Text(s.inlineMarkdown).font(.system(size: 15 * Theme.scale, weight: .semibold)).padding(.top, 4)
                case .bullet(let mark, let s):
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(mark).foregroundStyle(Theme.dim).frame(minWidth: 14, alignment: .trailing)
                        Text(s.inlineMarkdown).lineSpacing(4).fixedSize(horizontal: false, vertical: true)
                    }
                case .code(let s):
                    Text(s).font(.system(size: 12 * Theme.scale, design: .monospaced)).foregroundStyle(Theme.dim)
                        .padding(10).frame(maxWidth: .infinity, alignment: .leading)
                        .background(RoundedRectangle(cornerRadius: 8).fill(Color.black.opacity(0.3)))
                case .table(let rows):
                    Grid(alignment: .topLeading, horizontalSpacing: 14, verticalSpacing: 0) {
                        ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                            if index > 0 { Hairline().gridCellUnsizedAxes(.horizontal) }
                            GridRow {
                                ForEach(Array(row.enumerated()), id: \.offset) { _, cell in
                                    Text(cell.inlineMarkdown).font(.system(size: 13 * Theme.scale, weight: index == 0 ? .semibold : .regular))
                                        .foregroundStyle(index == 0 ? Theme.text : Theme.dim)
                                        .fixedSize(horizontal: false, vertical: true).padding(.vertical, 7)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 12).frame(maxWidth: .infinity, alignment: .leading)
                    .panel(radius: 10)
                }
            }
        }
        .font(.system(size: 14 * Theme.scale)).foregroundStyle(Theme.text).textSelection(.enabled)
    }
}

// MARK: - Floating panels and pickers

extension View {
    /// The raised dark card used for menus that float over the chat.
    func floatingPanel(radius: CGFloat = 22) -> some View {
        self.background(RoundedRectangle(cornerRadius: radius).fill(Theme.pop))
            .overlay(RoundedRectangle(cornerRadius: radius).strokeBorder(Theme.ink.opacity(0.12)))
            .shadow(color: .black.opacity(0.5), radius: 28, y: 10)
    }

    /// Gives a popover the app's dark surface, arrow included.
    func popoverSurface() -> some View {
        self.background(Theme.pop.scaleEffect(1.5))
    }
}

/// A slider that snaps to named steps, with a dot for each.
struct StepSlider: View {
    let steps: [String]
    @Binding var value: String
    var showLabels = false
    private let knob: CGFloat = 32
    private var track: Color { Theme.accentDeep }

    var body: some View {
        VStack(spacing: 6) {
            GeometryReader { geo in
                let usable = max(geo.size.width - knob, 1)
                let last = CGFloat(max(steps.count - 1, 1))
                let x = usable * CGFloat(steps.firstIndex(of: value) ?? 0) / last
                ZStack(alignment: .leading) {
                    Capsule().fill(Theme.ink.opacity(0.1))
                    Capsule().fill(track).frame(width: x + knob)
                    ForEach(steps.indices, id: \.self) { i in
                        Circle().fill(Theme.ink.opacity(0.4)).frame(width: 4, height: 4)
                            .position(x: knob / 2 + usable * CGFloat(i) / last, y: knob / 2)
                    }
                    Circle().fill(Theme.primary).frame(width: knob, height: knob)
                        .shadow(color: .black.opacity(0.35), radius: 3, y: 1).offset(x: x)
                }
                .animation(.easeOut(duration: 0.12), value: value)
                .overlay(DragCatcher { at, _, _ in
                    let fraction = min(max((at - knob / 2) / usable, 0), 1)
                    let pick = steps[Int((fraction * last).rounded())]
                    if pick != value { value = pick }
                })
            }
            .frame(height: knob)
            if showLabels {
                GeometryReader { geo in
                    let usable = max(geo.size.width - knob, 1)
                    let last = CGFloat(max(steps.count - 1, 1))
                    ForEach(steps.indices, id: \.self) { i in
                        Text(Effort.short(steps[i])).font(.system(size: 10.5 * Theme.scale, weight: steps[i] == value ? .semibold : .regular))
                            .foregroundStyle(steps[i] == value ? Theme.text : Theme.faint).fixedSize()
                            .position(x: knob / 2 + usable * CGFloat(i) / last, y: 7)
                    }
                }
                .frame(height: 14)
            }
        }
        // The slider is drawn by hand, so say what it is and let the keyboard and VoiceOver move it.
        .accessibilityElement()
        .accessibilityLabel("Thinking effort")
        .accessibilityValue(Effort.label(value))
        .accessibilityAdjustableAction { direction in
            guard let i = steps.firstIndex(of: value) else { return }
            let next = direction == .increment ? i + 1 : i - 1
            if steps.indices.contains(next) { value = steps[next] }
        }
    }
}

/// A scrolling, searchable list of models in the style of the ChatGPT picker.
struct ModelList: View {
    let models: [ModelInfo]
    let current: String?
    var checks: [String: ModelCheck] = [:]
    /// Models picked lately, shown first under "Recent".
    var recent: [String] = []
    let pick: (ModelInfo) -> Void
    @State private var query = ""
    @FocusState private var searching: Bool

    private var shown: [ModelInfo] {
        query.isEmpty ? models : models.filter { $0.name.localizedCaseInsensitiveContains(query) }
    }
    private var recentShown: [ModelInfo] {
        query.isEmpty ? recent.compactMap { id in models.first { $0.id == id } } : []
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Select model").font(.system(size: 13 * Theme.scale)).foregroundStyle(Theme.faint).padding(.horizontal, 12).padding(.top, 4)
            if models.count > 12 {
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass").font(.system(size: 11 * Theme.scale)).foregroundStyle(Theme.faint)
                    TextField("Search", text: $query).textFieldStyle(.plain).font(.system(size: 13 * Theme.scale)).focused($searching)
                }
                .padding(.horizontal, 10).frame(height: 30)
                .background(RoundedRectangle(cornerRadius: 9).fill(Theme.ink.opacity(0.06)))
                .padding(.horizontal, 6)
            }
            ScrollView {
                LazyVStack(spacing: 1) {
                    if recentShown.count > 1 {
                        section("Recent")
                        ForEach(recentShown.map { ($0, "recent-" + $0.id) }, id: \.1) { model, _ in row(model) }
                        section("All models")
                    }
                    ForEach(shown) { model in row(model) }
                    if shown.isEmpty { Text("No model matches.").font(.system(size: 13 * Theme.scale)).foregroundStyle(Theme.faint).padding(12) }
                }
                .padding(.horizontal, 6)
            }
            .frame(height: min(max(CGFloat(shown.count + (recentShown.count > 1 ? recentShown.count + 2 : 0)), 1) * 31 * Theme.scale, 340))
        }
        .padding(.vertical, 8)
        .frame(width: 300)
        .foregroundStyle(Theme.text)
        .task {
            // The popover has to finish opening before it can take the keyboard.
            try? await Task.sleep(for: .milliseconds(150))
            searching = models.count > 12
        }
    }

    private func section(_ title: String) -> some View {
        Text(title).font(.system(size: 11.5 * Theme.scale, weight: .medium)).foregroundStyle(Theme.faint)
            .frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 6).padding(.top, 6).padding(.bottom, 2)
    }

    private func row(_ model: ModelInfo) -> some View {
        // The same row as every other menu, with what is known about the model on the right.
        let check = checks[model.id]
        let notes = [model.readsImages ? nil : "text only", check.map { $0.ok ? "tested" : "failed test" }].compactMap { $0 }
        return MenuRow(entry: MenuEntry(title: model.name, note: notes.isEmpty ? nil : notes.joined(separator: " · "),
                                        warn: check?.ok == false, checked: model.id == current)) { pick(model) }
            .help(check.map { $0.ok ? "Answered a test message\($0.effort.map { " at \(Effort.label($0))" } ?? "")." : $0.message } ?? "")
    }
}

/// A pill that opens the model list in a popover. Used outside the message box.
struct ModelPicker: View {
    let title: String
    let models: [ModelInfo]
    let current: String?
    var checks: [String: ModelCheck] = [:]
    let pick: (ModelInfo) -> Void
    @State private var open = false

    var body: some View {
        Button { open = true } label: {
            HStack(spacing: 5) {
                Text(title).lineLimit(1)
                Image(systemName: "chevron.down").font(.system(size: 8.5 * Theme.scale, weight: .bold))
            }
            .font(.system(size: 12.5 * Theme.scale)).foregroundStyle(Theme.text)
            .padding(.horizontal, 12).frame(height: 28)
            .overlay(Capsule().strokeBorder(Theme.ink.opacity(0.16))).contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .popover(isPresented: $open, arrowEdge: .bottom) {
            ModelList(models: models, current: current, checks: checks) { model in
                pick(model)
                open = false
            }
            .popoverSurface()
        }
    }
}

/// Catches a mouse drag with AppKit, so it works wherever the view sits and never moves the window.
struct DragCatcher: NSViewRepresentable {
    var cursor: NSCursor?
    /// Where the pointer is across the view, how far it has moved since the press, and whether this is the press.
    let onDrag: (_ at: CGFloat, _ moved: CGFloat, _ began: Bool) -> Void
    var onEnd: () -> Void = {}

    final class Catcher: NSView {
        var cursor: NSCursor?
        var onDrag: ((CGFloat, CGFloat, Bool) -> Void)?
        var onEnd: (() -> Void)?
        private var start: CGFloat = 0

        override var mouseDownCanMoveWindow: Bool { false }
        override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
        override func resetCursorRects() { if let cursor { addCursorRect(bounds, cursor: cursor) } }

        override func mouseDown(with event: NSEvent) {
            start = event.locationInWindow.x
            onDrag?(convert(event.locationInWindow, from: nil).x, 0, true)
        }
        override func mouseDragged(with event: NSEvent) {
            onDrag?(convert(event.locationInWindow, from: nil).x, event.locationInWindow.x - start, false)
        }
        override func mouseUp(with event: NSEvent) { onEnd?() }
    }

    func makeNSView(context: Context) -> Catcher { Catcher() }
    func updateNSView(_ view: Catcher, context: Context) {
        view.cursor = cursor
        view.onDrag = onDrag
        view.onEnd = onEnd
    }
}

/// A draggable line between two panes. Drag it to resize the pane on its left.
struct SplitHandle: View {
    @Binding var width: Double
    let range: ClosedRange<Double>
    var help = "Drag to resize"
    @State private var start = 0.0
    @State private var dragging = false
    @State private var hover = false

    var body: some View {
        let lit = hover || dragging
        ZStack {
            Rectangle().fill(lit ? Theme.accent : Theme.line).frame(width: lit ? 3 : 1)
            if lit {
                Capsule().fill(Theme.accent).frame(width: 5, height: 44)
            }
        }
        .frame(width: 13).frame(maxHeight: .infinity)
        .overlay(DragCatcher(cursor: .resizeLeftRight, onDrag: { _, moved, began in
            if began { start = width; dragging = true }
            width = min(max(start + Double(moved), range.lowerBound), max(range.upperBound, range.lowerBound))
        }, onEnd: { dragging = false }))
        .onHover { hover = $0 }
        .padding(.horizontal, -6)   // the grab area is wider than the line, without pushing the panes apart
        .zIndex(2)
        .help(help)
    }
}

/// Pictures that explain the app: made with its own tools from open data.
enum Tour {
    static func image(_ name: String) -> NSImage? {
        guard let url = Bundle.main.resourceURL?.appendingPathComponent("tour/\(name).jpg") else { return nil }
        return Images.load(url.path)
    }
}

/// Two pictures of the same place with a handle between them. Drag it to see one give way to the other.
struct RevealSlider: View {
    let left: NSImage, right: NSImage
    let leftLabel: String, rightLabel: String
    var animateIn = true
    @State private var split = 0.5

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            ZStack(alignment: .topLeading) {
                Image(nsImage: right).resizable().aspectRatio(contentMode: .fill).frame(width: w, height: h).clipped()
                Image(nsImage: left).resizable().aspectRatio(contentMode: .fill).frame(width: w, height: h).clipped()
                    .mask(alignment: .leading) { Rectangle().frame(width: w * split) }
                tag(leftLabel).padding(10).opacity(split > 0.16 ? 1 : 0)
                tag(rightLabel).padding(10).frame(width: w, alignment: .trailing).opacity(split < 0.84 ? 1 : 0)
                Rectangle().fill(.white).frame(width: 2, height: h).offset(x: w * split - 1)
                Circle().fill(.white).frame(width: 34, height: 34)
                    .overlay(Image(systemName: "arrow.left.and.right").font(.system(size: 13 * Theme.scale, weight: .bold)).foregroundStyle(.black))
                    .shadow(color: .black.opacity(0.5), radius: 5, y: 1)
                    .offset(x: w * split - 17, y: h / 2 - 17)
            }
            .overlay(DragCatcher(cursor: .resizeLeftRight) { at, _, _ in split = min(max(at / w, 0.02), 0.98) })
        }
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Theme.line))
        .onAppear {
            guard animateIn else { return }
            split = 0.92
            withAnimation(.easeInOut(duration: 1.8).delay(0.5)) { split = 0.42 }
        }
        .accessibilityElement()
        .accessibilityLabel("\(leftLabel) and \(rightLabel) of the same place")
        .accessibilityValue("\(Int(split * 100)) percent \(leftLabel.lowercased())")
        .accessibilityAdjustableAction { direction in
            split = min(max(split + (direction == .increment ? 0.2 : -0.2), 0.02), 0.98)
        }
    }

    private func tag(_ text: String) -> some View {
        Text(text).font(.system(size: 11.5 * Theme.scale, weight: .semibold)).foregroundStyle(.white)
            .padding(.horizontal, 9).frame(height: 24)
            .background(Capsule().fill(.black.opacity(0.68)))
    }
}

/// The forest and the bare ground at Serpent Mound, from the same open lidar points.
struct ForestReveal: View {
    var animateIn = true

    var body: some View {
        if let top = Tour.image("serpent-canopy"), let ground = Tour.image("serpent-ground") {
            RevealSlider(left: top, right: ground, leftLabel: "Treetops", rightLabel: "Bare ground", animateIn: animateIn)
                .aspectRatio(938.0 / 586.0, contentMode: .fit)
        }
    }
}

/// The Dighouse mark, as in the app icon: a line of ground with a mound in it, and the canopy above.
/// A pass of light sweeps across it, the way a lidar flight passes over the ground: slowly while the app is idle,
/// quickly and brightly while the agent works, and once more when the pointer moves over it.
struct MoundMark: View {
    var working = false
    var lively = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var hover = false

    var body: some View {
        let moving = (lively || working || hover) && !reduceMotion
        TimelineView(.animation(minimumInterval: 1 / 30, paused: !moving)) { timeline in
            let period = working ? 1.2 : hover ? 1.5 : 2.6
            let phase = moving ? timeline.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: period) / period : -1
            Canvas { context, size in draw(context, size, sweep: phase, strength: working || hover ? 1 : 0.9) }
        }
        .onHover { hover = $0 }
        .accessibilityHidden(true)
    }

    /// sweep runs from 0 to 1 across the mark; below 0 the mark is still.
    private func draw(_ context: GraphicsContext, _ size: CGSize, sweep: Double, strength: CGFloat) {
        let n = 15
        let dot = size.width / CGFloat(n) * 0.62
        func lift(_ t: CGFloat) -> CGFloat { exp(-pow((t - 0.5) / 0.17, 2)) }
        for i in 0..<n {
            let t = CGFloat(i) / CGFloat(n - 1)
            // How close the pass is to this column: 1 under it, falling to 0 a few columns away.
            let near = sweep < 0 ? 0 : strength * max(0, 1 - abs(t - CGFloat(sweep * 1.4 - 0.2)) / 0.18)
            let x = t * (size.width - dot)
            let ground = size.height - dot - lift(t) * size.height * 0.34
            let grow = dot * (1 + 0.5 * near)
            let groundRect = CGRect(x: x - (grow - dot) / 2, y: ground - (grow - dot) / 2, width: grow, height: grow)
            context.fill(Path(ellipseIn: groundRect), with: .color(Theme.tan.opacity(0.7 + 0.3 * near)))
            // The canopy follows the ground, in two staggered rows. Under the pass it fades, as if seen through.
            for row in 1...2 where (i + row) % 2 == 0 && i > 0 && i < n - 1 {
                let y = ground - CGFloat(row) * size.height * 0.27
                if y >= 0 {
                    context.fill(Path(ellipseIn: CGRect(x: x, y: y, width: dot, height: dot)),
                                 with: .color(Theme.green.opacity(1 - 0.8 * near)))
                }
            }
        }
    }
}

/// A titled block on a page.
struct PageSection<Content: View>: View {
    let title: String
    var caption = ""
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.system(size: 16 * Theme.scale, weight: .semibold))
                if !caption.isEmpty {
                    Text(caption).font(.system(size: 13 * Theme.scale)).foregroundStyle(Theme.dim).fixedSize(horizontal: false, vertical: true)
                }
            }
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
