#!/usr/bin/env python3
"""Synthesizes the LUDO X sound effects (stdlib only) into assets/sfx/*.wav.
All sounds are generated from scratch here: layered harmonics, filtered noise,
pitch glides and a short echo for a polished arcade feel."""
import math, os, random, struct, wave

SR = 22050
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'assets', 'sfx')
os.makedirs(OUT, exist_ok=True)
random.seed(11)


def write(name, samples, gain=0.88):
    peak = max(1e-9, max(abs(s) for s in samples))
    data = b''.join(struct.pack('<h', int(max(-1, min(1, s / peak * gain)) * 32767)) for s in samples)
    with wave.open(os.path.join(OUT, name + '.wav'), 'wb') as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR); w.writeframes(data)


def adsr(i, n, a=0.01, d=0.15, s=0.6, r=0.3):
    t = i / n
    if t < a: return t / a
    if t < a + d: return 1 - (1 - s) * (t - a) / d
    if t < 1 - r: return s
    return max(0.0, s * (1 - (t - (1 - r)) / r))


def tone(f0, dur, f1=None, harm=(1.0, 0.4, 0.2), vol=1.0, a=0.01, d=0.15, s=0.6, r=0.35, vib=0.0):
    n = int(SR * dur); out = []; ph = 0.0
    f1 = f0 if f1 is None else f1
    for i in range(n):
        f = f0 + (f1 - f0) * (i / n)
        if vib: f *= 1 + vib * math.sin(2 * math.pi * 6 * i / SR)
        ph += 2 * math.pi * f / SR
        v = sum(h * math.sin(ph * (k + 1)) for k, h in enumerate(harm))
        out.append(v * adsr(i, n, a, d, s, r) * vol)
    return out


def noise(dur, vol=1.0, decay=5.0, lp=0.0):
    n = int(SR * dur); out = []; y = 0.0
    for i in range(n):
        x = random.random() * 2 - 1
        y = y + (x - y) * (1 - lp) if lp else x
        out.append(y * vol * math.exp(-decay * i / n))
    return out


def silence(d): return [0.0] * int(SR * d)


def mix(*tracks):
    n = max(len(t) for t in tracks)
    return [sum(t[i] if i < len(t) else 0 for t in tracks) for i in range(n)]


def at(track, delay):
    return silence(delay) + track


def echo(x, delay=0.11, fb=0.35, times=3):
    out = list(x) + [0.0] * int(SR * delay * times)
    for k in range(1, times + 1):
        off = int(SR * delay * k)
        for i, v in enumerate(x):
            out[i + off] += v * (fb ** k)
    return out


# --- dice: wooden rattle of clacks that slows down, ends with a thump
rattle = []
t = 0.0
gap = 0.028
for k in range(12):
    click = mix(noise(0.03, 0.9 - k * 0.04, 9, lp=0.55), tone(900 - k * 25, 0.03, harm=(1, .3), vol=0.5, a=0.002, r=0.8))
    rattle = mix(rattle, at(click, t)) if rattle else click
    t += gap
    gap *= 1.13
thump = tone(150, 0.12, 90, harm=(1, .5), vol=1.0, a=0.003, r=0.9)
write('dice', mix(rattle, at(thump, t + 0.02)))

# --- pawn hop: quick woody pop with a tiny upward chirp
write('move', mix(tone(420, 0.09, 640, harm=(1, .35), vol=0.9, a=0.003, r=0.9), noise(0.04, 0.25, 12, lp=0.6)))

# --- capture: whoosh, impact, sad slide
whoosh = noise(0.25, 0.7, 2.5, lp=0.85)
impact = tone(190, 0.18, 70, harm=(1, .6, .3), vol=1.0, a=0.002, r=0.9)
slide = tone(520, 0.4, 170, harm=(1, .5), vol=0.55, a=0.01, r=0.5)
write('capture', mix(whoosh, at(impact, 0.12), at(slide, 0.14)))

# --- home: sparkly ascending chime with echo
notes = (659.25, 783.99, 987.77, 1318.5, 1567.98)
chime = []
for i, f in enumerate(notes):
    chime = mix(chime, at(tone(f, 0.28, harm=(1, .35, .15), vol=0.8, a=0.004, d=0.2, s=0.3, r=0.6), i * 0.075)) if chime else tone(f, 0.28, harm=(1, .35, .15), vol=0.8, a=0.004, d=0.2, s=0.3, r=0.6)
write('home', echo(chime, 0.09, 0.3, 2))

# --- six: bright "ding-ding"
ding = tone(1046.5, 0.14, harm=(1, .4, .2), vol=0.9, a=0.003, r=0.7)
write('six', echo(mix(ding, at(tone(1568, 0.22, harm=(1, .4, .2), vol=0.9, a=0.003, r=0.7), 0.1)), 0.1, 0.3, 2))

# --- win: layered fanfare
fan = []
seq = ((523.25, 0.0, 0.13), (659.25, 0.13, 0.13), (783.99, 0.26, 0.13), (1046.5, 0.39, 0.34),
       (783.99, 0.76, 0.12), (1046.5, 0.88, 0.5))
for f, st, d in seq:
    note = mix(tone(f, d + 0.1, harm=(1, .5, .3, .15), vol=0.8, a=0.006, d=0.1, s=0.7, r=0.4, vib=0.004),
               tone(f / 2, d + 0.1, harm=(1, .3), vol=0.4, a=0.006, r=0.4))
    fan = mix(fan, at(note, st)) if fan else note
write('win', echo(fan, 0.13, 0.28, 3))

# --- tick: urgent timer blip
write('tick', tone(1500, 0.06, 1200, harm=(1, .2), vol=0.8, a=0.002, r=0.8))

# --- tap: soft UI pop
write('tap', mix(tone(700, 0.07, 480, harm=(1, .25), vol=0.9, a=0.002, r=0.9), noise(0.02, 0.15, 14, lp=0.7)))

# --- levelup: rising run + sparkle
run = []
for i, f in enumerate((392.0, 523.25, 659.25, 783.99, 1046.5, 1318.5)):
    nt = tone(f, 0.2, harm=(1, .45, .2), vol=0.8, a=0.004, d=0.1, s=0.5, r=0.5)
    run = mix(run, at(nt, i * 0.07)) if run else nt
write('levelup', echo(run, 0.1, 0.32, 3))

# --- coin: classic two-note "ka-ching"
coin = mix(tone(988, 0.08, harm=(1, .5, .3), vol=0.9, a=0.002, r=0.6),
           at(tone(1319, 0.35, harm=(1, .5, .3), vol=0.9, a=0.002, d=0.25, s=0.3, r=0.6), 0.08))
write('coin', echo(coin, 0.07, 0.25, 2))

print('sfx written:', ', '.join(sorted(f for f in os.listdir(OUT))))
