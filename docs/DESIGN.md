# Design

Dighouse should feel like one calm, plain tool that a first-time user can follow. Check every change against these rules in the running app, at 1440 × 900 and at 1280 × 800.

## Words

- **Fewer words is the work.** One sentence for one idea, 25 words at most. Use a picture or a control wherever one can carry the meaning.
- **One word for one thing:** a **find** (not a flag or a candidate), a **slice** (not a section), the agent **looks at** tiles (not screens), a **second opinion** (not a second look), **the ground** (not terrain). Code and tool names keep the older words.
- **Plain words a newcomer knows.** Write "lidar" in lowercase. Show no raw JSON or internal ids, and a file path only where a person needs it.
- **Say what happens next,** and who does it.

## Layout

- **One page at a time:** Home, a chat, New project, the Toolbox, Settings. A project puts its workspace beside the chat.
- **Projects first.** A project is the home for its work: the sidebar lists projects before loose chats, each project's chats fold under it, and the project page lists them. Blind tests sit in a group of their own.
- **A chat's title never shows a place.** `ChatThread.label` takes boxes and coordinates out; show titles through it.
- **One main button per screen** (`PrimaryButton`). Everything else is `SecondaryButton` or plain.
- **A number means one thing everywhere.** If the header says 6 need you, the overview and the list say 6 too.
- **Nothing truncates to "…".** Shorten the label, use an icon with help text, or move it.
- **Dense maps stay readable.** Labels show on hover, on selection or when zoomed in.
- **An empty screen says what is missing** and offers the one next step.
- **Progress shows in place,** not in a pop-up window.
- **One spacing scale.** Paddings and gaps are 2, 4, 6, 8, 10, 12, 14, 16, 20, 24, 32 or 48 points (0 and 1 for hairlines). Pages sit 24 or 32 points in from their edges; a panel's rows are padded 14; a group heading sits 20 below the group before. A padding that lines something up under an icon or a bar may be any number, with a `// aligns` comment. `tests/test_app_spacing.py` checks it.

## Controls

- **Reuse what exists:** `PrimaryButton`, `SecondaryButton`, `CardButton`, `IconButton`, `RowButton`, `PillMenu` and `Badge` in `Controls.swift`.
- **Colours come from `Theme`.** Every font size is multiplied by `Theme.scale`, so all five text sizes work.
- **Keyboard and pointer both work.** Every control can be reached from the keyboard. Escape or a click outside closes a sheet or a menu. Icon-only buttons have help text.
- **A greyed-out control says why** when you point at it.
- **Recheck every control you rewire** in the running app, not only in the build.

## Pictures of the ground

- Show them at a fixed, stated scale, with the find ringed and a wider view for context.
- Make them from open data with Dighouse's own tools, and name the source in the caption.
- Never show a coordinate outside `private/`.

## Accessibility

- VoiceOver reads every control and every status.
- Colour is never the only signal: pair it with an icon or a word.
- Respect Reduce Motion.

## Checking a change

- **Screenshots** of the test copy (`app/scripts/test-copy.sh`) in the Earth look, at both window sizes.
- **Words counted** on the pages you touched, with the method in [HANDOFF.md](HANDOFF.md). Counts must not grow without a reason.
- **Speed:** `-measure YES` writes `perf.log`. A change adds no new stall over 250 ms.
