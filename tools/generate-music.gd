extends SceneTree

# FB5 (remainder): ambient background loop. Same reasoning as
# tools/generate-sfx.gd -- no audio-generation API is configured in this
# project (only GEMINI_API_KEY, for images) -- synthesized directly instead
# of skipped. Music/ambient is a higher bar than SFX (must not grate on a
# tight loop), so this is deliberately conservative: a soft sustained pad
# (no melody, no percussion, nothing that draws attention to itself) at low
# volume, meant to sit under the game rather than be listened to.
#
# Seamless-loop technique: every oscillator's frequency is snapped so it
# completes a whole number of cycles across the loop duration (freq =
# round(target_freq * duration) / duration). A whole number of cycles means
# the waveform's value AND slope at t=duration exactly match t=0, so the
# loop point is genuinely click-free -- not just faded/crossfaded to hide a
# seam. The amplitude "breathing" LFO uses the same trick with exactly 1
# cycle over the full duration.
#
# Run: godot --headless --script tools/generate-music.gd

const SAMPLE_RATE := 22050
const OUT_DIR := "res://Assets/generated/audio/"
const DURATION := 16.0

func _initialize():
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	_save("ambient_loop", _synth_ambient())
	print("Ambient music generation complete.")
	quit()

func _save(name: String, stream: AudioStreamWAV) -> void:
	var path := OUT_DIR + name + ".tres"
	var err := ResourceSaver.save(stream, path)
	print(name, " -> ", path, " err=", err)

func _loop_safe_freq(target_hz: float) -> float:
	var cycles := roundf(target_hz * DURATION)
	return cycles / DURATION

func _make_wav_looping(samples: PackedFloat32Array) -> AudioStreamWAV:
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
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = samples.size()
	return stream

# A quiet, slow-breathing add9 pad (C-E-G-D) -- consonant, static harmony,
# nothing rhythmic or melodic to get repetitive/annoying on loop. Each note
# is its own loop-safe sine; a single shared amplitude LFO (also loop-safe,
# exactly 1 cycle) gives it a gentle "breathing" swell instead of a flat,
# static drone.
func _synth_ambient() -> AudioStreamWAV:
	var n := int(SAMPLE_RATE * DURATION)
	var samples := PackedFloat32Array()
	samples.resize(n)
	var freqs := [
		_loop_safe_freq(130.81),  # C3
		_loop_safe_freq(164.81),  # E3
		_loop_safe_freq(196.00),  # G3
		_loop_safe_freq(293.66),  # D4 (add9)
	]
	var note_gains := [0.30, 0.22, 0.20, 0.14]  # root loudest, upper notes softer
	var lfo_freq := _loop_safe_freq(1.0 / DURATION)  # exactly 1 cycle over the loop
	for i in n:
		var t := float(i) / SAMPLE_RATE
		var chord := 0.0
		for idx in freqs.size():
			chord += sin(TAU * freqs[idx] * t) * note_gains[idx]
		var breathe := 0.75 + 0.25 * (0.5 + 0.5 * sin(TAU * lfo_freq * t))
		samples[i] = chord * breathe * 0.5  # overall headroom, kept quiet by design
	return _make_wav_looping(samples)
