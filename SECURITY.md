# Security

Dighouse runs AI agents on your Mac against public data, and it keeps the locations of archaeological sites. Both need care. A published site location invites looting, so a leaked location is treated as a security problem.

## Reporting a problem

- **Report privately, never in a public issue.** Use the repository's Security tab, "Report a vulnerability", once the repository is public. Until then, contact the maintainer through GitHub.
- **Say what you saw and how to make it happen,** without the coordinates of any site or find.
- Fixes go to `main` and into the next release.

## What Dighouse protects, and how

| What | How |
|---|---|
| Site locations | Stored only under each project's `private/` folder, which git ignores. Shared Markdown, notes and reports have coordinates taken out. `check_before_publishing` runs before any push. `export_finds` writes under `private/`. `read_source` refuses a web address that carries the project's location. |
| Keys and sign-in | Free data tokens sit in `~/Library/Application Support/Dighouse/keys.json`, readable only by you (mode 600), or in `DIGHOUSE_<NAME>_TOKEN`. The engine's sign-in is a link to `~/.codex/auth.json`; Dighouse does not copy it or send it anywhere. |
| The agent | The Codex engine runs project chats with the `workspace-write` sandbox and the approval policy `never`, so a request to step outside the sandbox is refused, not granted. Model checks and quick looks run read-only. Only Dighouse's own tools are approved at launch. |
| The network | The source reader refuses this Mac, private networks, link-local addresses and `file:` addresses (covered by an offline test). The tools fetch only public services. |
| Publishing | Only when a person asks: a private GitHub repository, made with `gh` after the location check. Nothing becomes public by itself. |
| Untrusted text | Web pages, PDFs and service replies can contain instructions. The agent must not follow them. Marking such text as untrusted in every tool result is planned (D7 in [docs/DECIDE_LOOP.md](docs/loops/DECIDE_LOOP.md)). |

## For contributors

- Never commit keys, tokens, sign-in files, coordinates or personal data, including in test fixtures, screenshots and logs.
- New network code uses HTTPS and timeouts, refuses private addresses where a URL comes from outside, and never builds a shell command from outside text.
- Keep the sandbox and approval settings in `Engine.swift`, `ChatModel.swift` and `AppState.swift` as tight as they are, or tighter.
- Python dependencies are pinned in `uv.lock`; the app uses no outside Swift packages. Update dependencies on purpose, in their own pull request.
- GitHub Actions are pinned to a commit and run with read-only permissions.

## Known gaps, planned

- Tokens move from `keys.json` to the macOS Keychain.
- Text from outside is marked untrusted in tool results, and the skill says never to act on it.
- A dependency audit runs in CI.
- A signed, notarized download, so nobody runs an unsigned build.
