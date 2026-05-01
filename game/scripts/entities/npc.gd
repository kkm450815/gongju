extends CharacterBody3D
## NPC — state-machine driven villager.
## States: WANDER, GO_HOME, AT_HOME, GO_WORK, AT_WORK, GO_PRAY, PRAYING, FLEE
## Decisions are based on time-of-day (TimeSystem), town fear (FaithSystem),
## the NPC's behavior tags, and the buildings registered in TownRegistry.

class_name NPC

signal died(npc: NPC)

enum State { WANDER, GO_HOME, AT_HOME, GO_WORK, AT_WORK, GO_PRAY, PRAYING, FLEE }

const ARRIVE_DIST := 1.2
const REPLAN_INTERVAL_SEC := 4.0

var data: Dictionary = {}
var hp: float = 100.0
var max_hp: float = 100.0
var speed: float = 2.0
var world_size: float = 60.0

var state: int = State.WANDER
var target_pos: Vector3 = Vector3.ZERO
var home_b = null            # Building or null
var work_b = null
var _replan_in: float = 0.0
var _state_dwell: float = 0.0
var _last_known_fear: float = 0.0

func setup(npc_data: Dictionary, world_size_m: float) -> void:
	data = npc_data
	max_hp = float(data.get("hp", 100.0))
	hp = max_hp
	speed = float(data.get("speed", 2.0))
	world_size = world_size_m
	_pick_random_target()
	_build_visual()

func assign_home(b) -> void:
	home_b = b

func assign_work(b) -> void:
	work_b = b

func _build_visual() -> void:
	var col := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.3
	capsule.height = 1.6
	col.shape = capsule
	col.position.y = 0.8
	add_child(col)

	var path := String(data.get("model", ""))
	if path != "" and ResourceLoader.exists(path):
		var packed := load(path)
		if packed is PackedScene:
			add_child((packed as PackedScene).instantiate())
			return
	# fallback colored capsule-ish box
	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.6, 1.6, 0.6)
	mi.mesh = box
	mi.position.y = 0.8
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(String(data.get("fallback_color", "#eef1f8")))
	mi.material_override = mat
	add_child(mi)

# ---------------- AI ----------------
func _physics_process(delta: float) -> void:
	if hp <= 0.0:
		return
	_replan_in -= delta
	_state_dwell += delta
	_last_known_fear = FaithSystem.fear if has_node("/root/FaithSystem") else 0.0

	if _replan_in <= 0.0:
		_replan_in = REPLAN_INTERVAL_SEC + randf_range(-0.5, 1.0)
		_decide_next_state()

	_run_state(delta)

func _decide_next_state() -> void:
	var behaviors: Array = data.get("behaviors", ["wander"])
	# 1) panic flee
	var fear_thresh := float(data.get("fear_threshold", 80))
	if _last_known_fear > fear_thresh and "flee" in behaviors:
		_set_state(State.FLEE, _flee_target())
		return
	# 2) time-of-day routine
	var t: float = TimeSystem.time_in_day if has_node("/root/TimeSystem") else 0.5
	# night: 0..0.20 or 0.80..1.0  -> sleep at home
	if (t < 0.20 or t > 0.80):
		var h = home_b if is_instance_valid(home_b) else _find_home()
		if h:
			home_b = h
			_set_state(State.GO_HOME, h.global_position)
			return
	# pray window: 0.20..0.30 -> chance for priests, lower for others
	var pray_chance := 0.10
	if data.get("id", "") == "priest":
		pray_chance = 0.85
	if t > 0.20 and t < 0.30 and "pray" in behaviors and randf() < pray_chance:
		var church = TownRegistry.random_in(TownRegistry.religious) if has_node("/root/TownRegistry") else null
		if church:
			_set_state(State.GO_PRAY, church.global_position)
			return
	# work window: 0.30..0.75 if behavior allows
	if t > 0.30 and t < 0.75 and ("work" in behaviors or "wander" in behaviors):
		var w = work_b if is_instance_valid(work_b) else _find_work()
		if w:
			work_b = w
			_set_state(State.GO_WORK, w.global_position)
			return
	# default: wander
	_set_state(State.WANDER, _random_pos())

