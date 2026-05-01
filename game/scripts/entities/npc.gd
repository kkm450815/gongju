extends CharacterBody3D
## NPC — state-machine driven villager with personality (job + hobby) and
## visible emotional reactions to disasters and blessings.

class_name NPC

const CharacterBuilderClass := preload("res://scripts/procedural/character_builder.gd")
const SpeechBubbleClass := preload("res://scripts/ui/speech_bubble.gd")

signal died(npc: NPC)

enum State { WANDER, GO_HOME, AT_HOME, GO_WORK, AT_WORK, GO_PRAY, PRAYING, FLEE }

const ARRIVE_DIST := 1.2
const REPLAN_INTERVAL_SEC := 4.0

# personality lookup tables
const JOBS := ["farmer", "shopkeeper", "teacher", "doctor", "smith", "baker", "musician", "artist", "fisher", "guard"]
const HOBBIES := ["fishing", "reading", "cooking", "exercise", "painting", "music", "gardening", "stargazing", "dancing"]
const JOB_EMOJI := {
	"farmer": "🌾", "shopkeeper": "🛒", "teacher": "📚", "doctor": "🩺",
	"smith": "🔨", "baker": "🍞", "musician": "🎵", "artist": "🎨",
	"fisher": "🎣", "guard": "🛡️",
}
const HOBBY_EMOJI := {
	"fishing": "🎣", "reading": "📖", "cooking": "🍳", "exercise": "💪",
	"painting": "🎨", "music": "🎵", "gardening": "🌱", "stargazing": "🌙", "dancing": "💃",
}

var data: Dictionary = {}
var hp: float = 100.0
var max_hp: float = 100.0
var speed: float = 2.0
var world_size: float = 60.0

var state: int = State.WANDER
var target_pos: Vector3 = Vector3.ZERO
var home_b: Variant = null
var work_b: Variant = null
var _replan_in: float = 0.0
var _state_dwell: float = 0.0
var _last_known_fear: float = 0.0
var _walk_phase: float = 0.0
var _figure_root: Node3D
var _badge: SpeechBubble        # persistent activity badge
var _last_state: int = -1

# personality
var personality: Dictionary = {}    # {job, hobby, palette}

func setup(npc_data: Dictionary, world_size_m: float) -> void:
	data = npc_data
	max_hp = float(data.get("hp", 100.0))
	hp = max_hp
	speed = float(data.get("speed", 2.0))
	world_size = world_size_m
	_assign_personality()
	_pick_random_target()
	_build_visual()

func assign_home(b: Variant) -> void:
	home_b = b

func assign_work(b: Variant) -> void:
	work_b = b

# ---------------- Visual ----------------
func _assign_personality() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.randomize()
	personality = {
		"job":     JOBS[rng.randi() % JOBS.size()],
		"hobby":   HOBBIES[rng.randi() % HOBBIES.size()],
		"palette": CharacterBuilderClass.random_palette(rng),
	}
	# child / priest overrides
	var palette: Dictionary = personality["palette"]
	if String(data.get("id", "")) == "priest":
		personality["job"] = "priest"
		palette["shirt"] = Color("#3a3060")
	if String(data.get("id", "")) == "child":
		personality["job"] = "student"
		palette["shirt"] = Color("#ffd166")

func _build_visual() -> void:
	# physics body
	var col := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.3
	capsule.height = 1.5
	col.shape = capsule
	col.position.y = 0.85
	add_child(col)

	# 1) try GLB model first
	var path := String(data.get("model", ""))
	if path != "" and ResourceLoader.exists(path):
		var packed := load(path)
		if packed is PackedScene:
			_figure_root = (packed as PackedScene).instantiate() as Node3D
			if _figure_root != null:
				add_child(_figure_root)
				return
	# 2) fallback: procedural composite figure
	var palette: Dictionary = personality.get("palette", {})
	var opts: Dictionary = palette.duplicate()
	opts["child"] = String(data.get("id", "")) == "child"
	_figure_root = CharacterBuilderClass.build(opts)
	add_child(_figure_root)

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

	if state != _last_state:
		_last_state = state
		_update_activity_badge()

func _decide_next_state() -> void:
	var behaviors: Array = data.get("behaviors", ["wander"])
	var fear_thresh: float = float(data.get("fear_threshold", 80))
	if _last_known_fear > fear_thresh and "flee" in behaviors:
		_set_state(State.FLEE, _flee_target())
		return
	var t: float = TimeSystem.time_in_day if has_node("/root/TimeSystem") else 0.5
	if (t < 0.20 or t > 0.80):
		var h: Variant = home_b if is_instance_valid(home_b) else _find_home()
		if h != null:
			home_b = h
			_set_state(State.GO_HOME, h.global_position)
			return
	var pray_chance: float = 0.10
	if String(data.get("id", "")) == "priest":
		pray_chance = 0.85
	if t > 0.20 and t < 0.30 and "pray" in behaviors and randf() < pray_chance:
		var church: Variant = TownRegistry.random_in(TownRegistry.religious) if has_node("/root/TownRegistry") else null
		if church != null:
			_set_state(State.GO_PRAY, church.global_position)
			return
	if t > 0.30 and t < 0.75 and ("work" in behaviors or "wander" in behaviors):
		var w: Variant = work_b if is_instance_valid(work_b) else _find_work()
		if w != null:
			work_b = w
			_set_state(State.GO_WORK, w.global_position)
			return
	_set_state(State.WANDER, _random_pos())

