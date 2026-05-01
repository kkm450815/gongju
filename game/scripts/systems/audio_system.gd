extends Node
## AudioSystem — minimal SFX bus. Loads files lazily, silently no-ops if missing.
## Hooks into DisasterSystem signals so casting a power auto-plays the right SFX.

const SFX_ROOT := "res://assets/kenney/sfx/"

# Map symbolic names to candidate filenames in the sfx folder.
# The first one that exists wins. Add more candidates as you drop in packs.
const SFX_MAP := {
	"thunder":           ["impactPlate_heavy_000.ogg", "impactBell_heavy_000.ogg", "thunder.ogg"],
	"earthquake":        ["impactPlate_heavy_004.ogg", "impactBell_heavy_002.ogg"],
	"flood":             ["impactSoft_heavy_002.ogg", "impactSoft_medium_001.ogg"],
	"plague":            ["impactSoft_heavy_004.ogg"],
	"harvest":           ["select_002.ogg", "confirmation_001.ogg"],
	"heal":              ["bong_001.ogg", "confirmation_002.ogg"],
	"peace_fog":         ["glass_005.ogg", "minimalist1.ogg"],
	"ui_click":          ["click_001.ogg", "click_004.ogg"],
	"building_destroy":  ["impactPlate_heavy_001.ogg"],
	"npc_die":           ["impactSoft_medium_002.ogg"],
}

var _max_voices: int = 12
var _voices: Array[AudioStreamPlayer] = []
var _next_voice: int = 0
var _cache: Dictionary = {}     # symbolic name -> AudioStream or null

func _ready() -> void:
	for i in _max_voices:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_voices.append(p)
	# bind to gameplay signals
	if has_node("/root/DisasterSystem"):
		DisasterSystem.power_cast.connect(_on_power_cast)

func play(symbol: String, volume_db: float = 0.0) -> void:
	var stream := _resolve(symbol)
	if stream == null:
		return
	var p: AudioStreamPlayer = _voices[_next_voice]
	_next_voice = (_next_voice + 1) % _max_voices
	p.stream = stream
	p.volume_db = volume_db
	p.play()

func _resolve(symbol: String) -> AudioStream:
	if _cache.has(symbol):
		return _cache[symbol]
	var candidates: Array = SFX_MAP.get(symbol, [])
	for fname in candidates:
		var full: String = SFX_ROOT + String(fname)
		if ResourceLoader.exists(full):
			var s := load(full)
			if s is AudioStream:
				_cache[symbol] = s
				return s
	_cache[symbol] = null
	return null

func _on_power_cast(power_id: String, _pos: Vector3) -> void:
	# map power id to SFX symbol; fall back to power_id directly
	play(power_id)
