extends Node
## TimeSystem — game clock, day/night, speed control.

signal day_advanced(day: int)
signal speed_changed(speed: float)
signal pause_changed(paused: bool)

var day: int = 1
var time_in_day: float = 0.0    # 0..1 within a day
var day_length_sec: float = 120.0
var speed: float = 1.0
var paused: bool = false

func _ready() -> void:
	if has_node("/root/DataLoader"):
		await get_tree().process_frame  # let DataLoader populate
		var v: Variant = DataLoader.balance_value("day_length_sec", 120.0)
		day_length_sec = float(v)

func _process(delta: float) -> void:
	if paused:
		return
	time_in_day += (delta * speed) / day_length_sec
	while time_in_day >= 1.0:
		time_in_day -= 1.0
		day += 1
		emit_signal("day_advanced", day)

func set_speed(s: float) -> void:
	speed = s
	Engine.time_scale = 0.0 if paused else s
	emit_signal("speed_changed", s)

func toggle_pause() -> void:
	paused = not paused
	Engine.time_scale = 0.0 if paused else speed
	emit_signal("pause_changed", paused)

func sun_angle() -> float:
	# 0 at midnight, PI at noon
	return time_in_day * TAU
