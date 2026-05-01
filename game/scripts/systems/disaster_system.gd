extends Node
## DisasterSystem — applies damage/blessings in a radius around a target point.
## Other systems and the HUD listen to its signals.

signal power_cast(power_id: String, position: Vector3)
signal damage_dealt(position: Vector3, radius: float, amount: float)
signal heal_dealt(position: Vector3, radius: float, amount: float)
signal log_message(text: String)

func cast_disaster(data: Dictionary, world_pos: Vector3) -> void:
	var radius := float(data.get("radius", 5.0))
	var damage := float(data.get("damage", 10.0))
	var fear   := float(data.get("fear_increase", 0.0))
	emit_signal("power_cast", String(data.get("id", "")), world_pos)
	emit_signal("damage_dealt", world_pos, radius, damage)
	if fear > 0.0 and has_node("/root/FaithSystem"):
		FaithSystem.add_fear(fear)

func cast_blessing(data: Dictionary, world_pos: Vector3) -> void:
	var radius := float(data.get("radius", 5.0))
	emit_signal("power_cast", String(data.get("id", "")), world_pos)
	if data.has("heal"):
		emit_signal("heal_dealt", world_pos, radius, float(data["heal"]))
	if data.has("prosperity_delta") and has_node("/root/EconomySystem"):
		EconomySystem.add(float(data["prosperity_delta"]))
	if data.has("fear_delta") and has_node("/root/FaithSystem"):
		FaithSystem.add_fear(float(data["fear_delta"]))

func log(text: String) -> void:
	emit_signal("log_message", text)
