extends Node
## AudioSystem — SFX bus with two layers:
## 1) Procedurally-generated tones (always available, generated at startup)
## 2) Override files in res://assets/kenney/sfx/ if present (better quality)

const SFX_ROOT := "res://assets/kenney/sfx/"
const SFXGenClass := preload("res://scripts/systems/sfx_generator.gd")

# When a Kenney pack is dropped in, its filename can override the procedural fallback.
const SFX_OVERRIDE := {
	"thunder":           ["impactPlate_heavy_000.ogg", "thunder.ogg"],
	"earthquake":        ["impactPlate_heavy_004.ogg"],
	"flood":             ["impactSoft_heavy_002.ogg"],
	"plague":            ["impactSoft_heavy_004.ogg"],
	"harvest":           ["confirmation_001.ogg"],
	"heal":              ["bong_001.ogg"],
	"peace_fog":         ["glass_005.ogg"],
	"ui_click":          ["click_001.ogg"],
	"building_destroy":  ["impactPlate_heavy_001.ogg"],
	"npc_die":           ["impactSoft_medium_002.ogg"],
}

var _max_voices: int = 16
var _voices: Array[AudioStreamPlayer] = []
var _next_voice: int = 0
var _cache: Dictionary = {}     # symbol -> AudioStream
var _muted: bool = false

func _ready() -> void:
	for i in _max_voices:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_voices.append(p)
	_build_library()
	if has_node("/root/DisasterSystem"):
		DisasterSystem.power_cast.connect(_on_power_cast)
	print("[AudioSystem] ready (cached %d sfx)" % _cache.size())

func _build_library() -> void:
	# 1) seed with procedural tones
	var procedural: Dictionary = SFXGenClass.library()
	for k in procedural.keys():
		_cache[k] = procedural[k]
	# 2) override with files when available
	for symbol in SFX_OVERRIDE.keys():
		for fname in SFX_OVERRIDE[symbol]:
			var full: String = SFX_ROOT + String(fname)
			if ResourceLoader.exists(full):
				var s := load(full)
				if s is AudioStream:
					_cache[symbol] = s
					break

func play(symbol: String, volume_db: float = 0.0) -> void:
	if _muted:
		return
	var stream: AudioStream = _cache.get(symbol)
	if stream == null:
		return
	var p: AudioStreamPlayer = _voices[_next_voice]
	_next_voice = (_next_voice + 1) % _max_voices
	p.stream = stream
	p.volume_db = volume_db
	p.play()

func set_muted(m: bool) -> void:
	_muted = m

func _on_power_cast(power_id: String, _pos: Vector3) -> void:
	play(power_id)
