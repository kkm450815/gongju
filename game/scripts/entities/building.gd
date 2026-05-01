extends StaticBody3D
## Building — static structure with HP. Contributes faith / prosperity per tick.
## Uses BuildingBuilder for procedural visuals when no GLB model is available.

class_name Building

const BuildingBuilderClass := preload("res://scripts/procedural/building_builder.gd")

signal destroyed(b: Building)

var data: Dictionary = {}
var hp: float = 100.0
var max_hp: float = 100.0
var _visual_root: Node3D
var _building_height: float = 2.6

func setup(b_data: Dictionary) -> void:
	data = b_data
	max_hp = float(data.get("hp", 100.0))
	hp = max_hp

	var fp: Array = data.get("footprint", [3, 3])
	var sx: float = float(fp[0]) if fp.size() >= 2 else 3.0
	var sz: float = float(fp[1]) if fp.size() >= 2 else 3.0

	# decide rough height for collision (matches builder)
	var tags: Array = data.get("tags", [])
	if tags.has("religious") or tags.has("faith_source"):
		_building_height = 4.0
	elif tags.has("economy"):
		_building_height = 3.0
	else:
		_building_height = 2.6

	# physics collision (single box covering body)
	var col := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = Vector3(sx, _building_height, sz)
	col.shape = box_shape
	col.position.y = _building_height * 0.5
	add_child(col)

	# visual
	var path := String(data.get("model", ""))
	if path != "" and ResourceLoader.exists(path):
		var packed := load(path)
		if packed is PackedScene:
			_visual_root = (packed as PackedScene).instantiate() as Node3D
			if _visual_root != null:
				add_child(_visual_root)
				_register_passives()
				return
	# fallback: procedural composite building
	var body_color := Color(String(data.get("fallback_color", "#06b894")))
	_visual_root = BuildingBuilderClass.build(fp, body_color, tags)
	add_child(_visual_root)

	# defer until we're in the tree so autoload calls behave consistently
	call_deferred("_register_passives")

func _register_passives() -> void:
	# Autoloads are global singletons — accessible by name from any script.
	if data.has("faith_per_sec"):
		FaithSystem.register_building_faith(float(data["faith_per_sec"]))
	if data.has("prosperity_per_sec"):
		EconomySystem.register_building_bonus(float(data["prosperity_per_sec"]))

func take_damage(amount: float) -> void:
	hp -= amount
	# tilt and shake
	if _visual_root != null and hp > 0.0:
		var tw := create_tween()
		tw.tween_property(_visual_root, "rotation:z", deg_to_rad(4), 0.06)
		tw.tween_property(_visual_root, "rotation:z", deg_to_rad(-4), 0.10)
		tw.tween_property(_visual_root, "rotation:z", 0.0, 0.06)
	if hp <= 0.0:
		if data.has("faith_per_sec"):
			FaithSystem.unregister_building_faith(float(data["faith_per_sec"]))
		if data.has("prosperity_per_sec"):
			EconomySystem.unregister_building_bonus(float(data["prosperity_per_sec"]))
		emit_signal("destroyed", self)
		queue_free()
