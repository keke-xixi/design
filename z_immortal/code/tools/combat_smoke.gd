extends SceneTree

## Combat-focused smoke: drops, pickups, chests, boss kill path.


func _initialize() -> void:
	await process_frame
	var failed := 0
	failed += await _test_item_pickup_order()
	failed += await _test_mob_death_drops()
	failed += await _test_chest_open()
	failed += await _test_combat_scene_kills()
	failed += await _test_escape_scene_change()
	print("COMBAT_SMOKE done failed=", failed)
	quit(failed)


func _n(name: String) -> Node:
	return root.get_node_or_null("/root/%s" % name)


func _test_item_pickup_order() -> int:
	# Reproduce old bug: setup before add_child must not crash.
	var pickup: Node = load("res://scenes/world/item_pickup.tscn").instantiate()
	if pickup.has_method("setup"):
		pickup.call("setup", "wooden_sword", 1)
	root.add_child(pickup)
	await process_frame
	print("pickup setup-before-add OK")
	pickup.queue_free()
	await process_frame
	# Preferred order
	var pickup2: Node = load("res://scenes/world/item_pickup.tscn").instantiate()
	root.add_child(pickup2)
	pickup2.call("setup", "star_shard", 2)
	await process_frame
	print("pickup add-then-setup OK")
	pickup2.queue_free()
	await process_frame
	return 0


func _test_mob_death_drops() -> int:
	var combat: Node = load("res://scenes/world/combat.tscn").instantiate()
	root.add_child(combat)
	await process_frame
	await process_frame
	var gs := _n("GameState")
	gs.call("enter_stage", "sect")
	var enemy = _n("ContentDB").call("get_enemy", "outer_disciple")
	if enemy == null:
		printerr("missing enemy")
		combat.queue_free()
		return 1
	var mob: Node = load("res://scenes/world/mob.tscn").instantiate()
	var mobs := combat.get_node("Mobs")
	mobs.add_child(mob)
	mob.call("setup", enemy)
	mob.set("global_position", Vector2(200, 200))
	# Force many damage hits until dead
	for _i in 40:
		if not is_instance_valid(mob):
			break
		mob.call("take_damage", 50)
		await process_frame
	await process_frame
	await process_frame
	var pickups := combat.get_node("Pickups")
	print("mob death pickups children=", pickups.get_child_count())
	combat.queue_free()
	await process_frame
	print("mob death drops OK")
	return 0


func _test_chest_open() -> int:
	var combat: Node = load("res://scenes/world/combat.tscn").instantiate()
	root.add_child(combat)
	await process_frame
	await process_frame
	var chests := combat.get_node("Chests")
	if chests.get_child_count() == 0:
		printerr("no chests spawned on sect map")
		combat.queue_free()
		return 1
	var chest: Node = chests.get_child(0)
	var player: Node2D = combat.get_node("Player")
	# Move player onto chest
	player.global_position = chest.global_position
	for _i in 10:
		await process_frame
	print("chest open path OK")
	combat.queue_free()
	await process_frame
	return 0


func _test_combat_scene_kills() -> int:
	var combat: Node = load("res://scenes/world/combat.tscn").instantiate()
	root.add_child(combat)
	await process_frame
	_n("GameState").call("enter_stage", "sect")
	await process_frame
	# Spawn and kill several enemies to exercise loot/register_kill/combo
	var enemies := ["outer_disciple", "spirit_hare", "outer_disciple", "spirit_hare", "outer_disciple"]
	for eid in enemies:
		var enemy = _n("ContentDB").call("get_enemy", eid)
		var mob: Node = load("res://scenes/world/mob.tscn").instantiate()
		combat.get_node("Mobs").add_child(mob)
		mob.call("setup", enemy)
		mob.set("global_position", combat.get_node("Player").global_position + Vector2(40, 0))
		# Make elite sometimes
		if mob.has_method("make_elite") and eid == "spirit_hare":
			mob.call("make_elite")
		for _i in 50:
			if not is_instance_valid(mob):
				break
			mob.call("take_damage", 80)
			await process_frame
		await process_frame
	# Trigger boss spawn path via GameState
	_n("EventBus").emit_signal("boss_spawned", "sect_elder")
	await process_frame
	await process_frame
	print("multi-kill + boss spawn OK kills=", _n("GameState").call("stage_kills"))
	combat.queue_free()
	await process_frame
	return 0


func _test_escape_scene_change() -> int:
	# Esc used to crash: go_stage_select freed the player, then get_viewport() was null.
	var combat: Node = load("res://scenes/world/combat.tscn").instantiate()
	root.add_child(combat)
	await process_frame
	var player: Node = combat.get_node("Player")
	if player.has_method("_mark_input_handled"):
		player.call("_mark_input_handled")
	_n("SceneManager").call("go_stage_select")
	# Same frame: player must still be able to touch viewport (deferred change).
	var vp = player.call("get_viewport")
	if vp == null:
		printerr("viewport already null before deferred change")
		return 1
	vp.call("set_input_as_handled")
	await process_frame
	await process_frame
	print("escape scene change OK")
	return 0