func _set_state(new_state: int, new_target: Vector3) -> void:
	state = new_state
	target_pos = new_target
	_state_dwell = 0.0

func _run_state(delta: float) -> void:
	match state:
		State.WANDER:
			_walk_toward(target_pos, 1.0)
			if _arrived(target_pos):
				_set_state(State.WANDER, _random_pos())
		State.GO_HOME:
			_walk_toward(target_pos, 1.0)
			if _arrived(target_pos):
				_set_state(State.AT_HOME, target_pos)
		State.AT_HOME:
			# stay put for up to a few seconds, replan_check will move us
			velocity = Vector3.ZERO
			move_and_slide()
		State.GO_WORK:
			_walk_toward(target_pos, 1.0)
			if _arrived(target_pos):
				_set_state(State.AT_WORK, target_pos)
		State.AT_WORK:
			velocity = Vector3.ZERO
			move_and_slide()
			# small wander while working
			if _state_dwell > 5.0:
				_set_state(State.WANDER, _around(target_pos, 4.0))
		State.GO_PRAY:
			_walk_toward(target_pos, 1.0)
			if _arrived(target_pos):
				_set_state(State.PRAYING, target_pos)
		State.PRAYING:
			velocity = Vector3.ZERO
			move_and_slide()
			if has_node("/root/FaithSystem") and _state_dwell > 1.0:
				FaithSystem.add(0.5 * delta * float(data.get("faith_contribution", 1.0)))
		State.FLEE:
			_walk_toward(target_pos, 1.7)
			if _arrived(target_pos):
				_set_state(State.FLEE, _flee_target())

# ---------------- Helpers ----------------
func _walk_toward(p: Vector3, speed_mul: float) -> void:
	var dir := p - global_position
	dir.y = 0.0
	if dir.length() < 0.05:
		return
	var v := dir.normalized() * speed * speed_mul
	velocity = Vector3(v.x, velocity.y, v.z)
	# face direction
	var look := global_position + Vector3(v.x, 0, v.z)
	if (look - global_position).length() > 0.05:
		look_at(look, Vector3.UP)
	move_and_slide()

func _arrived(p: Vector3) -> bool:
	var d := Vector3(p.x - global_position.x, 0.0, p.z - global_position.z).length()
	return d < ARRIVE_DIST

func _random_pos() -> Vector3:
	var half := world_size * 0.45
	return Vector3(randf_range(-half, half), 0.0, randf_range(-half, half))

func _around(center: Vector3, r: float) -> Vector3:
	var a := randf() * TAU
	return center + Vector3(cos(a) * r, 0.0, sin(a) * r)

func _flee_target() -> Vector3:
	var center := TownRegistry.center if has_node("/root/TownRegistry") else Vector3.ZERO
	var dir := global_position - center
	dir.y = 0.0
	if dir.length() < 0.5:
		dir = Vector3(randf_range(-1, 1), 0, randf_range(-1, 1))
	return global_position + dir.normalized() * (world_size * 0.4)

func _find_home():
	if not has_node("/root/TownRegistry"):
		return null
	return TownRegistry.nearest(TownRegistry.residential, global_position)

func _find_work():
	if not has_node("/root/TownRegistry"):
		return null
	# prefer nearest economy building, fallback to nearest residential (errands)
	var w = TownRegistry.nearest(TownRegistry.economy, global_position)
	if w == null:
		w = TownRegistry.nearest(TownRegistry.residential, global_position)
	return w

func _pick_random_target() -> void:
	target_pos = _random_pos()

# ---------------- Damage / Heal ----------------
func take_damage(amount: float) -> void:
	hp -= amount
	if hp <= 0.0:
		emit_signal("died", self)
		queue_free()

func heal(amount: float) -> void:
	hp = min(hp + amount, max_hp)
