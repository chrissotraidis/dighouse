# Your first hour with Dighouse

Dighouse helps you look for earthworks and other remains that may not be on record yet, in open lidar: laser scans that see the ground through the trees. An AI agent does the slow work and writes down every step. You decide what each find is, and you decide whether to tell anyone. Nothing is ever called new: a find that matches nothing in the sources read is "no match in the sources read", and the people who keep the official record are the ones who can say more.

## What you need

- A Mac with Apple silicon (M1 or later) and macOS 14 or later.
- A ChatGPT account that can use Codex. Searches use your account's models and its usage.
- An internet connection. A search downloads a few megabytes of ground for each square km.

## Install it

Download `Dighouse-<version>.dmg` from the [releases page](https://github.com/chrissotraidis/dighouse/releases), open it and drag Dighouse to Applications. It is signed and notarized by Apple, so it opens like any app you download.

To build it yourself instead, see [SETUP.md](SETUP.md).

## The first launch

Dighouse shows a short checklist and fixes what it can:

1. **Agent engine (Codex).** If your Mac has none, press **Install it**: Dighouse downloads OpenAI's Codex engine from its GitHub releases into its own folder.
2. **Signed in.** Press **Sign in with ChatGPT**. Your browser opens; sign in there. Dighouse never sees your password.
3. **Archaeology tools.** Dighouse prepares its tools, about a minute the first time. A downloaded Dighouse carries everything they need.
4. **AI models.** Pick the model that runs the search. It must be able to read images.

## Your first search

There are two good first steps.

- **The first project at Serpent Mound**, about ten minutes, one step at a time: get the ground, look at it, open a find, read its record and decide what it is.
- **Find something.** Press it on Home and choose how long (an hour is a good start). The agent picks a region with open lidar and little on record, preferring one where a site register is open, names a project after it, and searches it area by area. Every tile is looked at in bulk by a low-cost model, then the agent looks closely where something showed, measures each find, checks open maps and the records, and searches what is published. You can watch, steer or stop it at any point.

At the top of every project, a line says what a search there can do:

- **Can find and check**: open lidar, and an official site register Dighouse reads in full (Norway; Denmark once its free token is set). Each find is checked against it.
- **Can find, not fully check**: open lidar, but the official record is closed or partial (the United States; England and Navarre, whose open lists hold protected sites only; most other places). A find there can only be checked against open lists, so the office that keeps the record is the one to ask.
- **No open lidar yet**: Dighouse cannot search there.

## Deciding

What needs you waits on Home under **Waiting for you**, across every project. Press **Decide**:

- **Needs you** shows one find at a time: a close view, the whole tile, a slice through the laser points, and what the agent and a second model think. Return agrees; a letter picks another decision and asks for your reason.
- **Agree in bulk** shows routine finds as a grid; untick any that look wrong.
- **Done** lists what you decided, with Undo.

Measured rises and shapes the bulk look pointed at that nothing else supports stay on the map instead of being put to you. You can raise any of them.

On the Map, the pin-and-circle button marks what you see yourself: click a spot and it becomes a find with the usual checks, or drag a box and the agent looks closely at the tiles under it.

## If something looks real

- **Do not post the location anywhere public, and do not dig or remove anything.** In most countries that needs a permit, and a published location invites looting.
- Mark it **Worth reporting** in Decide.
- In the project's Data tab, **A question for the records office** drafts a short letter asking whether it is already recorded, where the official record is closed. It holds the location, so it is kept under `private/`. **A report for the heritage authority** drafts a report to the body Dighouse names for that country. You read both and send them yourself.

## What stays on your Mac

- Every project is a folder of Markdown records with its own history. Locations live only under its `private/` folder, which never leaves your Mac or goes into its history.
- The models see pictures of the ground and the project's records, through your ChatGPT account (and, if you use the OpenCodex router, through the providers you set up there).
- Downloads are kept in `~/.cache/dighouse`, so a second look at the same ground is quick. Laser points no project uses are kept up to 10 GB, oldest dropped first; a project's own points are never dropped.
- **Publish to GitHub** checks that no location would leave your Mac before it makes a private repository.

## When something goes wrong

- **A search is slow.** Looking at tiles in bulk needs a direct line to a model, through the [OpenCodex](https://github.com/lidge-jun/opencodex) router. Without it the agent looks at every tile itself, which takes a few times longer.
- **Second opinions from the same maker.** By default the second opinion is GPT-6 Luna on your ChatGPT account, the lowest-cost choice, and the record says when it comes from the same maker as the agent. With OpenCodex you can choose Claude Sonnet 5.5 in Settings, Models, which finds more of the known features.
- **Second opinions wait.** They pause while less than 20% of your account's usage is left and carry on when it resets; a search closes, saving its record, below 10%.
- **Denmark's ground needs a token.** Get a free one from Dataforsyningen and paste it in Settings, Data and privacy.
- **A data service does not answer.** National services go down for a while now and then. The search says which, carries on with the rest, and the check can be run again later.
- **Something else.** [SETUP.md](SETUP.md) covers where projects and chats are kept and more fixes.
- **Still stuck.** Ask in **dighouse-help** on [Discord](https://discord.gg/xwHfUD2bxW): when you join, pick **Dighouse (lidar archaeology)**. Leave out anything that shows where a find is.
