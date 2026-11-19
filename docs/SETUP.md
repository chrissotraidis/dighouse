# Setting up Dighouse

Dighouse runs on a Mac with Apple silicon (M1 or later) and macOS 14 or later. Setup takes about fifteen minutes plus the Xcode download, most of it waiting.

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

1. **Welcome.** Dighouse checks that it can reach Codex and the tools, then prepares the tools, which takes about a minute the first time.
2. **Choose a model** in Settings, Models. The agent model must read images, because the agent looks at pictures of the ground. A cheaper model is fine to start.
3. **Optional: a second-opinion model.** Each find can get a second opinion from a model made by a different company. Choose one in Settings, Models. It works with any model your Codex setup offers from another maker. Without one, searches still run; finds are marked as having no second opinion.
4. **Try it.** On Home, press **Pick a place on the map** and click where you want to look: the shaded areas have open lidar. Or type a place such as *Serpent Mound, Ohio* and press **Find and report back**, or start the tutorial. A small search takes 5 to 15 minutes.

## Where things go

- **Projects** are folders in `~/Dighouse`, each with its own documents and git history. Choose *Work out of my GitHub folder* on New project to put one in `~/GitHub` instead.
- **Chats** are kept by Dighouse itself, in `~/Library/Application Support/Dighouse`. They do not appear in the Codex app.
- **Locations** of finds stay in each project's `private/` folder, on this Mac. Publishing a project to GitHub leaves them out, so keep your own backup of `private/` if the locations matter to you.

## If something goes wrong

| What you see | What to do |
|---|---|
| "Codex is not signed in" | In Terminal, run `codex login`, then press Restart in Settings, How it runs. |
| "Agent engine not found" | Install Codex (see above), then press Check again. |
| The tools never finish preparing | Check the Mac is online; quit and reopen Dighouse. |
| "The second model is refused" | Its provider turned the request down. Choose another model in Settings, Models. |
| A place "has no open data" | Dighouse only reaches places with open lidar or sonar. The map on Home, under Where you can search, shades them. |

## Updating

~~~sh
cd dighouse
git pull
./scripts/setup.sh
~~~

Your projects, chats and settings stay as they are.
