# Dighouse open-concerns loop

Started 2026-11-25. Read [HANDOFF.md](HANDOFF.md) and the first four sections of [ROADMAP.md](ROADMAP.md) first: this loop works through them. Chris asked: "make a goal loop based on this and run it to resolve these open concerns."

## Decisions taken for this loop

- **Searched areas stay on this Mac.** Sharing them with other people, even as coarse squares, would break "locations stay private". The layer is local.
- **Both kinds of reviewer.** A person who decides finds themselves gets a short list and short Decide sessions; a person who hands leads to an archaeologist or a records office gets the lead's progress and a deliberate step for the location.
- **Not in this loop: decisions that teach the ranking.** It changes which finds a person sees, so it needs the blind tests, and the account is at 5%. It stays on the roadmap.

## Goals

Each goal is done when its check passes in the running test copy. Record the date and what was seen in the Log.

| Goal | What | Check |
|---|---|---|
| O1 | **Awake while working.** The Mac does not sleep while a search, a timed session or second opinions run. | An activity is held while work runs and released when it stops (seen in `pmset -g assertions`). |
| O2 | **Notifications.** One when a search reports back or a session ends, one when second opinions finish. Not for steps. Only while the app is not in front. | Permission is asked once, at the first search; a notification arrives from a rehearsal with the app behind. |
| O3 | **Updates.** At launch, at most once a day, the app asks GitHub for the latest release and, if newer, shows a quiet line on Home and in Settings. Nothing is downloaded. | With a newer version faked, the line shows; offline or with the repository private, nothing shows and nothing breaks. |
| O4 | **Disk use.** Settings shows what projects' downloads and the cache take, and frees the cache's points no project holds, as `scripts/tidy.py` does. Projects are never touched. | Sizes match `du`; freeing removes only unheld cache files, after a confirmation that says how much. |
| O5 | **Report a problem.** A button opens a new GitHub issue filled with the version, macOS and the last log lines, coordinates taken out. The person reads it and submits it. | The opened page shows the text, with a planted coordinate removed. |
| O6 | **What each plan gets.** GETTING_STARTED says what works with ChatGPT, an OpenAI API key and Claude, and what was not measured. | The page reads plainly and matches Settings. |
| O7 | **A short list.** Home shows the strongest leads across all projects, a few at most; a press opens Decide on that find. | The list shows on Home from the kept glances, without reading every record again. |
| O8 | **Short Decide sessions.** Decide can be started on the strongest twenty, and says "8 of 20". | Started from Home's short list or a project, it stops at twenty with a Done step. |
| O9 | **A lead's progress.** A find marked worth reporting can be marked sent, answered (already recorded, or recorded as new) or visited, with a date; the record, the research record and the report say it. | Marked in the app; the record file holds it; the research record lists it. |
| O10 | **Where you have searched.** Home's map and New project's show the areas every project has covered. | The test Mac's projects show as outlines in the right places. |
| O11 | **Finds per square km in the benchmark.** The scorecard and the benchmark table say how many finds a person would look at per square km, beside how many known features were found. | A scored blind test shows both. |
| O12 | **A tidier docs folder.** Finished loop logs move to `docs/loops/` with an index; every link still works. | A link check over the repository finds no broken relative links. |

## Log

- **O1 to O6, the day-one basics** (2026-11-25). All in `Basics.swift`.
  - **O1, awake.** While an agent's turn or goal, or second opinions, run (`AppState.working`), Dighouse holds a `ProcessInfo` activity that stops idle sleep; the screen may still sleep, and closing the lid on battery still sleeps the Mac. Seen in the test copy: one short message to primary / 6.1 Terra ("Reply with the single word: ready"); `pmset -g assertions` showed "PreventUserIdleSystemSleep named: Dighouse is working" from Dighouse for the three seconds of the turn, and nothing after.
  - **O2, notifications.** One when the search report is written, one when a timed session ends, one when the last second opinion is back; none when Dighouse is in front. Permission is asked once, the first time work starts. A rehearsal (`-measure YES -noticeTest YES`, Finder in front) posted one and macOS listed it as delivered; the test copy's permission read "denied" in the system, so the banner itself was not seen. Allowing it is the person's choice in System Settings.
  - **O3, updates.** At most once a day the app asks GitHub's API for the latest release's number; a newer one shows a quiet line on Home and in Settings, Advanced, About, with What is new. A switch there turns the check off, and Data and keys lists it under What leaves this Mac. Seen with `-fakeLatest 9.9.9`: "Dighouse 9.9.9 is out. You have 0.2.0." on Home and in About. The repository is private, so the real request gets no release and nothing shows, as intended.
  - **O4, space.** Data and keys, Space on this Mac: the projects' folders and the download cache, a file linked from both counted once, and the cache's points no project holds. The test copy, pointed at a scratch cache (`open --env DIGHOUSE_CACHE=...`) with one loose and one held download, showed "Projects 44.21 GB, downloads kept for later 8 MB. 5 MB of those are held by no project."; `du` over the same 104 folders gave 43,173,656 KB (44.2 GB) and 7.8 MB. Free 5 MB asked first, inline; Cancel was checked in the app; the removal itself is checked by an app test (a loose file and its note go, a file a project holds stays).
  - **O5, report a problem.** Settings, Advanced, About, Report…: opens GitHub's new issue page with versions, models and any engine problem filled in, coordinates and the home folder taken out. Pressed in the test copy: the browser opened "New issue" with the text. An app test checks that coordinates and the home folder are removed and ordinary numbers kept. There is no app log to attach; perf.log is included when the app runs with `-measure YES`.
  - **O6, which account.** GETTING_STARTED has a table: ChatGPT with Codex, an OpenAI API key, a Claude plan, and the tools without the app, with what was measured (Pro only, about 1.6% an hour) and what was not. The README links to it. Also: the Mac and sleep, new versions, space and Report a problem are in its lists.
