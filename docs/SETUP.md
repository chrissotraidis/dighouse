# Building Dighouse from source

Most people should download the app instead: see [GETTING_STARTED.md](GETTING_STARTED.md). This page is for building it yourself. Dighouse runs on a Mac with Apple silicon (M1 or later) and macOS 14 or later. Setup takes about fifteen minutes plus the Xcode download, most of it waiting.

## What you need

- **A ChatGPT account.** Dighouse's agent runs on Codex, OpenAI's agent engine, and uses the models your account can use.
- **Codex**, signed in. The Codex app, or the command-line version.
- **uv**, a small program that runs Dighouse's archaeology tools in their own Python.
- **Xcode**, Apple's developer app, to build Dighouse. It is free from the App Store; open it once after installing.

The setup script checks all four, offers to install what is missing, then builds and opens the app.

## Set it up

Open Terminal and run:

~~~sh
git clone https://github.com/chrissotraidis/dighouse.git
cd dighouse
./scripts/setup.sh
~~~

If the script stops, it says what to install and how. Do that, then run it again.

## The first launch

1. **Welcome.** A guide of three steps. It fetches the Codex engine if none is found and prepares the tools, which takes about a minute the first time. On its Set up step, **Sign in with ChatGPT** opens the sign-in page in your browser, or, without a ChatGPT plan, paste an OpenAI API key, billed to the key. With Claude Code on the Mac there is a third choice, **A Claude account**: Claude Code gets Dighouse's tools and runs the search, and you decide the finds in the app.
2. **Choose a model** in Settings, Account and models. The agent model must read images, because the agent looks at pictures of the ground. A cheaper model is fine to start.
3. **Optional: a second-opinion model.** Each find can get a second opinion from a model made by a different company: Claude Sonnet or Haiku through Claude Code, if you have it, or another maker's model through the OpenCodex router. Choose it in Settings, Account and models. Without one, the second opinion comes from a different model of the same maker (GPT-6 Luna by default), and the record says so.
4. **Try it.** On Home, press **Find something** and choose how long: the agent picks a region and searches it. Or press **Pick a place on the map** and click where you want to look, or start the ten-minute project at Serpent Mound. [GETTING_STARTED.md](GETTING_STARTED.md) explains what you will see.

## If you use Claude

The search inside the app runs on Codex, so the app's own chat needs a ChatGPT account or an OpenAI API key. With [Claude Code](https://docs.claude.com/en/docs/claude-code/setup) on the Mac, two more things work, both on the Claude card in Settings, Account and models. A person with Claude alone can choose **A Claude account** in the welcome guide, search from Claude Code and decide the finds in the app:

- **Second opinions from Claude.** Choose *Claude Sonnet, through Claude Code* (or Haiku). Each find's two pictures go to Claude Code with no tools, settings or memory of yours, and the answer is billed to your Claude account. Claude Code must be signed in: run `claude` in Terminal and `/login`.
- **Searching from Claude Code.** **Add to Claude Code** gives Claude Code Dighouse's tools and its search guide. Ask Claude Code to search a place; the project it makes appears in Dighouse, to look at and decide. **Remove** takes both out again. Without the OpenCodex router, a Claude Code search looks at each tile itself, which is slower than the bulk look; it is not yet held to the blind tests.

## Where things go

- **Projects** are folders in `~/Dighouse`, each with its own documents and git history. Choose *Work out of my GitHub folder* on New project to put one in `~/GitHub` instead.
- **Chats** are kept by Dighouse itself, in `~/Library/Application Support/Dighouse`. They do not appear in the Codex app.
- **Locations** of finds stay in each project's `private/` folder, on this Mac. Publishing a project to GitHub leaves them out, so keep your own backup of `private/` if the locations matter to you.

## If something goes wrong

| What you see | What to do |
|---|---|
| "Codex is not signed in" | Press **Sign in with ChatGPT** on the welcome checklist and finish signing in in your browser. |
| "Agent engine not found" | Press **Install it** on the welcome checklist, or install Codex yourself, then press Check again. |
| The tools never finish preparing | Check the Mac is online; quit and reopen Dighouse. |
| "The second model is refused" | Its provider turned the request down. Choose another model in Settings, Account and models. |
| A place "has no open data" | Dighouse only reaches places with open lidar or sonar. The map on Home, under Places to start, shades them. |

## Updating

~~~sh
cd dighouse
git pull
./scripts/setup.sh
~~~

Your projects, chats and settings stay as they are.
