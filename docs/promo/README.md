# The promo video

A 65-second film for the first public release, 1920 × 1080, cut to a 98 BPM track. Everything needed to build it again is in this folder.

What it shows is real: 3D renders of open USGS lidar at Serpent Mound and Angel Mounds, and the app itself at Mound City and Angel Mounds. All three sites are published and open to visitors. Nothing here holds a coordinate.

## Build it

~~~sh
docs/promo/build.sh
~~~

It needs a Mac (the captions use the system font), `ffmpeg`, and `python3` with numpy and Pillow. It renders the 3D shots, then the film, then lays the music under it, in about two minutes on an M3 Max. The film is `build/dighouse-promo.mp4`. The `build` folder is not committed.

To change a caption, edit it in `render()` in `render.py`. Once the 3D shots exist, `python3 render.py 31.5` writes one still, at that second, to `build`.

## What is here

| File | What it is |
|---|---|
| `render.py` | The film: every shot, caption and cut, counted in bars of the music. |
| `cloud_render.py` | The Serpent Mound shots: the treetops lifting off the ground, the slice, and the end card. |
| `mound_render.py` | Mound A at Angel Mounds turning in 3D, its heights stretched from ×1 to ×4. |
| `source/serpent-cloud.npz` | Serpent Mound: the bare-ground model and 2.4 million returns from the trees, in metres from the middle of the tile. Made by `cloud_prep.py`. |
| `source/angel-mound.npz` | The ground 380 m around Mound A, as heights. Made by `mound_prep.py`. |
| `source/clips` | Recordings of the app: the live map and its panel during the search, and the nine close views. |
| `source/stills` | The app's scorecard, Decide card and 3D view, and the pictures its tools made for one find: nine views and two flights. |
| `music` | The soundtrack, as FLAC for the build and MP3 to share. `music.py` is its arrangement. |
| `capture` | How the app footage was taken. |

## Where each shot comes from

- **Serpent Mound, Ohio.** One tile of open USGS lidar, 7,020,212 returns, from a Dighouse project's downloads.
- **Mound City Group, Ohio.** The live map and the scorecard are a blind test run on 2026-11-22, which found 19 of 19 published features in four minutes. No new search was run for the film. The test's results were played back into the app's live map in the order of the run's log, at an even pace, with `capture/replay.py`. The film says "Replay of a real blind test".
- **Angel Mounds, Indiana.** The Decide card, the nine views and the two flights (2013 and 2019) are find C-003 in a project begun on 2026-11-12. The large 3D shot of Mound A is rendered here from the same ground model. The small one beside it is the app's own 3D view.
- **The four places near the end** are pictures the app already carries, in `app/Resources/starts`.

The app was version 0.2.0, recorded on 2026-11-26 with `capture/winrec.swift`, which records one window without the pointer.

## The music

Oak Felder's "Seeking Light" stems from Apple's loop library (GarageBand and Logic), 98 BPM, arranged in `music.py` over 26.5 bars. On a Mac with those loops installed, `python3 music.py` writes the mix again to `build/music.wav`. The stems are Apple's and are not stored here. Read Apple's terms for its loops before using the track outside the film.
