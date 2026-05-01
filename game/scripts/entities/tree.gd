extends Node3D
## Tree — small decorative tree with random size + foliage color.

class_name DecorTree

const FOLIAGE_COLORS := [
	Color("#5fb04a"), Color("#7ec06b"), Color("#3f9c40"),
	Color("#c9a86b"),  # autumn
	Color("#bb3a3a"),  # red maple
]
const TRUNK_COLOR := Color("#5d3a26")

func setup(seed_val: int = 0) -> void:
	var rng := RandomNumberGenerator.new()
	if seed_val != 0:
		rng.seed = seed_val
	else:
		rng.randomize()
	var s := rng.randf_range(0.7, 1.3)
	# trunk
	var trunk := MeshInstance3D.new()
	var tcyl := CylinderMesh.new()
	tcyl.top_radius = 0.18 * s
	tcyl.bottom_radius = 0.25 * s
	tcyl.height = 1.2 * s
	trunk.mesh = tcyl
	var tmat := StandardMaterial3D.new()
	tmat.albedo_color = TRUNK_COLOR
	trunk.material_override = tmat
	trunk.position.y = 0.6 * s
	add_child(trunk)
	# foliage — stacked spheres for layered look
	var fcol: Color = FOLIAGE_COLORS[rng.randi() % FOLIAGE_COLORS.size()]
	for i in 3:
		var fol := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = (1.0 - i * 0.15) * 0.9 * s
		sm.height = sm.radius * 2.0
		fol.mesh = sm
		var fm := StandardMaterial3D.new()
		fm.albedo_color = fcol.lerp(Color.WHITE, i * 0.05)
		fol.material_override = fm
		fol.position.y = (1.4 + i * 0.5) * s
		add_child(fol)
