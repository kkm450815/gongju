extends Node
## FaithSystem — the resource that powers the player's actions.

signal faith_changed(value: float, max_value: float)
signal level_changed(level: int)
signal fear_changed(value: float)

var faith: float = 30.0
var max_faith: float = 100.0
var level: int = 1
var fear: float = 0.0           # 0..100 town-wide
var _regen_per_sec: float = 0.8
var _building_faith_per_sec: float = 0.0

func _ready() -> void:
	if has_node("/root/DataLoader"):
		await get_tree().process_frame
		_regen_per_sec = float(DataLoader.balance_value("faith_regen_per_sec", 0.8))
		max_faith = float(DataLoader.balance_value("max_faith_base", 100.0))

func _process(delta: float) -> void:
	var fear_decay := float(DataLoader.balance_value("fear_decay_per_sec", 0.1)) if has_node("/root/DataLoader") else 0.1
	var prev_faith := faith
	faith = clamp(faith + (_regen_per_sec + _building_faith_per_sec) * delta, 0.0, max_faith)
	if absf(faith - prev_faith) > 0.01:
		emit_signal("faith_changed", faith, max_faith)
	var prev_fear := fear
	fear = clamp(fear - fear_decay * delta, 0.0, 100.0)
	if absf(fear - prev_fear) > 0.01:
		emit_signal("fear_changed", fear)

func can_afford(cost: float) -> bool:
	return faith >= cost

func spend(cost: float) -> bool:
	if not can_afford(cost):
		return false
	faith -= cost
	emit_signal("faith_changed", faith, max_faith)
	return true

func add(amount: float) -> void:
	faith = clamp(faith + amount, 0.0, max_faith)
	emit_signal("faith_changed", faith, max_faith)

func add_fear(amount: float) -> void:
	fear = clamp(fear + amount, 0.0, 100.0)
	emit_signal("fear_changed", fear)

func register_building_faith(per_sec: float) -> void:
	_building_faith_per_sec += per_sec

func unregister_building_faith(per_sec: float) -> void:
	_building_faith_per_sec -= per_sec
