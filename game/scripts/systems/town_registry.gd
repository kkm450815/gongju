extends Node
## TownRegistry — central index of all live buildings/NPCs in the town.
## NPCs query it to find homes, workplaces, churches, and where to flee from.

signal building_registered(b)
signal building_unregistered(b)
signal npc_registered(n)
signal npc_unregistered(n)

var buildings: Array = []
var npcs: Array = []

# tag-bucketed lookups (Building references)
var residential: Array = []
var economy: Array = []
var religious: Array = []
var nature: Array = []

# town center (computed from average building position)
var center: Vector3 = Vector3.ZERO

func register_building(b: Variant) -> void:
	buildings.append(b)
	var tags: Array = b.data.get("tags", [])
	if "residential" in tags: residential.append(b)
	if "economy" in tags:     economy.append(b)
	if "religious" in tags or "faith_source" in tags:
		religious.append(b)
	if "nature" in tags:      nature.append(b)
	_recompute_center()
	emit_signal("building_registered", b)

func unregister_building(b: Variant) -> void:
	buildings.erase(b)
	residential.erase(b)
	economy.erase(b)
	religious.erase(b)
	nature.erase(b)
	_recompute_center()
	emit_signal("building_unregistered", b)

func register_npc(n: Variant) -> void:
	npcs.append(n)
	emit_signal("npc_registered", n)

func unregister_npc(n: Variant) -> void:
	npcs.erase(n)
	emit_signal("npc_unregistered", n)

func nearest(arr: Array, pos: Vector3) -> Variant:
	var best: Variant = null
	var best_d: float = INF
	for x in arr:
		if not is_instance_valid(x):
			continue
		var d: float = pos.distance_squared_to(x.global_position)
		if d < best_d:
			best_d = d
			best = x
	return best

func random_in(arr: Array) -> Variant:
	if arr.is_empty():
		return null
	for _i in 6:
		var pick: Variant = arr[randi() % arr.size()]
		if is_instance_valid(pick):
			return pick
	return null

func _recompute_center() -> void:
	if buildings.is_empty():
		center = Vector3.ZERO
		return
	var sum := Vector3.ZERO
	var count := 0
	for b in buildings:
		if is_instance_valid(b):
			sum += b.global_position
			count += 1
	center = sum / max(1, count) if count > 0 else Vector3.ZERO
