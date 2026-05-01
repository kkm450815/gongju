extends Node3D
## Car — drives back and forth along one of the cross roads of the town.
## Procedural visual: low body box + roof + 4 wheel cylinders + windows.

class_name Car

const COLORS := [
	Color("#ff5c7a"), Color("#5b8def"), Color("#06b894"),
	Color("#ffd166"), Color("#a18cf0"), Color("#cfd8e8"),
	Color("#222831"), Color("#f5945c"),
]

var speed: float = 6.0
var direction: Vector3 = Vector3.RIGHT
var bounds: float = 30.0      # half-extent of the road; flips at the edges
var rng := RandomNumberGenerator.new()

func setup(road_axis: String, lane: float, world_size: float) -> void:
	rng.randomize()
	speed = rng.randf_range(4.0, 9.0)
	bounds = world_size * 0.45
	if road_axis == "x":
		direction = Vector3.RIGHT * (1.0 if rng.randf() < 0.5 else -1.0)
		position = Vector3(rng.randf_range(-bounds, bounds), 0.3, lane)
	else:
		direction = Vector3.FORWARD * (1.0 if rng.randf() < 0.5 else -1.0)
		position = Vector3(lane, 0.3, rng.randf_range(-bounds, bounds))
	_face_direction()
	_build_visual()

func _physics_process(delta: float) -> void:
	position += direction * speed * delta
	# wrap on the road
	if abs(direction.x) > 0.1:
		if position.x > bounds:
			direction = Vector3.LEFT
			_face_direction()
		elif position.x < -bounds:
			direction = Vector3.RIGHT
			_face_direction()
	else:
		if position.z > bounds:
			direction = Vector3.FORWARD
			_face_direction()
		elif position.z < -bounds:
			direction = Vector3.BACK
			_face_direction()
	# subtle bob
	position.y = 0.3 + sin(Time.get_ticks_msec() * 0.005) * 0.02

func _face_direction() -> void:
	# our car model is oriented with the long body along local +X (headlights at +X),
	# so set yaw such that local +X points along `direction`.
	if direction.length() < 0.001:
		return
	rotation.y = atan2(-direction.z, direction.x)

func _build_visual() -> void:
	var body_color: Color = COLORS[rng.randi() % COLORS.size()]
	# body
	var body := _box(Vector3(0, 0.0, 0), Vector3(2.4, 0.5, 1.1), body_color)
	add_child(body)
	# roof / cabin
	var roof := _box(Vector3(-0.2, 0.45, 0), Vector3(1.4, 0.5, 1.0), body_color.darkened(0.1))
	add_child(roof)
	# windows
	add_child(_box(Vector3(-0.2, 0.45, 0.51), Vector3(1.2, 0.35, 0.04), Color("#bce0ff"), true))
	add_child(_box(Vector3(-0.2, 0.45, -0.51), Vector3(1.2, 0.35, 0.04), Color("#bce0ff"), true))
	# headlights
	add_child(_box(Vector3(1.18, 0.05, 0.4), Vector3(0.06, 0.12, 0.12), Color("#ffeaa7"), true))
	add_child(_box(Vector3(1.18, 0.05, -0.4), Vector3(0.06, 0.12, 0.12), Color("#ffeaa7"), true))
	# wheels
	for x in [-0.85, 0.85]:
		for z in [-0.55, 0.55]:
			var w := MeshInstance3D.new()
			var cyl := CylinderMesh.new()
			cyl.top_radius = 0.22
			cyl.bottom_radius = 0.22
			cyl.height = 0.18
			w.mesh = cyl
			var wm := StandardMaterial3D.new()
			wm.albedo_color = Color("#1b1b1b")
			w.material_override = wm
			w.position = Vector3(x, -0.1, z)
			w.rotation = Vector3(0, 0, deg_to_rad(90))
			add_child(w)

func _box(pos: Vector3, size: Vector3, col: Color, emissive: bool = false) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mi.mesh = box
	var mat := StandardMaterial3D.new()
	mat.albedo_color = col
	if emissive:
		mat.emission_enabled = true
		mat.emission = col
		mat.emission_energy_multiplier = 0.6
	mi.material_override = mat
	mi.position = pos
	return mi
