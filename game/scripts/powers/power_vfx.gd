extends Node3D
## PowerVFX — generic, data-driven visual effect spawner for any power.
## Emits a brief light + colored ring + auto-frees itself.

class_name PowerVFX

func play(power_data: Dictionary) -> void:
	var color := Color(String(power_data.get("color", "#ffd166")))
	var radius := float(power_data.get("radius", 4.0))
	var vfx := String(power_data.get("vfx", "lightning"))

	# 1) bright omni light flash
	var light := OmniLight3D.new()
	light.light_color = color
	light.light_energy = 12.0
	light.omni_range = max(radius * 2.0, 6.0)
	light.position.y = 6.0
	add_child(light)

	# 2) ground ring
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = radius * 0.85
	torus.outer_radius = radius
	ring.mesh = torus
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 4.0
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ring.material_override = mat
	ring.position.y = 0.05
	add_child(ring)

	# 3) optional vertical bolt for "lightning"
	if vfx == "lightning":
		var bolt := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.15
		cyl.bottom_radius = 0.4
		cyl.height = 14.0
		bolt.mesh = cyl
		bolt.material_override = mat
		bolt.position.y = 7.0
		add_child(bolt)

	# 4) animate fade & scale
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(ring, "scale", Vector3(1.6, 1.0, 1.6), 0.5)
	tween.tween_property(mat, "albedo_color:a", 0.0, 0.5)
	tween.tween_property(light, "light_energy", 0.0, 0.4)
	tween.chain().tween_callback(Callable(self, "queue_free"))
