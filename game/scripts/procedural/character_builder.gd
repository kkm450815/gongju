extends RefCounted
## CharacterBuilder — composes a small humanoid figure from primitives.
## Used as a fallback when no GLB model is available. Looks like a simple
## "low-poly toon" person: head + body + arms + legs with random clothing colors.
##
## Usage:
##   var fig := CharacterBuilder.build({"skin": Color, "shirt": Color, "pants": Color, "hair": Color, "scale": 1.0, "child": false})
##   parent.add_child(fig)

class_name CharacterBuilder

const SKIN_COLORS := [
	Color("#f4d4b4"), Color("#e8c39e"), Color("#cb9b76"),
	Color("#a37553"), Color("#8c5b3f"), Color("#5d3a26"),
]
const SHIRT_COLORS := [
	Color("#ff5c7a"), Color("#5b8def"), Color("#06b894"), Color("#ffd166"),
	Color("#a18cf0"), Color("#f5945c"), Color("#7ee07b"), Color("#cfd8e8"),
]
const PANTS_COLORS := [
	Color("#3a4170"), Color("#1f2545"), Color("#5d3a26"), Color("#222831"),
	Color("#4a5568"),
]
const HAIR_COLORS := [
	Color("#1b1b1b"), Color("#3a2618"), Color("#7a4b21"), Color("#c9a86b"),
	Color("#e2c79f"), Color("#bb3a3a"),
]

static func random_palette(rng: RandomNumberGenerator) -> Dictionary:
	return {
		"skin":  SKIN_COLORS[rng.randi() % SKIN_COLORS.size()],
		"shirt": SHIRT_COLORS[rng.randi() % SHIRT_COLORS.size()],
		"pants": PANTS_COLORS[rng.randi() % PANTS_COLORS.size()],
		"hair":  HAIR_COLORS[rng.randi() % HAIR_COLORS.size()],
	}

## Returns a Node3D with the figure standing on y=0, total height ~1.6m (or 1.1m if child).
static func build(opts: Dictionary = {}) -> Node3D:
	var skin: Color  = opts.get("skin",  Color("#f4d4b4"))
	var shirt: Color = opts.get("shirt", Color("#06b894"))
	var pants: Color = opts.get("pants", Color("#3a4170"))
	var hair: Color  = opts.get("hair",  Color("#1b1b1b"))
	var is_child: bool = opts.get("child", false)
	var s: float = 0.7 if is_child else 1.0

	var root := Node3D.new()
	root.name = "Figure"

	# legs
	var leg_y := 0.4 * s
	var leg_h := 0.7 * s
	var leg_size := Vector3(0.18, leg_h, 0.18) * s
	root.add_child(_box(Vector3(-0.12 * s, leg_y, 0.0), leg_size, pants, "LegL"))
	root.add_child(_box(Vector3( 0.12 * s, leg_y, 0.0), leg_size, pants, "LegR"))

	# torso (shirt)
	var torso_y := (leg_h + 0.4 * s)
	var torso_size := Vector3(0.5, 0.55, 0.32) * s
	root.add_child(_box(Vector3(0, torso_y, 0), torso_size, shirt, "Torso"))

	# arms
	var arm_y := torso_y + 0.05
	var arm_size := Vector3(0.12, 0.5, 0.12) * s
	root.add_child(_box(Vector3(-0.32 * s, arm_y, 0.0), arm_size, shirt, "ArmL"))
	root.add_child(_box(Vector3( 0.32 * s, arm_y, 0.0), arm_size, shirt, "ArmR"))

	# head
	var head_y := torso_y + (torso_size.y * 0.5) + (0.18 * s)
	var head_node := _box(Vector3(0, head_y, 0), Vector3(0.36, 0.36, 0.36) * s, skin, "Head")
	root.add_child(head_node)

	# hair (small slab on top + back)
	var hair_y := head_y + 0.18 * s
	root.add_child(_box(Vector3(0, hair_y, 0), Vector3(0.40, 0.10, 0.40) * s, hair, "Hair"))

	# eyes (tiny black dots)
	var eye_z := 0.18 * s
	var eye_size := Vector3(0.05, 0.05, 0.04) * s
	var eye_color := Color(0.06, 0.06, 0.06)
	var eye_l := _box(Vector3(-0.07 * s, head_y + 0.02 * s, eye_z), eye_size, eye_color, "EyeL")
	var eye_r := _box(Vector3( 0.07 * s, head_y + 0.02 * s, eye_z), eye_size, eye_color, "EyeR")
	root.add_child(eye_l)
	root.add_child(eye_r)

	# mouth (subtle dark line)
	var mouth := _box(Vector3(0, head_y - 0.06 * s, eye_z), Vector3(0.10, 0.02, 0.02) * s, Color(0.25, 0.05, 0.05), "Mouth")
	root.add_child(mouth)

	return root

static func _box(pos: Vector3, size: Vector3, col: Color, name: String) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = name
	var box := BoxMesh.new()
	box.size = size
	mi.mesh = box
	var mat := StandardMaterial3D.new()
	mat.albedo_color = col
	mat.roughness = 0.85
	mi.material_override = mat
	mi.position = pos
	return mi
