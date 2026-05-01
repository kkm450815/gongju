extends Node
## SaveSystem — periodic JSON snapshot to user://save.json.
## Stores: current day, faith/fear, prosperity, all NPC positions/HP/data id,
## all building positions/HP/data id. Restores on game start if a save exists.
##
## Usage from main.gd:
##   SaveSystem.bind(self, _npcs_array, _buildings_array)
## SaveSystem then auto-saves every N seconds and after manual saves via F2.

const SAVE_PATH := "user://save.json"
const SAVE_VERSION := 1

signal saved()
signal loaded(state: Dictionary)

var _autosave_interval: float = 60.0
var _timer: float = 0.0
var _main_ref: Node = null
var _npcs_ref: Array = []
var _buildings_ref: Array = []

func _ready() -> void:
	if has_node("/root/DataLoader"):
		await get_tree().process_frame
		_autosave_interval = float(DataLoader.balance_value("save_autosave_interval_sec", 60.0))

func bind(main_node: Node, npcs: Array, buildings: Array) -> void:
	_main_ref = main_node
	_npcs_ref = npcs
	_buildings_ref = buildings

func _process(delta: float) -> void:
	if _main_ref == null:
		return
	_timer += delta
	if _timer >= _autosave_interval:
		_timer = 0.0
		save_now()

func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)

func save_now() -> void:
	if _main_ref == null:
		return
	var snap := _snapshot()
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		push_warning("[SaveSystem] cannot write %s" % SAVE_PATH)
		return
	f.store_string(JSON.stringify(snap))
	f.close()
	emit_signal("saved")
	if has_node("/root/Telemetry"):
		Telemetry.track("save", {"day": snap.get("day", 0)})
	print("[SaveSystem] saved (day=%d, npcs=%d, buildings=%d)" % [
		int(snap.get("day", 0)), snap.get("npcs", []).size(), snap.get("buildings", []).size()
	])

func load_state() -> Dictionary:
	if not has_save():
		return {}
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return {}
	var txt := f.get_as_text()
	f.close()
	var parsed = JSON.parse_string(txt)
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	emit_signal("loaded", parsed)
	return parsed

func clear_save() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH)) if false else _remove_file(SAVE_PATH)

func _remove_file(path: String) -> void:
	var d := DirAccess.open("user://")
	if d:
		d.remove(path.replace("user://", ""))

func _snapshot() -> Dictionary:
	var npcs_out: Array = []
	for n in _npcs_ref:
		if not is_instance_valid(n):
			continue
		npcs_out.append({
			"id": String(n.data.get("id", "")),
			"x": n.global_position.x,
			"z": n.global_position.z,
			"hp": n.hp,
			"state": n.state,
		})
	var bs_out: Array = []
	for b in _buildings_ref:
		if not is_instance_valid(b):
			continue
		bs_out.append({
			"id": String(b.data.get("id", "")),
			"x": b.global_position.x,
			"z": b.global_position.z,
			"hp": b.hp,
		})
	return {
		"version": SAVE_VERSION,
		"day": TimeSystem.day if has_node("/root/TimeSystem") else 1,
		"time_in_day": TimeSystem.time_in_day if has_node("/root/TimeSystem") else 0.0,
		"faith": FaithSystem.faith if has_node("/root/FaithSystem") else 0.0,
		"max_faith": FaithSystem.max_faith if has_node("/root/FaithSystem") else 100.0,
		"fear": FaithSystem.fear if has_node("/root/FaithSystem") else 0.0,
		"prosperity": EconomySystem.prosperity if has_node("/root/EconomySystem") else 0.0,
		"lang": I18N.lang if has_node("/root/I18N") else "ko",
		"npcs": npcs_out,
		"buildings": bs_out,
	}