func _set_state(new_state: int, new_target: Vector3) -> void:
	state = new_state
	target_pos = new_target
	_state_dwell = 0.0

func _run_state(delta: float) -> void:
	match state:
		State.WANDER:
			_walk_toward(target_pos, 1.0, delta)
			if _arrived(target_pos):
				_set_state(State.WANDER, _random_pos())
		State.GO_HOME:
			_walk_toward(target_pos, 1.0, delta)
			if _arrived(target_pos):
				_set_state(State.AT_HOME, target_pos)
		State.AT_HOME:
			velocity = Vector3.ZERO
			move_and_slide()
		State.GO_WORK:
			_walk_toward(target_pos, 1.0, delta)
			if _arrived(target_pos):
				_set_state(State.AT_WORK, target_pos)
		State.AT_WORK:
			velocity = Vector3.ZERO
			move_and_slide()
			# subtle "working" bob
			if _figure_root:
				_figure_root.rotation.y += 0.6 * delta
			if _state_dwell > 8.0:
				_set_state(State.WANDER, _around(target_pos, 5.0))
		State.GO_PRAY:
			_walk_toward(target_pos, 1.0, delta)
			if _arrived(target_pos):
				_set_state(State.PRAYING, target_pos)
		State.PRAYING:
			velocity = Vector3.ZERO
			move_and_slide()
			if has_node("/root/FaithSystem") and _state_dwell > 1.0:
				FaithSystem.add(0.5 * delta * float(data.get("faith_contribution", 1.0)))
		State.FLEE:
			_walk_toward(target_pos, 1.7, delta)
			if _arrived(target_pos):
				_set_state(State.FLEE, _flee_target())

# ---------------- Movement helpers ----------------
func _walk_toward(p: Vector3, speed_mul: float, delta: float) -> void:
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
	# walking bob
	_walk_phase += delta * 8.0 * speed_mul
	if _figure_root:
		_figure_root.position.y = abs(sin(_walk_phase)) * 0.05
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

func _find_home() -> Variant:
	if not has_node("/root/TownRegistry"):
		return null
	return TownRegistry.nearest(TownRegistry.residential, global_position)

func _find_work() -> Variant:
	if not has_node("/root/TownRegistry"):
		return null
	var w: Variant = TownRegistry.nearest(TownRegistry.economy, global_position)
	if w == null:
		w = TownRegistry.nearest(TownRegistry.residential, global_position)
	return w

func _pick_random_target() -> void:
	target_pos = _random_pos()

# ---------------- Activity badge ----------------
func _update_activity_badge() -> void:
	var emoji := _emoji_for_state()
	if emoji == "":
		if _badge and is_instance_valid(_badge):
			_badge.queue_free()
			_badge = null
		return
	if _badge == null or not is_instance_valid(_badge):
		_badge = SpeechBubbleClass.attach(self, emoji)
	else:
		_badge.set_text(emoji)

func _emoji_for_state() -> String:
	match state:
		State.AT_WORK:
			var job_key: String = String(personality.get("job", ""))
			return String(JOB_EMOJI.get(job_key, "💼"))
		State.WANDER:
			# show hobby occasionally
			if randf() < 0.5:
				var hobby_key: String = String(personality.get("hobby", ""))
				return String(HOBBY_EMOJI.get(hobby_key, ""))
			return ""
		State.PRAYING:
			return "🙏"
		State.GO_HOME, State.AT_HOME:
			return "💤"
		State.FLEE:
			return "😱"
		_:
			return ""

# ---------------- Damage / Heal ----------------
func take_damage(amount: float) -> void:
	hp -= amount
	if hp <= 0.0:
		emit_signal("died", self)
		queue_free()
		return
	_react_negative()

func heal(amount: float) -> void:
	hp = min(hp + amount, max_hp)
	_react_positive()

func bless() -> void:
	_react_positive()

func scare() -> void:
	_react_negative()

func _react_positive() -> void:
	# pop a heart and bounce
	SpeechBubbleClass.spawn(self, "❤️", 1.5, 2.6)
	_animate_bounce(1.4, Color.WHITE)

func _react_negative() -> void:
	SpeechBubbleClass.spawn(self, "😱", 1.5, 2.6)
	_animate_shake()

func _animate_bounce(amplitude: float, _flash: Color) -> void:
	if _figure_root == null:
		return
	var tw := create_tween()
	tw.tween_property(_figure_root, "scale", Vector3(1.0, amplitude, 1.0), 0.12)
	tw.tween_property(_figure_root, "scale", Vector3(1.0, 1.0, 1.0), 0.20)

func _animate_shake() -> void:
	if _figure_root == null:
		return
	var tw := create_tween()
	tw.tween_property(_figure_root, "rotation:z", deg_to_rad(8), 0.05)
	tw.tween_property(_figure_root, "rotation:z", deg_to_rad(-8), 0.10)
	tw.tween_property(_figure_root, "rotation:z", 0.0, 0.05)
