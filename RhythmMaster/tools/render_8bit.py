"""Render a melody MIDI as cohesive retro 8-bit tracks for Processing.

- No machine learning happens here: this transforms MIDI notes into retro waveform audio.
- To use AI, first obtain MIDI via Basic Pitch, then pass that MIDI to this script.
- Optional chords must be verified for the actual song; never assume an automatic chord progression is correct.

Requirements: numpy, soundfile, pretty_midi
Example:
  python tools/render_8bit.py tools/demo_original.mid RhythmGame_Processing/data --bpm 125 --chords C,G,Am,F --title "PIXEL POP DEMO"
  python tools/render_8bit.py ai_output/song_basic_pitch.mid RhythmGame_Processing/data --bpm 120 --title "MY SONG"
"""
from __future__ import annotations

import argparse
import json
import math
import re
from pathlib import Path

import numpy as np
import pretty_midi
import soundfile as sf

SAMPLE_RATE = 32000
SEED = 2026
NOTE_NAMES = ['C','C#','D','D#','E','F','F#','G','G#','A','A#','B']
SEMITONES = {name: i for i, name in enumerate(NOTE_NAMES)}
SEMITONES.update({'Db':1,'Eb':3,'Gb':6,'Ab':8,'Bb':10})


def midi_hz(note):
    return 440.0 * 2.0 ** ((note - 69) / 12)


def envelope(size, attack=0.007, release=0.065, strength=1.0):
    if size <= 0:
        return np.zeros(0, dtype=np.float32)
    t = np.arange(size, dtype=np.float32) / SAMPLE_RATE
    length = size / SAMPLE_RATE
    a = np.clip(t / max(attack, 0.002), 0.0, 1.0)
    r = np.clip((length - t) / max(release, 0.005), 0.0, 1.0)
    decay = (0.76 + 0.24 * np.exp(-t / 0.1))
    return (a * r * decay * strength).astype(np.float32)


