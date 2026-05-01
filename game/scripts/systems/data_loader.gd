extends Node
## DataLoader — loads all JSON content under res://data on startup.
## Other systems read from these dictionaries via DataLoader.disasters etc.

signal data_ready

var disasters: Array = []
var blessings: Array = []
var buildings: Array = []
var npcs: Array = []
var events: Array = []
var balance: Dictionary = {}

var _by_id: Dictionary = {}   # id -> entry, across all categories

func _ready() -> void:
	disasters = _load_array("res://data/disasters.json")
	blessings = _load_array("res://data/blessings.json")
	buildings = _load_array("res://data/buildings.json")
	npcs      = _load_array("res://data/npcs.json")
	events    = _load_array("res://data/events.json")
	balance   = _load_object("res://data/balance.json")
	for arr in [disasters, blessings, buildings, npcs, events]:
		for entry in arr:
			if entry.has("id"):
				_by_id[entry["id"]] = entry
	print("[DataLoader] loaded — disasters=%d blessings=%d buildings=%d npcs=%d events=%d"
		% [disasters.size(), blessings.size(), buildings.size(), npcs.size(), events.size()])
	emit_signal("data_ready")

func get_by_id(id: String) -> Dictionary:
	return _by_id.get(id, {})

func balance_value(key: String, default_value = null) -> Variant:
	return balance.get(key, default_value)

# ---- internals ----
func _load_array(path: String) -> Array:
	var text := _read_text(path)
	if text == "":
		return []
	var parsed = JSON.parse_string(text)
	if typeof(parsed) != TYPE_ARRAY:
		push_error("[DataLoader] expected array in %s" % path)
		return []
	return parsed

func _load_object(path: String) -> Dictionary:
	var text := _read_text(path)
	if text == "":
		return {}
	var parsed = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("[DataLoader] expected object in %s" % path)
		return {}
	return parsed

func _read_text(path: String) -> String:
	if not FileAccess.file_exists(path):
		push_error("[DataLoader] missing %s" % path)
		return ""
	var f := FileAccess.open(path, FileAccess.READ)
	var t := f.get_as_text()
	f.close()
	return t
