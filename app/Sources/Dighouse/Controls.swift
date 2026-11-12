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
            .font(.system(size: 13, weight: .medium))
            .lineLimit(1).fixedSize(horizontal: true, vertical: false)
            .foregroundStyle(text.opacity(enabled ? 1 : 0.4))
            .padding(.horizontal, 14).frame(height: 30)
            .background(Capsule().fill(fill(hover && enabled, pressed).opacity(enabled ? 1 : 0.3)))
            .overlay(Capsule().strokeBorder(outline))
            .contentShape(Capsule())
            .onHover { hover = $0 }
            .animation(.easeOut(duration: 0.12), value: hover)
    }
}

/// The one main action on a screen: white, like the send button.
struct PrimaryButton: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        Pressable(label: configuration.label, pressed: configuration.isPressed,
                  fill: { hover, pressed in Color.white.opacity(pressed ? 0.72 : hover ? 0.86 : 1) },
                  text: .black, outline: .clear)
    }
}

/// A quiet outlined pill for everything else.
struct SecondaryButton: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        Pressable(label: configuration.label, pressed: configuration.isPressed,
                  fill: { hover, pressed in Color.white.opacity(pressed ? 0.16 : hover ? 0.1 : 0) },
                  text: Theme.text, outline: Color.white.opacity(0.16))
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
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle((active ? Theme.text : Theme.dim).opacity(enabled ? 1 : 0.35))
                .frame(width: size, height: size)
                .background(RoundedRectangle(cornerRadius: 8).fill(
                    configuration.isPressed ? Color.white.opacity(0.14) : (hover || active) ? Theme.hover : .clear))
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
                    selected ? Color.white.opacity(0.1) : (hover || configuration.isPressed) ? Theme.hover : .clear))
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
            .background(RoundedRectangle(cornerRadius: 9).fill(Color.white.opacity(0.05)))
            .overlay(RoundedRectangle(cornerRadius: 9).strokeBorder(Theme.line))
    }

    /// A grouped surface with a hairline edge.
    func panel(padding: CGFloat = 0, radius: CGFloat = 14) -> some View {
        self.padding(padding)
            .background(RoundedRectangle(cornerRadius: radius).fill(Color.white.opacity(0.035)))
            .overlay(RoundedRectangle(cornerRadius: radius).strokeBorder(Theme.line))
    }
}

/// A menu drawn as a pill with its current choice and a chevron.
struct PillMenu<Content: View>: View {
    let title: String
    var quiet = false
    @ViewBuilder let content: () -> Content

    var body: some View {
        Menu {
            content()
        } label: {
            HStack(spacing: 5) {
                Text(title).lineLimit(1)
                Image(systemName: "chevron.down").font(.system(size: 8.5, weight: .bold))
            }
            .font(.system(size: 12.5))
            .foregroundStyle(quiet ? Theme.dim : Theme.text)
            .padding(.horizontal, quiet ? 8 : 12).frame(height: 28)
            .background(Capsule().fill(Color.white.opacity(quiet ? 0 : 0.05)))
            .overlay(Capsule().strokeBorder(quiet ? .clear : Color.white.opacity(0.16)))
            .contentShape(Capsule())
        }
        .menuStyle(.button).buttonStyle(.plain).menuIndicator(.hidden).fixedSize()
    }
}

/// A short coloured status label.
struct Badge: View {
    let text: String
    var color = Theme.dim

    var body: some View {
        Text(text).font(.system(size: 11.5, weight: .medium)).foregroundStyle(color)
            .lineLimit(1).fixedSize()
            .padding(.horizontal, 8).frame(height: 22)
            .background(Capsule().fill(color.opacity(0.14)))
    }
}

/// An icon on a small rounded tile.
struct IconTile: View {
    let name: String
    var size: CGFloat = 34

    var body: some View {
        Image(systemName: name).font(.system(size: size * 0.44, weight: .medium)).foregroundStyle(Theme.tan)
            .frame(width: size, height: size)
            .background(RoundedRectangle(cornerRadius: size * 0.27).fill(Color.white.opacity(0.07)))
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
                    Text(s.inlineMarkdown).font(.system(size: 15, weight: .semibold)).padding(.top, 4)
                case .bullet(let mark, let s):
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(mark).foregroundStyle(Theme.dim).frame(minWidth: 14, alignment: .trailing)
                        Text(s.inlineMarkdown).lineSpacing(4).fixedSize(horizontal: false, vertical: true)
                    }
                case .code(let s):
                    Text(s).font(.system(size: 12, design: .monospaced)).foregroundStyle(Theme.dim)
                        .padding(10).frame(maxWidth: .infinity, alignment: .leading)
                        .background(RoundedRectangle(cornerRadius: 8).fill(Color.black.opacity(0.3)))
                case .table(let rows):
                    Grid(alignment: .topLeading, horizontalSpacing: 14, verticalSpacing: 0) {
                        ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                            if index > 0 { Hairline().gridCellUnsizedAxes(.horizontal) }
                            GridRow {
                                ForEach(Array(row.enumerated()), id: \.offset) { _, cell in
                                    Text(cell.inlineMarkdown).font(.system(size: 13, weight: index == 0 ? .semibold : .regular))
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
        .font(.system(size: 14)).foregroundStyle(Theme.text).textSelection(.enabled)
    }
}

// MARK: - Floating panels and pickers

extension View {
    /// The raised dark card used for menus that float over the chat.
    func floatingPanel(radius: CGFloat = 22) -> some View {
        self.background(RoundedRectangle(cornerRadius: radius).fill(Color(white: 0.165)))
            .overlay(RoundedRectangle(cornerRadius: radius).strokeBorder(Color.white.opacity(0.12)))
            .shadow(color: .black.opacity(0.5), radius: 28, y: 10)
    }

    /// Gives a popover the app's dark surface, arrow included.
    func popoverSurface() -> some View {
        self.background(Color(white: 0.165).scaleEffect(1.5))
    }
}

/// A slider that snaps to named steps, with a dot for each.
struct StepSlider: View {
    let steps: [String]
    @Binding var value: String
    private let knob: CGFloat = 32
    private let track = Color(red: 0.17, green: 0.43, blue: 0.86)

    var body: some View {
        GeometryReader { geo in
            let usable = max(geo.size.width - knob, 1)
            let last = CGFloat(max(steps.count - 1, 1))
            let x = usable * CGFloat(steps.firstIndex(of: value) ?? 0) / last
            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.1))
                Capsule().fill(track).frame(width: x + knob)
                ForEach(steps.indices, id: \.self) { i in
                    Circle().fill(Color.white.opacity(0.4)).frame(width: 4, height: 4)
                        .position(x: knob / 2 + usable * CGFloat(i) / last, y: knob / 2)
                }
                Circle().fill(.white).frame(width: knob, height: knob)
                    .shadow(color: .black.opacity(0.35), radius: 3, y: 1).offset(x: x)
            }
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 0).onChanged { drag in
                let fraction = min(max((drag.location.x - knob / 2) / usable, 0), 1)
                let pick = steps[Int((fraction * last).rounded())]
                if pick != value { value = pick }
            })
            .animation(.easeOut(duration: 0.12), value: value)
        }
        .frame(height: knob)
    }
}