def waveform(frequency, size, patch):
    t = np.arange(size, dtype=np.float64) / SAMPLE_RATE
    phase = 2.0 * np.pi * frequency * t
    if patch == 'triangle':
        # Band-limited triangle harmonics sound softer than an aliased hard square.
        result = np.zeros(size, dtype=np.float64)
        limit = min(9, int(13500 // max(frequency, 1)))
        for n in range(1, limit + 1, 2):
            result += ((-1) ** ((n - 1) // 2)) * np.sin(phase * n) / (n ** 2)
        result *= 0.84
    elif patch == 'saw':
        result = np.zeros(size, dtype=np.float64)
        limit = min(14, int(13500 // max(frequency, 1)))
        for n in range(1, max(2, limit + 1)):
            result += ((-1) ** (n + 1)) * np.sin(phase * n) / n
        result *= 0.57
    else:  # 'pulse' 25% duty; harmonics are bandwidth-capped for a less harsh sound.
        result = np.zeros(size, dtype=np.float64)
        duty = 0.25
        limit = min(14, int(13500 // max(frequency, 1)))
        for n in range(1, max(2, limit + 1)):
            result += 2 / (np.pi * n) * np.sin(np.pi * n * duty) * np.cos(phase * n - np.pi * n * duty)
        result *= 1.05
    return result.astype(np.float32)


def place_note(track, start_sec, dur_sec, pitch, patch, gain=0.2):
    if start_sec < 0:
        return
    start = int(start_sec * SAMPLE_RATE)
    if start >= len(track):
        return
    n = min(int(dur_sec * SAMPLE_RATE), len(track) - start)
    if n < 16:
        return
    voice = waveform(midi_hz(pitch), n, patch)
    track[start:start + n] += voice * envelope(n) * gain


def place_drum(track, beat, kind, rng):
    start = int(max(0.0, beat) * SAMPLE_RATE)
    if start >= len(track):
        return
    seconds = {'kick':0.15,'snare':0.13,'hat':0.055}[kind]
    n = min(int(seconds * SAMPLE_RATE), len(track) - start)
    if n < 10:
        return
    t = np.arange(n) / SAMPLE_RATE
    if kind == 'kick':
        f = 58 + 110 * np.exp(-t * 40)
        wave = np.sin(2 * np.pi * np.cumsum(f) / SAMPLE_RATE)
        sample = wave * np.exp(-t * 26) * 0.21
    elif kind == 'snare':
        white = rng.standard_normal(n)
        high = white - np.convolve(white, np.ones(25)/25, mode='same')
        sample = high * np.exp(-t * 30) * 0.077
    else:
        white = rng.standard_normal(n)
        high = np.diff(white, prepend=0)
        sample = high * np.exp(-t * 78) * 0.028
    track[start:start + n] += sample.astype(np.float32)


def select_melody(midi, track=None, min_gap_ms=140):
    playable = [ins for ins in midi.instruments if not ins.is_drum]
    if track is not None:
        if track < 0 or track >= len(playable):
            raise ValueError(f'Invalid --track {track}; non-drum track count is {len(playable)}')
        source = list(playable[track].notes)
    else:
        source = [note for ins in playable for note in ins.notes]
    source = [n for n in source if 48 <= n.pitch <= 90 and 0.07 <= n.end - n.start <= 5.0 and n.start >= 0]
    source.sort(key=lambda n: (n.start, -n.pitch))
    # Group simultaneous notes. Highest-note selection is a heuristic, not an AI melody separator.
    selected = []
    i = 0
    while i < len(source):
        group = [source[i]]
        j = i + 1
        while j < len(source) and source[j].start - source[i].start <= 0.065:
            group.append(source[j])
            j += 1
        chosen = max(group, key=lambda n: (n.pitch, n.velocity))
        if not selected or (chosen.start - selected[-1].start) * 1000 >= min_gap_ms:
            selected.append(chosen)
        i = j
    if not selected:
        raise ValueError('No playable melody MIDI notes found; try a clean melody MIDI or lower the min-gap limit')
    return selected, len(source), len(playable)


def chord_midi(name):
    # Chord notation like C, F#, Am, Bb, Gm
    match = re.fullmatch(r'([A-G](?:#|b)?)(m?)', name.strip())
    if not match:
        raise ValueError(f'Unsupported chord {name!r}; examples: C,G,Am,F or Dm,Bb,F,C')
    root, minor = match.groups()
    pc = SEMITONES[root]
    # Bass in octave 3, arpeggio in octave 4.
    root_midi = 48 + pc
    return (root_midi, (0, 3 if minor else 4, 7))


def generate(midi_file, output_dir, bpm_override=0.0, chords='', title='8-BIT POP', track=None):
    midi = pretty_midi.PrettyMIDI(str(midi_file))
    notes, raw_count, track_count = select_melody(midi, track=track)
    times, bpms = midi.get_tempo_changes()
    raw_bpm = float(bpms[0]) if len(bpms) else 120.0
    bpm = bpm_override if bpm_override > 0 else raw_bpm
    if not (40 <= bpm <= 240):
        raise ValueError('BPM must be in 40..240')
    duration = max(max(n.end for n in notes) + 2.0, 8.0)
    if duration > 185.0:
        raise ValueError("Song exceeds 3 minutes. Trim to a shorter clip for this classroom demo.")
    samples = int(math.ceil(duration * SAMPLE_RATE))
    lead = {name: np.zeros(samples, dtype=np.float32) for name in ['pulse','triangle','saw']}
    bass = np.zeros(samples, dtype=np.float32)
    arp = np.zeros(samples, dtype=np.float32)
    drums = np.zeros(samples, dtype=np.float32)

    pitch_vals = [n.pitch for n in notes]
    lo, hi = min(pitch_vals), max(pitch_vals)
    chart = []
    for n in notes:
        # Use MIDI pitch range for the 4 rhythm lanes.
        lane = min(3, int((n.pitch - lo) * 4 / (hi - lo + 1))) if lo != hi else 1
        chart.append({'lane': lane, 'startMs': round(n.start * 1000),
                      'durationMs': round((n.end - n.start) * 1000),
                      'pitch': int(n.pitch), 'velocity': int(n.velocity)})
        for patch in lead:
            place_note(lead[patch], n.start, min(1.6, n.end - n.start + 0.04),
                       n.pitch, patch, gain=0.28*(max(50, n.velocity)/110.0))

    beat_len = 60.0 / bpm
    rng = np.random.default_rng(SEED)
    # These drums are generated from an assumed tempo/grid, NOT audio beat detection.
    beat_index = 0
    while beat_index * beat_len < duration - 0.2:
        start = beat_index * beat_len
        if beat_index % 4 in (0,2):
            place_drum(drums, start, 'kick', rng)
        if beat_index % 4 in (1,3):
            place_drum(drums, start, 'snare', rng)
        place_drum(drums, start, 'hat', rng)
        place_drum(drums, start + beat_len * 0.5, 'hat', rng)
        beat_index += 1

    progression = []
    if chords.strip():
        progression = [c.strip() for c in chords.split(',') if c.strip()]
        for chord in progression: chord_midi(chord)
        # Music harmony is only generated with user-verified chords; wrong chords sound dissonant.
        bar_len = beat_len * 4
        bar = 0
        while bar * bar_len < duration - .25:
            root_midi, intervals = chord_midi(progression[bar % len(progression)])
            start = bar * bar_len
            for b in (0,2):
                place_note(bass, start+b*beat_len, beat_len*.75, root_midi-12, 'triangle', 0.35)
            # 8ths arpeggio, quiet enough to avoid obscuring the melody.
            for step in range(8):
                tone = intervals[[0,1,2,1,0,1,2,1][step]]
                place_note(arp, start + step*beat_len*.5,
                           beat_len*.38, root_midi + 12 + tone, 'pulse', 0.09)
            bar += 1

    all_audio = (lead['pulse'] + bass + arp + drums)
    peak = float(np.max(np.abs(all_audio)))
    scale = min(1.4, 0.90 / max(peak, 0.001))
    output_dir.mkdir(parents=True, exist_ok=True)
    for patch, samples_arr in lead.items():
        sf.write(str(output_dir / f'lead_{patch}.wav'), np.clip(samples_arr*scale,-.99,.99), SAMPLE_RATE, subtype='PCM_16')
    for name, samples_arr in [('bass',bass),('arp',arp),('drums',drums)]:
        sf.write(str(output_dir / f'{name}.wav'), np.clip(samples_arr*scale,-.99,.99), SAMPLE_RATE, subtype='PCM_16')
    # Preview file that can be played even without Processing.
    sf.write(str(output_dir / 'preview_full.wav'), np.clip(all_audio*scale,-.99,.99), SAMPLE_RATE, subtype='PCM_16')

    data = {'title': title, 'source': midi_file.name,
            'method': 'External MIDI -> note selection heuristic -> original 8-bit waveform synthesis',
            'isAIPrediction': False,  # MIDI may originate from AI, but this renderer never runs AI.
            'durationMs': round(duration * 1000), 'bpm': round(bpm, 2),
            'chords': progression, 'midiTracks': track_count,
            'rawNotes': raw_count, 'selectedNotes': len(chart), 'notes': chart}
    (output_dir / 'beatmap.json').write_text(json.dumps(data, ensure_ascii=False, indent=2), encoding='utf-8')
    print(f'Created chiptune WAVs and beatmap.json in {output_dir}')
    print(f'MIDI: {midi_file.name} / {len(chart)} melody notes / {duration:.1f}s / BPM={bpm:g}')
    print('Chords:', ', '.join(progression) if progression else 'none (drum-only backing, avoid harmonic clash)')
    print('NOTE: Rendering MIDI to chiptune is NOT AI inference. AI transcription must happen beforehand.')
    return data


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('midi_file', type=Path)
    parser.add_argument('output_dir', type=Path)
    parser.add_argument('--bpm', type=float, default=0.0, help='Set actual song BPM (defaults to MIDI tempo)')
    parser.add_argument('--chords', default='', help='Verified repeating 4-beat chord names, e.g. C,G,Am,F; omit if uncertain')
    parser.add_argument('--title', default='8-BIT POP', help='Processing UI display title')
    parser.add_argument('--track', type=int, default=None, help='Optional 0-based non-drum MIDI track with melody')
    args = parser.parse_args()
    generate(args.midi_file, args.output_dir, args.bpm, args.chords, args.title, args.track)
