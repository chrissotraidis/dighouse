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
        case paragraph(String), heading(String), bullet(String, String), code(String)
    }

    private var blocks: [Block] {
        var out: [Block] = []
        var paragraph: [String] = []
        var code: [String]?
        func flush() {
            if !paragraph.isEmpty { out.append(.paragraph(paragraph.joined(separator: " "))); paragraph = [] }
        }
        for raw in text.components(separatedBy: "\n") {
            let line = raw.trimmingCharacters(in: .whitespaces)
            if line.hasPrefix("```") {
                if let done = code { out.append(.code(done.joined(separator: "\n"))); code = nil } else { flush(); code = [] }
                continue
            }
            if code != nil { code?.append(raw); continue }
            if line.isEmpty { flush(); continue }
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
                }
            }
        }
        .font(.system(size: 14)).foregroundStyle(Theme.text).textSelection(.enabled)
    }
}
