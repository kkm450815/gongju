extends StaticBody3D
## Building — static structure with HP. Contributes faith / prosperity per tick.
## Loads its visual from data["model"] if present, else falls back to a colored cube.

class_name Building

signal destroyed(b: Building)

var data: Dictionary = {}
var hp: float = 100.0
var max_hp: float = 100.0

func setup(b_data: Dictionary) -> void:
	data = b_data
	max_hp = float(data.get("hp", 100.0))
	hp = max_hp

	var fp: Array = data.get("footprint", [3, 3])
	var sx := float(fp[0]) if fp.size() >= 2 else 3.0
	var sz := float(fp[1]) if fp.size() >= 2 else 3.0
	var sy := 2.5

	# collision
	var col := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = Vector3(sx, sy, sz)
	col.shape = box_shape
	col.position.y = sy * 0.5
	add_child(col)

	# visual
	var path := String(data.get("model", ""))
	if path != "" and ResourceLoader.exists(path):
		var packed := load(path)
		if packed is PackedScene:
			var inst: Node = packed.instantiate()
			add_child(inst)
		else:
			_build_fallback(sx, sy, sz)
	else:
		_build_fallback(sx, sy, sz)

	# register passive bonuses
	if data.has("faith_per_sec") and has_node("/root/FaithSystem"):
		FaithSystem.register_building_faith(float(data["faith_per_sec"]))
	if data.has("prosperity_per_sec") and has_node("/root/EconomySystem"):
		EconomySystem.register_building_bonus(float(data["prosperity_per_sec"]))

func _build_fallback(sx: float, sy: float, sz: float) -> void:
	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(sx, sy, sz)
	mi.mesh = box
	mi.position.y = sy * 0.5
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(String(data.get("fallback_color", "#06b894")))
	mi.material_override = mat
	add_child(mi)

func take_damage(amount: float) -> void:
	hp -= amount
	if hp <= 0.0:
		# unregister passives
		if data.has("faith_per_sec") and has_node("/root/FaithSystem"):
			FaithSystem.unregister_building_faith(float(data["faith_per_sec"]))
		if data.has("prosperity_per_sec") and has_node("/root/EconomySystem"):
			EconomySystem.unregister_building_bonus(float(data["prosperity_per_sec"]))
		emit_signal("destroyed", self)
		queue_free()
