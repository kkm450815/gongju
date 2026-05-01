extends RefCounted
## SFXGenerator — synthesizes tiny PCM audio streams at runtime so the game
## has sound even without downloaded SFX packs. Returns AudioStreamWAV
## instances usable directly by AudioStreamPlayer.

class_name SFXGenerator

const SAMPLE_RATE := 22050

## Build a noise burst (used for thunder, earthquake low-freq rumble).
static func build_noise(duration: float, low_freq_bias: float = 0.0, volume: float = 0.6) -> AudioStreamWAV:
	var n := int(SAMPLE_RATE * duration)
	var pcm := PackedByteArray()
	pcm.resize(n * 2)
	var prev := 0.0
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	for i in n:
		var t: float = float(i) / float(n)
		# attack/decay envelope
		var env := pow(1.0 - t, 1.5)
		var raw := rng.randf_range(-1.0, 1.0)
		# low-pass: lerp toward previous sample (simulates rumble)
		if low_freq_bias > 0.0:
			raw = lerp(prev, raw, 1.0 - low_freq_bias)
			prev = raw
		var s := raw * env * volume
		var v := int(clamp(s, -1.0, 1.0) * 32767.0)
		pcm[i * 2]     = v & 0xff
		pcm[i * 2 + 1] = (v >> 8) & 0xff
	return _make_stream(pcm)

## Build a tone with envelope (used for blessings, UI).
static func build_tone(freq: float, duration: float, volume: float = 0.4, decay: float = 4.0) -> AudioStreamWAV:
	var n := int(SAMPLE_RATE * duration)
	var pcm := PackedByteArray()
	pcm.resize(n * 2)
	for i in n:
		var t: float = float(i) / float(SAMPLE_RATE)
		var env := pow(1.0 - float(i) / float(n), decay)
		var s := sin(TAU * freq * t) * env * volume
		var v := int(clamp(s, -1.0, 1.0) * 32767.0)
		pcm[i * 2]     = v & 0xff
		pcm[i * 2 + 1] = (v >> 8) & 0xff
	return _make_stream(pcm)

## Build an arpeggio (3-note ascending or descending).
static func build_arpeggio(freqs: Array, duration: float, volume: float = 0.4) -> AudioStreamWAV:
	var n := int(SAMPLE_RATE * duration)
	var pcm := PackedByteArray()
	pcm.resize(n * 2)
	var per_note := float(n) / float(freqs.size())
	for i in n:
		var note_idx: int = clamp(int(i / per_note), 0, freqs.size() - 1)
		var freq: float = freqs[note_idx]
		var local_t := float(i - int(note_idx * per_note)) / per_note
		var t: float = float(i) / float(SAMPLE_RATE)
		var env := pow(1.0 - local_t, 2.0)
		var s := sin(TAU * freq * t) * env * volume
		var v := int(clamp(s, -1.0, 1.0) * 32767.0)
		pcm[i * 2]     = v & 0xff
		pcm[i * 2 + 1] = (v >> 8) & 0xff
	return _make_stream(pcm)

## Build a bell-like tone using two summed sines with detune.
static func build_bell(freq: float, duration: float, volume: float = 0.4) -> AudioStreamWAV:
	var n := int(SAMPLE_RATE * duration)
	var pcm := PackedByteArray()
	pcm.resize(n * 2)
	for i in n:
		var t: float = float(i) / float(SAMPLE_RATE)
		var env := pow(1.0 - float(i) / float(n), 1.2)
		var s := (sin(TAU * freq * t) + 0.6 * sin(TAU * freq * 2.01 * t)) * 0.5 * env * volume
		var v := int(clamp(s, -1.0, 1.0) * 32767.0)
		pcm[i * 2]     = v & 0xff
		pcm[i * 2 + 1] = (v >> 8) & 0xff
	return _make_stream(pcm)

static func _make_stream(pcm: PackedByteArray) -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = SAMPLE_RATE
	stream.stereo = false
	stream.data = pcm
	return stream

## Build the full SFX library used by the game.
static func library() -> Dictionary:
	return {
		"thunder":          build_noise(0.55, 0.0, 0.7),
		"earthquake":       build_noise(1.6, 0.92, 0.5),
		"flood":            build_noise(1.0, 0.85, 0.4),
		"plague":           build_noise(0.8, 0.8, 0.35),
		"harvest":          build_arpeggio([523, 659, 784, 1047], 0.6),
		"heal":             build_bell(880, 0.7, 0.45),
		"peace_fog":        build_arpeggio([392, 494, 587], 0.9, 0.35),
		"ui_click":         build_tone(900, 0.05, 0.3, 6.0),
		"building_destroy": build_noise(0.45, 0.4, 0.55),
		"npc_die":          build_tone(180, 0.35, 0.4, 3.0),
	}
