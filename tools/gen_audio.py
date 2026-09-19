"""Procedural SFX and music (numpy -> 16-bit mono WAV). Run: python tools/gen_audio.py"""
import os
import wave

import numpy as np

SR = 22050
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "audio")
RNG = np.random.default_rng(42)


def t_axis(dur):
    return np.linspace(0, dur, int(SR * dur), endpoint=False)


def env(n, attack=0.005, decay=None):
    """Percussive envelope: fast attack then exponential decay."""
    t = np.arange(n) / SR
    e = np.exp(-t * (decay if decay else 8.0 / (n / SR)))
    a = int(SR * attack)
    if a > 0:
        e[:a] *= np.linspace(0, 1, a)
    return e


def sine(freq, dur, vol=1.0):
    return vol * np.sin(2 * np.pi * freq * t_axis(dur))


def sweep(f0, f1, dur, vol=1.0):
    t = t_axis(dur)
    f = f0 + (f1 - f0) * (t / dur)
    return vol * np.sin(2 * np.pi * np.cumsum(f) / SR)


def noise(dur, vol=1.0):
    return vol * RNG.uniform(-1, 1, int(SR * dur))


def lowpass(x, k):
    kernel = np.ones(k) / k
    return np.convolve(x, kernel, mode="same")


def square(freq, dur, vol=1.0):
    return vol * np.sign(np.sin(2 * np.pi * freq * t_axis(dur)))


def notes(freqs, each, vol=0.6, wave_fn=sine):
    return np.concatenate([wave_fn(f, each, vol) * env(int(SR * each), decay=6.0) for f in freqs])


def save(name, data, sub="sfx"):
    data = np.asarray(data, dtype=np.float64)
    peak = max(1e-9, np.max(np.abs(data)))
    data = data / peak * 0.85
    pcm = (data * 32767).astype(np.int16)
    path = os.path.join(OUT, sub, name + ".wav")
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(pcm.tobytes())


def build_sfx():
    n = int(SR * 0.12)
    save("hit", lowpass(noise(0.12), 6) * env(n, decay=30) + sine(120, 0.12) * env(n, decay=25))
    save("miss", noise(0.15) * env(int(SR * 0.15), attack=0.03, decay=18) * 0.5)
    n = int(SR * 0.25)
    save("hurt", sweep(220, 80, 0.25) * env(n, decay=10) + noise(0.25, 0.3) * env(n, decay=20))
    save("pickup", notes([660, 880], 0.07))
    save("gold", notes([1200, 1600], 0.06, wave_fn=square, vol=0.3))
    save("stairs", notes([523, 440, 349, 262], 0.09))
    save("levelup", notes([523, 659, 784, 1047], 0.1))
    n = int(SR * 0.9)
    save("death", sweep(400, 60, 0.9) * env(n, decay=3.5) + noise(0.9, 0.2) * env(n, decay=6))
    n = int(SR * 0.3)
    save("skill", sweep(300, 1200, 0.3) * env(n, attack=0.02, decay=6))
    t = t_axis(0.3)
    save("potion", np.sin(2 * np.pi * (300 + 100 * np.sin(2 * np.pi * 12 * t)) * t) * env(len(t), decay=7))
    n = int(SR * 0.3)
    save("scroll", lowpass(noise(0.3), 30) * env(n, attack=0.05, decay=8) + sweep(500, 900, 0.3, 0.3) * env(n, decay=8))
    n = int(SR * 0.15)
    save("equip", noise(0.15, 0.4) * env(n, decay=40) + sine(1500, 0.15) * env(n, decay=30))
    n = int(SR * 0.4)
    save("door", lowpass(square(85, 0.4, 0.6), 8) * env(n, attack=0.05, decay=4))
    n = int(SR * 0.25)
    save("trap", square(180, 0.25, 0.5) * env(n, decay=10) + noise(0.25, 0.3) * env(n, decay=14))
    save("click", sine(900, 0.03) * env(int(SR * 0.03), decay=60))
    save("victory", notes([523, 659, 784, 1047, 784, 1047, 1319], 0.14, vol=0.7))
    save("defeat", notes([392, 349, 311, 262], 0.25, vol=0.7))


def loop_fix(a, length, xf=SR):
    """Crossfade the tail into the head so the loop has no click."""
    head = a[:length].copy()
    tail = a[length:length + xf]
    fade = np.linspace(0, 1, xf)
    head[:xf] = head[:xf] * fade + tail * (1 - fade)
    return head


def bell(freq, dur):
    t = t_axis(dur)
    tone = sum(np.sin(2 * np.pi * freq * m * t) * a for m, a in ((1, 1.0), (2.76, 0.4), (5.4, 0.2)))
    return tone * np.exp(-t * 2.5)


def build_music():
    length = 16 * SR
    t = t_axis(17)
    pad = np.zeros_like(t)
    for f, a in ((55, 1.0), (82.5, 0.6), (110.4, 0.35), (165, 0.2)):
        pad += a * np.sin(2 * np.pi * f * t + 0.3 * np.sin(2 * np.pi * 0.11 * t))
    pad *= 0.6 + 0.4 * np.sin(2 * np.pi * (1 / 8) * t)
    for start in (2.0, 5.5, 9.0, 12.5):
        b = bell(int(RNG.choice([330, 392, 262, 440])), 3.0) * 0.25
        i = int(start * SR)
        pad[i:i + len(b)] += b
    save("ambient", loop_fix(pad, length), "music")

    length = 12 * SR
    t = t_axis(13)
    drone = np.sin(2 * np.pi * 65.4 * t) + np.sin(2 * np.pi * 69.3 * t)
    drone *= 0.7 + 0.3 * np.sin(2 * np.pi * 3 * t)
    for k in range(26):
        b = sine(50, 0.35) * env(int(SR * 0.35), decay=9) * 1.3
        i = int(k * 0.5 * SR)
        if i + len(b) <= len(drone):
            drone[i:i + len(b)] += b
    for start in (3.0, 7.0, 10.5):
        s = (sine(466, 1.2) + sine(494, 1.2)) * env(int(SR * 1.2), decay=3) * 0.25
        i = int(start * SR)
        drone[i:i + len(s)] += s
    save("boss", loop_fix(drone, length), "music")


if __name__ == "__main__":
    build_sfx()
    build_music()
    print("audio files:", sum(len(f) for _, _, f in os.walk(OUT)))
