extends Node3D
## Main — builds the world programmatically (camera, sun, ground, buildings, NPCs)
## and wires HUD <-> systems together. No .tscn editing required.

const HUDClass := preload("res://scripts/ui/hud.gd")
const NPCClass := preload("res://scripts/entities/npc.gd")
const BuildingClass := preload("res://scripts/entities/building.gd")
const PowerVFXClass := preload("res://scripts/powers/power_vfx.gd")

var _camera: Camera3D
var _camera_pivot: Node3D
var _zoom: float = 28.0
var _cam_yaw: float = 0.0
var _hud: HUD
var _world_size: float = 60.0
var _selected_power_id: String = ""
var _selected_power_kind: String = ""    # "disaster" | "blessing"
var _power_cooldowns: Dictionary = {}    # id -> next-allowed-time
var _npcs: Array[NPC] = []
var _buildings: Array[Building] = []
var _ground: StaticBody3D

func _ready() -> void:
	# Wait one frame so DataLoader (autoload) has populated
	await get_tree().process_frame
	if has_node("/root/DataLoader"):
		_world_size = float(DataLoader.balance_value("town_size", 60.0))
		_zoom = float(DataLoader.balance_value("camera_default_zoom", 28.0))

	_build_environment()
	_build_camera()
	_build_ground()

	# load existing save if present, else fresh world
	var loaded_state: Dictionary = SaveSystem.load_state() if has_node("/root/SaveSystem") else {}
	if loaded_state.is_empty():
		_spawn_buildings()
		_spawn_npcs()
	else:
		_restore_from(loaded_state)
	_assign_npc_locations()

	_build_hud()
	_wire_signals()

	# bind save system after world exists
	if has_node("/root/SaveSystem"):
		SaveSystem.bind(self, _npcs, _buildings)

	# initial HUD push
	_hud.update_faith(FaithSystem.faith, FaithSystem.max_faith)
	_hud.update_population(_npcs.size())
	_hud.update_prosperity(EconomySystem.prosperity)
	_hud.update_fear(FaithSystem.fear)
	_hud.update_day(TimeSystem.day)
	_hud.push_log("⚡ %s" % I18N.t("HUD_HINT_SELECT"))

# ---------------- Environment ----------------
func _build_environment() -> void:
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var pmat := ProceduralSkyMaterial.new()
	pmat.sky_top_color = Color(0.07, 0.12, 0.28)
	pmat.sky_horizon_color = Color(0.20, 0.32, 0.55)
	pmat.ground_bottom_color = Color(0.04, 0.05, 0.10)
	pmat.ground_horizon_color = Color(0.10, 0.13, 0.22)
	pmat.sun_angle_max = 30.0
	sky.sky_material = pmat
	e.sky = sky
	e.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	e.ambient_light_energy = 0.6
	e.fog_enabled = true
	e.fog_density = 0.005
	e.fog_light_color = Color(0.6, 0.7, 1.0)
	env.environment = e
	add_child(env)

	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(deg_to_rad(-50), deg_to_rad(40), 0)
	sun.light_energy = 1.2
	sun.light_color = Color(1.0, 0.95, 0.85)
	sun.shadow_enabled = true
	add_child(sun)

func _build_camera() -> void:
	_camera_pivot = Node3D.new()
	add_child(_camera_pivot)
	_camera = Camera3D.new()
	_camera.fov = 55.0
	_camera_pivot.add_child(_camera)
	_apply_camera()
	_camera.current = true

func _apply_camera() -> void:
	# top-down-ish orbit: place the camera above and behind the pivot, then look at it
	var height: float = _zoom * 0.85
	var horiz: float = _zoom * 0.55
	var offset := Vector3(sin(_cam_yaw) * horiz, height, cos(_cam_yaw) * horiz)
	_camera.global_position = _camera_pivot.global_position + offset
	_camera.look_at(_camera_pivot.global_position, Vector3.UP)

