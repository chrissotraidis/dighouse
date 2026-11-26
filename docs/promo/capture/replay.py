"""Replay a finished real search into the app's live map: the tiles get their recorded verdicts and the finds arrive in the
order the run's own log gives, a couple of seconds apart, so the open project shows them as the store rereads the folder.
It made the live-map recording: reset, start winrec on the app's window, play, then finish to score the test.
Usage: replay.py <finished project> <copy to play into> reset | play [seconds between finds] | finish"""
import json, os, shutil, sys, time, glob, subprocess
SRC, DST = sys.argv[1], sys.argv[2]; sys.argv = sys.argv[2:]
def write(path, obj):
    tmp = path + ".tmp"; json.dump(obj, open(tmp, "w"), indent=1); os.replace(tmp, path)
def reset():
    if not os.path.exists(DST):
        os.mkdir(DST); subprocess.run(["ditto", SRC, DST], check=True)      # a folder made now, so the app adopts it
    st = DST + "/private/state/"
    for f in ("tiles.json", "rises.json", "test.json"): shutil.copy(SRC + "/private/state/" + f, st + f)
    tiles = json.load(open(st + "tiles.json"))
    for t in tiles.values():
        for k in ("verdict", "note", "model"): t.pop(k, None)
        t["status"] = "unscreened"
    write(st + "tiles.json", tiles); write(st + "locations.json", {})
    r = json.load(open(st + "rises.json")); write(st + "rises.json", type(r)())
    for f in ("score.json",):
        if os.path.exists(st + f): os.remove(st + f)
    if os.path.isdir(st + "score"): shutil.move(st + "score", DST + "-score-before-%d" % time.time())
    t = json.load(open(st + "test.json")); t.pop("scored", None); write(st + "test.json", t)
    for f in glob.glob(DST + "/candidates/C-*.md") + glob.glob(DST + "/candidates/img/*"): os.remove(f)
    print("reset", len(tiles), "tiles")
def play(gap):
    st = DST + "/private/state/"; sst = SRC + "/private/state/"
    final = json.load(open(sst + "tiles.json")); locs = json.load(open(sst + "locations.json"))
    order = sorted(final)      # row by row, as the run's log has them
    by_tile = {}
    for cid in sorted(locs):
        by_tile.setdefault(locs[cid]["tile"], []).append(cid)
    seen = [c for c in sorted(locs) if "Measured rise" not in open(SRC + f"/candidates/{c}.md").read(400)]
    t0 = time.time(); log = []
    def mark(what): log.append((round(time.time() - t0, 2), what)); print(log[-1], flush=True)
    time.sleep(3); mark("start")
    for name in order:
        tiles = json.load(open(st + "tiles.json")); tiles[name] = final[name]; write(st + "tiles.json", tiles); mark("tile " + name[-8:] + " " + str(final[name].get("verdict")))
        time.sleep(gap)
        for cid in [c for c in by_tile.get(name, []) if c in seen]:
            for f in glob.glob(SRC + f"/candidates/img/{cid}-*"): shutil.copy(f, DST + "/candidates/img/")
            shutil.copy(SRC + f"/candidates/{cid}.md", DST + f"/candidates/{cid}.md")
            cur = json.load(open(st + "locations.json")); cur[cid] = locs[cid]; write(st + "locations.json", cur); mark("find " + cid)
            time.sleep(gap)
    rest = [c for c in sorted(locs) if c not in seen]
    for cid in rest:
        for f in glob.glob(SRC + f"/candidates/img/{cid}-*"): shutil.copy(f, DST + "/candidates/img/")
        shutil.copy(SRC + f"/candidates/{cid}.md", DST + f"/candidates/{cid}.md")
    cur = json.load(open(st + "locations.json")); cur.update({c: locs[c] for c in rest}); write(st + "locations.json", cur)
    shutil.copy(sst + "rises.json", st + "rises.json"); mark("measured rises " + str(len(rest)))
    json.dump(log, open(DST + "-replay-log.json", "w"))
def finish():
    st = DST + "/private/state/"; sst = SRC + "/private/state/"
    if os.path.isdir(sst + "score") and not os.path.isdir(st + "score"): shutil.copytree(sst + "score", st + "score")
    shutil.copy(sst + "score.json", st + "score.json"); shutil.copy(sst + "test.json", st + "test.json"); print("scored")
if sys.argv[1] == "reset": reset()
elif sys.argv[1] == "play": play(float(sys.argv[2]) if len(sys.argv) > 2 else 2.0)
else: finish()

