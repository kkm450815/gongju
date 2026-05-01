extends Node
## EconomySystem — town prosperity (0..200) + simple per-tick growth.

signal prosperity_changed(value: float)

var prosperity: float = 50.0
const PROSPERITY_MAX := 200.0
var _bonus_per_sec: float = 0.0    # contributed by buildings (shops etc.)

func _process(delta: float) -> void:
	var before := prosperity
	prosperity = clamp(prosperity + _bonus_per_sec * delta - 0.05 * delta, 0.0, PROSPERITY_MAX)
	if absf(prosperity - before) > 0.01:
		emit_signal("prosperity_changed", prosperity)

func add(amount: float) -> void:
	prosperity = clamp(prosperity + amount, 0.0, PROSPERITY_MAX)
	emit_signal("prosperity_changed", prosperity)

func register_building_bonus(per_sec: float) -> void:
	_bonus_per_sec += per_sec

func unregister_building_bonus(per_sec: float) -> void:
	_bonus_per_sec -= per_sec
