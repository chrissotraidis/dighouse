"""The promo's soundtrack: Oak Felder's "Seeking Light" stems (Apple Loops), 98 BPM, B minor, arranged to the one-minute cut.
The same stems as the 30-second cut, over three turns of their eight bars (26.5 bars, 65 s):
  bar 0        piano and bells under the scan and the title
  bars 1-7.5   a pulse and low end while the trees lift and the ground holds; hats join at bar 5
  bars 7.5-8   half a bar of air
  bars 8-14    the full kit as the search runs and the scorecard lands
  bars 14-16   drums out for the slice, the choir comes in
  bars 16-24   the full kit and the choir through the views, the decision and the other kinds of site
  bars 24-26.5 drums out for the end card, the piano and choir ring and fade"""
import subprocess, numpy as np, wave, glob, os
SR = 44100; BAR = 4 * 60 / 98; BARS = 26.5; N = int(BARS * BAR * SR)
def load(name):
    p = glob.glob(f"/Library/Audio/Apple Loops/**/Seeking Light {name}.caf", recursive=True)[0]
    raw = subprocess.run(["ffmpeg", "-v", "error", "-i", p, "-ac", "2", "-ar", str(SR), "-f", "f32le", "-"], capture_output=True).stdout
    return np.frombuffer(raw, np.float32).reshape(-1, 2).astype(np.float64)
cache = {}; mix = np.zeros((N, 2))
def place(name, bar, nbars, gain=1.0, ramp=None, fade_in=0.008, fade_out=0.03):
    if name not in cache: cache[name] = load(name)
    a = cache[name]; s = int(bar * BAR * SR); n = min(int(nbars * BAR * SR), N - s)
    seg = a[(int((bar % 8) * BAR * SR) + np.arange(n)) % len(a)]
    e = np.ones(n); fi, fo = max(1, int(fade_in * SR)), max(1, int(fade_out * SR))
    e[:fi] = np.linspace(0, 1, fi); e[-fo:] *= np.linspace(1, 0, fo)
    if ramp: e *= np.linspace(ramp[0], ramp[1], n) ** 1.5
    mix[s:s + n] += seg * (e * gain)[:, None]
KIT = [("Kick", 1.0), ("Snare 01", 0.9), ("Hi-Hat", 0.8), ("Percussion", 0.7), ("Sub Bass 01", 0.95)]
place("Piano 01", 0, BARS, 1.0)
place("Bells", 0, BARS, 0.8, fade_in=0.3)
place("FX", 0, 1, 0.8, fade_in=0.8)
# the pulse under the point cloud
place("Kick", 1, 6.5, 0.95); place("Sub Bass 01", 1, 6.5, 0.9); place("Percussion", 1, 6.5, 0.7)
place("Hi-Hat", 5, 2.5, 0.6, ramp=(0.4, 1.0))
place("FX", 7, 1, 0.6, fade_in=1.2)
# the search
for stem, g in KIT: place(stem, 8, 6, g)
place("FX", 8, 1, 0.7)
# the slice: drums out, choir in
place("Sub Bass 01", 14, 2, 0.8)
place("Vox 01", 14, 12.5, 0.8, fade_in=0.5)
place("FX", 15, 1, 0.6, fade_in=1.0)
# the views and the decision
for stem, g in KIT: place(stem, 16, 8, g)
place("FX", 16, 1, 0.7); place("FX", 20, 1, 0.5)
# the end card
place("FX", 22, 1, 0.5)
place("FX", 24, 1, 0.8, fade_in=0.01)
place("Sub Bass 01", 24, 2.5, 0.7, ramp=(1, 0.1))
f = np.ones(N); i0 = int(25.3 * BAR * SR); f[i0:] = np.linspace(1, 0, N - i0) ** 1.6
mix *= f[:, None]
mix = mix / np.abs(mix).max() * 0.89
os.makedirs("build", exist_ok=True)
with wave.open("build/music.wav", "wb") as w:
    w.setnchannels(2); w.setsampwidth(2); w.setframerate(SR); w.writeframes((mix * 32767).astype(np.int16).tobytes())
# a loudness line per bar, to check the arrangement by eye
rms = [float(np.sqrt((mix[int(b * BAR * SR):int((b + 0.5) * BAR * SR)] ** 2).mean())) for b in np.arange(0, BARS, 0.5)]
print("build/music.wav", round(N / SR, 2), sorted(cache)); print(" ".join(f"{20 * np.log10(max(r, 1e-6)):.0f}" for r in rms))

