extends SceneTree

# FB5 (partial): simple SFX pass. No audio-generation API is configured in
# this project (only GEMINI_API_KEY, used for images) -- rather than skip
# this or fake it, these are synthesized directly (sine/square waves with
# amplitude envelopes to avoid clicks), zero external tooling needed. Real
# music/ambient tracks are a different, much higher bar (need to not sound
# annoying on loop) and are explicitly out of scope for this pass.
#
# Run: godot --headless --script tools/generate-sfx.gd

const SAMPLE_RATE := 22050
const OUT_DIR := "res://Assets/generated/audio/"

func _initialize():
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	_save("jump", _synth_jump())
	_save("bean_collect", _synth_collect())
	_save("hit", _synth_hit())
	_save("life_pickup", _synth_powerup())
	_save("level_complete", _synth_fanfare())
	print("SFX generation complete.")
	quit()

func _save(name: String, stream: AudioStreamWAV) -> void:
	var path := OUT_DIR + name + ".tres"
	var err := ResourceSaver.save(stream, path)
	print(name, " -> ", path, " err=", err)

func _make_wav(samples: PackedFloat32Array) -> AudioStreamWAV:
	var bytes := PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i in samples.size():
		var v := clampf(samples[i], -1.0, 1.0)
		var s := int(v * 32767.0)
		bytes.encode_s16(i * 2, s)
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = SAMPLE_RATE
	stream.stereo = false
	stream.data = bytes
	return stream

# Linear envelope: quick attack, longer release, avoids waveform-edge clicks.
func _envelope(t: float, duration: float, attack: float, release: float) -> float:
	if t < attack:
		return t / attack
	if t > duration - release:
		return max(0.0, (duration - t) / release)
	return 1.0

func _synth_jump() -> AudioStreamWAV:
	var duration := 0.18
	var n := int(SAMPLE_RATE * duration)
	var samples := PackedFloat32Array()
	samples.resize(n)
	for i in n:
		var t := float(i) / SAMPLE_RATE
		var freq := lerpf(420.0, 880.0, t / duration)  # rising pitch sweep
		var env := _envelope(t, duration, 0.01, 0.1)
		samples[i] = sin(TAU * freq * t) * env * 0.5
	return _make_wav(samples)

func _synth_collect() -> AudioStreamWAV:
	var duration := 0.22
	var n := int(SAMPLE_RATE * duration)
	var samples := PackedFloat32Array()
	samples.resize(n)
	for i in n:
		var t := float(i) / SAMPLE_RATE
		# a bright two-note chime (major third up)
		var freq := 880.0 if t < duration * 0.45 else 1108.73
		var env := _envelope(t, duration, 0.005, 0.12)
		samples[i] = sin(TAU * freq * t) * env * 0.45
	return _make_wav(samples)

func _synth_hit() -> AudioStreamWAV:
	var duration := 0.25
	var n := int(SAMPLE_RATE * duration)
	var samples := PackedFloat32Array()
	samples.resize(n)
	for i in n:
		var t := float(i) / SAMPLE_RATE
		var freq := lerpf(220.0, 90.0, t / duration)  # falling pitch, low thud
		var env := _envelope(t, duration, 0.005, 0.2)
		# square-ish wave (sign of sine) for a blunter, less musical "hit" tone
		samples[i] = signf(sin(TAU * freq * t)) * env * 0.35
	return _make_wav(samples)

func _synth_powerup() -> AudioStreamWAV:
	var duration := 0.5
	var n := int(SAMPLE_RATE * duration)
	var samples := PackedFloat32Array()
	samples.resize(n)
	var notes := [523.25, 659.25, 783.99, 1046.50]  # C E G C (major arpeggio)
	var note_dur := duration / notes.size()
	for i in n:
		var t := float(i) / SAMPLE_RATE
		var note_idx := clampi(int(t / note_dur), 0, notes.size() - 1)
		var local_t := t - note_idx * note_dur
		var env := _envelope(local_t, note_dur, 0.005, note_dur * 0.5)
		samples[i] = sin(TAU * notes[note_idx] * t) * env * 0.4
	return _make_wav(samples)

func _synth_fanfare() -> AudioStreamWAV:
	var duration := 1.1
	var n := int(SAMPLE_RATE * duration)
	var samples := PackedFloat32Array()
	samples.resize(n)
	var notes := [523.25, 523.25, 523.25, 659.25, 783.99, 1046.50]
	var durs := [0.15, 0.15, 0.15, 0.2, 0.2, 0.45]
	for i in n:
		var t := float(i) / SAMPLE_RATE
		var acc := 0.0
		var note_idx := 0
		for d in durs:
			if t < acc + d:
				break
			acc += d
			note_idx += 1
		note_idx = clampi(note_idx, 0, notes.size() - 1)
		var local_t := t - acc
		var this_dur: float = durs[note_idx]
		var env := _envelope(local_t, this_dur, 0.005, this_dur * 0.4)
		samples[i] = sin(TAU * notes[note_idx] * t) * env * 0.45
	return _make_wav(samples)