func _build_ground() -> void:
	_ground = StaticBody3D.new()
	add_child(_ground)
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(_world_size + 20, 0.5, _world_size + 20)
	col.shape = box
	col.position.y = -0.25
	_ground.add_child(col)

	var mi := MeshInstance3D.new()
	var pl := PlaneMesh.new()
	pl.size = Vector2(_world_size + 20, _world_size + 20)
	mi.mesh = pl
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.20, 0.32, 0.20)
	mi.material_override = mat
	_ground.add_child(mi)

	# road cross
	for axis in [Vector3.RIGHT, Vector3.FORWARD]:
		var rmi := MeshInstance3D.new()
		var rp := PlaneMesh.new()
		if axis == Vector3.RIGHT:
			rp.size = Vector2(_world_size, 4)
		else:
			rp.size = Vector2(4, _world_size)
		rmi.mesh = rp
		var rmat := StandardMaterial3D.new()
		rmat.albedo_color = Color(0.22, 0.22, 0.28)
		rmi.material_override = rmat
		rmi.position.y = 0.02
		_ground.add_child(rmi)

# ---------------- Spawning ----------------
func _spawn_buildings() -> void:
	if not has_node("/root/DataLoader"):
		return
	var defs: Array = DataLoader.buildings
	if defs.is_empty():
		return
	var n: int = int(DataLoader.balance_value("starting_buildings", 12))
	# weighted choice
	var pool: Array = []
	for d in defs:
		var w: int = int(d.get("weight", 1))
		for _i in w:
			pool.append(d)
	if pool.is_empty():
		return
	for i in n:
		var def: Dictionary = pool[randi() % pool.size()]
		var b := BuildingClass.new()
		b.setup(def)
		var pos := Vector3(
			randf_range(-_world_size * 0.45, _world_size * 0.45),
			0.0,
			randf_range(-_world_size * 0.45, _world_size * 0.45)
		)
		# nudge away from the cross-roads
		if absf(pos.x) < 3.0:
			pos.x = (1.0 if pos.x >= 0.0 else -1.0) * 3.5
		if absf(pos.z) < 3.0:
			pos.z = (1.0 if pos.z >= 0.0 else -1.0) * 3.5
		b.position = pos
		b.destroyed.connect(_on_building_destroyed)
		add_child(b)
		_buildings.append(b)
		if has_node("/root/TownRegistry"):
			TownRegistry.register_building(b)

func _spawn_npcs() -> void:
	if not has_node("/root/DataLoader"):
		return
	var defs: Array = DataLoader.npcs
	if defs.is_empty():
		return
	var n: int = int(DataLoader.balance_value("starting_npcs", 18))
	var pool: Array = []
	for d in defs:
		var w: int = int(d.get("weight", 1))
		for _i in w:
			pool.append(d)
	if pool.is_empty():
		return
	for i in n:
		var def: Dictionary = pool[randi() % pool.size()]
		var npc := NPCClass.new()
		add_child(npc)
		npc.setup(def, _world_size)
		npc.position = Vector3(
			randf_range(-_world_size * 0.45, _world_size * 0.45),
			0.0,
			randf_range(-_world_size * 0.45, _world_size * 0.45)
		)
		npc.died.connect(_on_npc_died)
		_npcs.append(npc)
		if has_node("/root/TownRegistry"):
			TownRegistry.register_npc(npc)

# ---------------- HUD wiring ----------------
func _build_hud() -> void:
	_hud = HUDClass.new()
	add_child(_hud)
	_hud.populate_powers(DataLoader.disasters, DataLoader.blessings)
	_hud.power_selected.connect(_on_power_selected)
	_hud.speed_change_requested.connect(func(s: float): TimeSystem.set_speed(s))
	_hud.pause_toggle_requested.connect(func(): TimeSystem.toggle_pause())
	_hud.lang_change_requested.connect(func(l: String):
		I18N.set_lang(l)
		# rebuild HUD labels by re-populating (cheapest)
		_hud.queue_free()
		_build_hud()
	)

func _wire_signals() -> void:
	FaithSystem.faith_changed.connect(func(v, mv): _hud.update_faith(v, mv))
	FaithSystem.fear_changed.connect(func(v): _hud.update_fear(v))
	EconomySystem.prosperity_changed.connect(func(v): _hud.update_prosperity(v))
	TimeSystem.day_advanced.connect(func(d): _hud.update_day(d))

	DisasterSystem.power_cast.connect(_on_power_cast)
	DisasterSystem.damage_dealt.connect(_on_damage_dealt)
	DisasterSystem.heal_dealt.connect(_on_heal_dealt)
	DisasterSystem.log_message.connect(func(t): _hud.push_log(t))

