extends RefCounted
## BuildingBuilder — composes a small low-poly building from primitives.
## Adds a colored body, sloped roof, windows, and a door so buildings look
## like buildings even without 3D models loaded.

class_name BuildingBuilder

const ROOF_COLORS := [
	Color("#8b3a3a"), Color("#5b3a26"), Color("#34495e"), Color("#a14a4a"),
	Color("#2e3a4a"),
]
const WINDOW_COLOR := Color("#bce0ff")
const DOOR_COLOR := Color("#4a2e1a")

## Returns a Node3D positioned with base on y=0.
## Footprint = [width, depth] in meters; tags drives style choice.
static func build(footprint: Array, body_color: Color, tags: Array, rng: RandomNumberGenerator = null) -> Node3D:
	if rng == null:
		rng = RandomNumberGenerator.new()
		rng.randomize()
	var sx: float = float(footprint[0]) if footprint.size() >= 2 else 3.0
	var sz: float = float(footprint[1]) if footprint.size() >= 2 else 3.0
	var is_church := tags.has("religious") or tags.has("faith_source")
	var is_economy := tags.has("economy")
	var is_nature := tags.has("nature")

	var root := Node3D.new()
	root.name = "Building"

	if is_nature:
		# render as a clump of green volume (a tiny park / tree mass)
		var trunk := _box(Vector3(0, 0.5, 0), Vector3(0.4, 1.0, 0.4), Color("#5d3a26"))
		root.add_child(trunk)
		var foliage := _box(Vector3(0, 1.6, 0), Vector3(sx * 0.8, 1.4, sz * 0.8), Color("#5fb04a"))
		root.add_child(foliage)
		var foliage2 := _box(Vector3(rng.randf_range(-0.6, 0.6), 2.6, rng.randf_range(-0.6, 0.6)),
			Vector3(sx * 0.5, 1.0, sz * 0.5), Color("#7ec06b"))
		root.add_child(foliage2)
		return root

	# main body
	var body_h: float = 2.6
	if is_church: body_h = 4.0
	elif is_economy: body_h = 3.0
	body_h += rng.randf_range(-0.2, 0.4)
	var body := _box(Vector3(0, body_h * 0.5, 0), Vector3(sx, body_h, sz), body_color)
	root.add_child(body)

	# roof — pyramid (stretched cone)
	var roof_color: Color = ROOF_COLORS[rng.randi() % ROOF_COLORS.size()]
	var roof_h: float = 1.2 if is_church else 0.9
	var roof_mi := MeshInstance3D.new()
	roof_mi.name = "Roof"
	var roof_mesh := PrismMesh.new()
	roof_mesh.size = Vector3(sx + 0.1, roof_h, sz + 0.1)
	roof_mi.mesh = roof_mesh
	var roof_mat := StandardMaterial3D.new()
	roof_mat.albedo_color = roof_color
	roof_mat.roughness = 0.9
	roof_mi.material_override = roof_mat
	roof_mi.position.y = body_h + roof_h * 0.5
	root.add_child(roof_mi)

	# door (front face — assume +Z is "front")
	var door := _box(Vector3(0, 0.6, sz * 0.5 + 0.02), Vector3(0.6, 1.2, 0.05), DOOR_COLOR)
	root.add_child(door)

	# windows — distribute on +Z and -Z faces
	var win_size := Vector3(0.5, 0.5, 0.04)
	var win_y_levels: Array = [body_h * 0.65]
	if body_h > 3.2:
		win_y_levels = [body_h * 0.4, body_h * 0.75]
	for win_y in win_y_levels:
		var n_per_row := max(1, int((sx - 1.0) / 1.4))
		for i in n_per_row:
			var x := (i - (n_per_row - 1) * 0.5) * 1.2
			# front
			root.add_child(_box(Vector3(x, win_y, sz * 0.5 + 0.02), win_size, WINDOW_COLOR, true))
			# back
			root.add_child(_box(Vector3(x, win_y, -sz * 0.5 - 0.02), win_size, WINDOW_COLOR, true))

	# church spire / cross
	if is_church:
		var spire := MeshInstance3D.new()
		var sm := CylinderMesh.new()
		sm.top_radius = 0.06
		sm.bottom_radius = 0.18
		sm.height = 1.6
		spire.mesh = sm
		var sm_mat := StandardMaterial3D.new()
		sm_mat.albedo_color = roof_color.lerp(Color.WHITE, 0.15)
		spire.material_override = sm_mat
		spire.position.y = body_h + roof_h + 0.8
		root.add_child(spire)
		# cross on top
		var cross_v := _box(Vector3(0, body_h + roof_h + 1.7, 0), Vector3(0.06, 0.45, 0.06), Color("#ffd166"))
		root.add_child(cross_v)
		var cross_h := _box(Vector3(0, body_h + roof_h + 1.7, 0), Vector3(0.28, 0.06, 0.06), Color("#ffd166"))
		root.add_child(cross_h)

	# shop sign (small floating board over the door for economy buildings)
	if is_economy:
		var sign_node := _box(Vector3(0, body_h * 0.85, sz * 0.5 + 0.04),
			Vector3(min(2.0, sx - 0.4), 0.5, 0.05), Color("#ffd166"))
		root.add_child(sign_node)

	return root

static func _box(pos: Vector3, size: Vector3, col: Color, emissive: bool = false) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mi.mesh = box
	var mat := StandardMaterial3D.new()
	mat.albedo_color = col
	mat.roughness = 0.8
	if emissive:
		mat.emission_enabled = true
		mat.emission = col
		mat.emission_energy_multiplier = 0.3
	mi.material_override = mat
	mi.position = pos
	return mi