/// A scrolling, searchable list of models in the style of the ChatGPT picker.
struct ModelList: View {
    let models: [ModelInfo]
    let current: String?
    let pick: (ModelInfo) -> Void
    @State private var query = ""
    @FocusState private var searching: Bool

    private var shown: [ModelInfo] {
        query.isEmpty ? models : models.filter { $0.name.localizedCaseInsensitiveContains(query) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Select model").font(.system(size: 13)).foregroundStyle(Theme.faint).padding(.horizontal, 12).padding(.top, 4)
            if models.count > 12 {
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass").font(.system(size: 11)).foregroundStyle(Theme.faint)
                    TextField("Search", text: $query).textFieldStyle(.plain).font(.system(size: 13)).focused($searching)
                }
                .padding(.horizontal, 10).frame(height: 30)
                .background(RoundedRectangle(cornerRadius: 9).fill(Color.white.opacity(0.06)))
                .padding(.horizontal, 6)
            }
            ScrollView {
                LazyVStack(spacing: 1) {
                    ForEach(shown) { model in
                        Button { pick(model) } label: {
                            HStack(spacing: 8) {
                                Text(model.name).font(.system(size: 14)).lineLimit(1)
                                if !model.readsImages { Text("text only").font(.system(size: 11)).foregroundStyle(Theme.faint) }
                                Spacer(minLength: 0)
                                if model.id == current { Image(systemName: "checkmark").font(.system(size: 11, weight: .semibold)) }
                            }
                            .padding(.vertical, 3)
                        }
                        .buttonStyle(RowButton(selected: model.id == current))
                    }
                    if shown.isEmpty { Text("No model matches.").font(.system(size: 13)).foregroundStyle(Theme.faint).padding(12) }
                }
                .padding(.horizontal, 6)
            }
            .frame(height: min(max(CGFloat(shown.count), 1) * 39, 340))
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
}

/// A pill that opens the model list in a popover. Used outside the message box.
struct ModelPicker: View {
    let title: String
    let models: [ModelInfo]
    let current: String?
    let pick: (ModelInfo) -> Void
    @State private var open = false

    var body: some View {
        Button { open = true } label: {
            HStack(spacing: 5) {
                Text(title).lineLimit(1)
                Image(systemName: "chevron.down").font(.system(size: 8.5, weight: .bold))
            }
            .font(.system(size: 12.5)).foregroundStyle(Theme.text)
            .padding(.horizontal, 12).frame(height: 28)
            .overlay(Capsule().strokeBorder(Color.white.opacity(0.16))).contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .popover(isPresented: $open, arrowEdge: .bottom) {
            ModelList(models: models, current: current) { model in
                pick(model)
                open = false
            }
            .popoverSurface()
        }
    }
}

/// The draggable line between the chat and the workspace.
struct SplitHandle: View {
    @Binding var width: Double
    let range: ClosedRange<Double>
    @State private var start: Double?
    @State private var hover = false

    var body: some View {
        Rectangle().fill(hover || start != nil ? Theme.accent.opacity(0.7) : Theme.line)
            .frame(width: hover || start != nil ? 2 : 1)
            .frame(width: 9).contentShape(Rectangle())
            .onHover { inside in
                hover = inside
                if inside { NSCursor.resizeLeftRight.push() } else { NSCursor.pop() }
            }
            .gesture(DragGesture(minimumDistance: 1, coordinateSpace: .global).onChanged { drag in
                if start == nil { start = width }
                width = min(max((start ?? width) + drag.translation.width, range.lowerBound), range.upperBound)
            }.onEnded { _ in start = nil })
            .help("Drag to resize the chat")
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
                Text(title).font(.system(size: 16, weight: .semibold))
                if !caption.isEmpty {
                    Text(caption).font(.system(size: 13)).foregroundStyle(Theme.dim).fixedSize(horizontal: false, vertical: true)
                }
            }
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