# ---------------- Input / Camera ----------------
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom = max(_zoom - 2.0, float(DataLoader.balance_value("camera_min_zoom", 8.0)))
			_apply_camera()
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom = min(_zoom + 2.0, float(DataLoader.balance_value("camera_max_zoom", 60.0)))
			_apply_camera()
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			_try_cast_at_mouse(mb.position)
	elif event is InputEventMouseMotion:
		var mm: InputEventMouseMotion = event
		if mm.button_mask & MOUSE_BUTTON_MASK_RIGHT:
			_cam_yaw -= mm.relative.x * 0.005
			_apply_camera()

	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_SPACE: TimeSystem.toggle_pause()
			KEY_1: TimeSystem.set_speed(1.0)
			KEY_2: TimeSystem.set_speed(2.0)
			KEY_3: TimeSystem.set_speed(4.0)
			KEY_F2:
				if has_node("/root/SaveSystem"):
					SaveSystem.save_now()
					_hud.push_log("💾 saved")
			KEY_F3:
				if has_node("/root/SaveSystem"):
					var st: Dictionary = SaveSystem.load_state()
					if not st.is_empty():
						get_tree().reload_current_scene()
			KEY_F4:
				if has_node("/root/SaveSystem"):
					SaveSystem.clear_save()
					get_tree().reload_current_scene()
			KEY_W:
				_camera_pivot.position += Vector3(0, 0, -2).rotated(Vector3.UP, _cam_yaw)
				_apply_camera()
			KEY_S:
				_camera_pivot.position += Vector3(0, 0, 2).rotated(Vector3.UP, _cam_yaw)
				_apply_camera()
			KEY_A:
				_camera_pivot.position += Vector3(-2, 0, 0).rotated(Vector3.UP, _cam_yaw)
				_apply_camera()
			KEY_D:
				_camera_pivot.position += Vector3(2, 0, 0).rotated(Vector3.UP, _cam_yaw)
				_apply_camera()

func _try_cast_at_mouse(screen_pos: Vector2) -> void:
	if _selected_power_id == "":
		_hud.hint(I18N.t("HUD_HINT_SELECT"))
		return
	var data: Dictionary = DataLoader.get_by_id(_selected_power_id)
	if data.is_empty():
		return
	# cooldown
	var now := Time.get_ticks_msec() / 1000.0
	var allowed_at: float = _power_cooldowns.get(_selected_power_id, 0.0)
	if now < allowed_at:
		_hud.hint(I18N.t("HUD_HINT_COOLDOWN"))
		return
	# faith
	var cost := float(data.get("cost_faith", 0))
	if not FaithSystem.spend(cost):
		_hud.hint(I18N.t("HUD_HINT_NOT_ENOUGH"))
		return
	# raycast to ground
	var from := _camera.project_ray_origin(screen_pos)
	var to   := from + _camera.project_ray_normal(screen_pos) * 1000.0
	var space := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(from, to)
	var hit := space.intersect_ray(q)
	var pos: Vector3
	if hit.has("position"):
		pos = hit["position"]
	else:
		# math fallback: intersect with y=0 plane
		var dir := (to - from).normalized()
		if abs(dir.y) < 0.001:
			return
		var tparam := -from.y / dir.y
		pos = from + dir * tparam
	# cast
	if _selected_power_kind == "disaster":
		DisasterSystem.cast_disaster(data, pos)
	else:
		DisasterSystem.cast_blessing(data, pos)
	_power_cooldowns[_selected_power_id] = now + float(data.get("cooldown_sec", 1.0))
	_hud.set_cooldown(_selected_power_id, float(data.get("cooldown_sec", 1.0)))
	if has_node("/root/Telemetry"):
		Telemetry.track("power_cast", {"id": _selected_power_id, "kind": _selected_power_kind})

# ---------------- Power resolution ----------------
func _on_power_selected(id: String, kind: String) -> void:
	_selected_power_id = id
	_selected_power_kind = kind

