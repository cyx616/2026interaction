"""Create a short ORIGINAL pop-style MIDI demo (no copyrighted melody)."""
from pathlib import Path
import pretty_midi

OUT = Path(__file__).with_name('demo_original.mid')
BPM = 125
beat = 60.0 / BPM
pm = pretty_midi.PrettyMIDI(initial_tempo=BPM)
melody = pretty_midi.Instrument(program=80, name='Original melody')
# 16 bars of original C-major pop-style motifs, each contains 8 eighth notes.
# Pitches selected by hand to harmonize with C-G-Am-F repeating chord progression.
bars = [
 [76,79,81,79,76,74,72,76],  # C
 [74,79,83,81,79,74,71,74],  # G
 [76,81,84,83,81,79,76,72],  # Am
 [77,81,79,77,76,72,69,72],  # F
 [76,76,79,81,79,76,72,74],
 [79,79,83,81,79,74,71,74],
 [81,81,84,83,81,76,72,76],
 [77,79,81,79,77,76,74,72],
 [84,83,81,79,76,79,81,79],
 [83,81,79,74,79,81,83,79],
 [84,84,83,81,79,76,81,79],
 [81,79,77,76,77,79,76,72],
 [76,79,81,84,83,81,79,76],
 [79,83,86,83,81,79,74,71],
 [81,84,83,81,79,76,72,76],
 [77,76,74,72,76,74,72,72],
]
for bar_index, pitches in enumerate(bars):
    for i, pitch in enumerate(pitches):
        start = (bar_index * 4 + i * .5) * beat
        # Give some natural note separation and accents.
        dur = beat * (0.37 if i % 4 != 0 else 0.44)
        velocity = 108 if i in (0,4) else 84
        melody.notes.append(pretty_midi.Note(pitch=pitch, velocity=velocity, start=start, end=start+dur))
pm.instruments.append(melody)
pm.write(str(OUT))
print(f'Wrote ORIGINAL demo: {OUT} ({len(melody.notes)} melody notes)')
