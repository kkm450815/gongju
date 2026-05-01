extends CharacterBody3D
## NPC — wanders, flees on fear, dies when HP <= 0.
## Loads its visual from data["model"] if present, else falls back to a colored cube.

class_name NPC

signal died(npc: NPC)

const TILE := 1.0
var data: Dictionary = {}
var hp: float = 100.0
var max_hp: float = 100.0
var speed: float = 2.0
var _target: Vector3
var _retarget_in: float = 0.0
var _is_fleeing: bool = false

func setup(npc_data: Dictionary, world_size: float) -> void:
	data = npc_data
	max_hp = float(data.get("hp", 100.0))
	hp = max_hp
	speed = float(data.get("speed", 2.0))
	_pick_random_target(world_size)
	_build_visual()

func _build_visual() -> void:
	# collision body (capsule)
	var col := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.3
	capsule.height = 1.6
	col.shape = capsule
	col.position.y = 0.8
	add_child(col)

	# visual
	var path := String(data.get("model", ""))
	if path != "" and ResourceLoader.exists(path):
		var packed := load(path)
		if packed is PackedScene:
			var inst: Node = packed.instantiate()
			add_child(inst)
			return
	# fallback box
	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.6, 1.6, 0.6)
	mi.mesh = box
	mi.position.y = 0.8
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(String(data.get("fallback_color", "#eef1f8")))
	mi.material_override = mat
	add_child(mi)

func _physics_process(delta: float) -> void:
	if hp <= 0.0:
		return
	_retarget_in -= delta
	var fear: float = 0.0
	if has_node("/root/FaithSystem"):
		fear = FaithSystem.fear
	_is_fleeing = fear > float(data.get("fear_threshold", 80))
	if _retarget_in <= 0.0:
		_pick_random_target(60.0)
	var dir := (_target - global_position)
	dir.y = 0.0
	if dir.length() < 0.5:
		_retarget_in = 0.0
		return
	var v := dir.normalized() * speed * (1.6 if _is_fleeing else 1.0)
	velocity = Vector3(v.x, velocity.y, v.z)
	move_and_slide()

func _pick_random_target(size: float) -> void:
	var half := size * 0.5
	_target = Vector3(randf_range(-half, half), 0.0, randf_range(-half, half))
	_retarget_in = randf_range(2.0, 5.0)

func take_damage(amount: float) -> void:
	hp -= amount
	if hp <= 0.0:
		emit_signal("died", self)
		queue_free()

func heal(amount: float) -> void:
	hp = min(hp + amount, max_hp)