func _on_power_cast(power_id: String, position: Vector3) -> void:
	var data: Dictionary = DataLoader.get_by_id(power_id)
	if data.is_empty():
		return
	var vfx := PowerVFXClass.new()
	vfx.position = position
	add_child(vfx)
	vfx.play(data)

func _on_damage_dealt(position: Vector3, radius: float, amount: float) -> void:
	# damage NPCs
	for npc in _npcs:
		if not is_instance_valid(npc):
			continue
		if npc.global_position.distance_to(position) <= radius:
			npc.take_damage(amount)
	# damage buildings
	for b in _buildings:
		if not is_instance_valid(b):
			continue
		if b.global_position.distance_to(position) <= radius:
			b.take_damage(amount)

func _on_heal_dealt(position: Vector3, radius: float, amount: float) -> void:
	for npc in _npcs:
		if not is_instance_valid(npc):
			continue
		if npc.global_position.distance_to(position) <= radius:
			npc.heal(amount)

func _on_npc_died(npc: NPC) -> void:
	_npcs.erase(npc)
	_hud.update_population(_npcs.size())
	if has_node("/root/TownRegistry"):
		TownRegistry.unregister_npc(npc)
	if has_node("/root/AudioSystem"):
		AudioSystem.play("npc_die")
	DisasterSystem.log(I18N.t("LOG_NPC_DIED"))

func _on_building_destroyed(b: Building) -> void:
	_buildings.erase(b)
	if has_node("/root/TownRegistry"):
		TownRegistry.unregister_building(b)
	if has_node("/root/AudioSystem"):
		AudioSystem.play("building_destroy")
	DisasterSystem.log(I18N.t("LOG_BUILDING_DESTROYED"))

# ---------------- NPC location assignment ----------------
func _assign_npc_locations() -> void:
	if not has_node("/root/TownRegistry"):
		return
	for npc in _npcs:
		if not is_instance_valid(npc):
			continue
		var home = TownRegistry.random_in(TownRegistry.residential)
		var work = TownRegistry.random_in(TownRegistry.economy)
		if home: npc.assign_home(home)
		if work: npc.assign_work(work)

# ---------------- Save/Restore ----------------
func _restore_from(state: Dictionary) -> void:
	# restore world from a saved snapshot
	if has_node("/root/TimeSystem"):
		TimeSystem.day = int(state.get("day", 1))
		TimeSystem.time_in_day = float(state.get("time_in_day", 0.0))
	if has_node("/root/FaithSystem"):
		FaithSystem.faith = float(state.get("faith", 30.0))
		FaithSystem.max_faith = float(state.get("max_faith", 100.0))
		FaithSystem.fear = float(state.get("fear", 0.0))
	if has_node("/root/EconomySystem"):
		EconomySystem.prosperity = float(state.get("prosperity", 50.0))
	if has_node("/root/I18N"):
		I18N.set_lang(String(state.get("lang", "ko")))
	# buildings
	for entry in state.get("buildings", []):
		var def: Dictionary = DataLoader.get_by_id(String(entry.get("id", "")))
		if def.is_empty():
			continue
		var b := BuildingClass.new()
		b.setup(def)
		b.position = Vector3(float(entry.get("x", 0.0)), 0.0, float(entry.get("z", 0.0)))
		b.hp = float(entry.get("hp", b.max_hp))
		b.destroyed.connect(_on_building_destroyed)
		add_child(b)
		_buildings.append(b)
		if has_node("/root/TownRegistry"):
			TownRegistry.register_building(b)
	# npcs
	for entry in state.get("npcs", []):
		var def: Dictionary = DataLoader.get_by_id(String(entry.get("id", "")))
		if def.is_empty():
			continue
		var n := NPCClass.new()
		add_child(n)
		n.setup(def, _world_size)
		n.position = Vector3(float(entry.get("x", 0.0)), 0.0, float(entry.get("z", 0.0)))
		n.hp = float(entry.get("hp", n.max_hp))
		n.died.connect(_on_npc_died)
		_npcs.append(n)
		if has_node("/root/TownRegistry"):
			TownRegistry.register_npc(n)
	print("[Main] restored save: %d buildings, %d npcs, day=%d" % [
		_buildings.size(), _npcs.size(), int(state.get("day", 0))
	])
