extends SceneTree

## Headless smoke test. Uses get_node for autoloads ( -s compile may not see them).

func _initialize() -> void:
	await process_frame
	var failed := 0
	failed += _check_autoloads()
	if failed > 0:
		print("SMOKE done failed=", failed)
		quit(failed)
		return
	failed += _check_content()
	failed += _check_market_logic()
	failed += _check_alchemy_logic()
	failed += _check_equipment_logic()
	failed += await _check_scenes()
	print("SMOKE done failed=", failed)
	quit(failed)


func _n(name: String) -> Node:
	return root.get_node_or_null("/root/%s" % name)


func _check_autoloads() -> int:
	var names := [
		"EventBus", "ContentDB", "GameState", "SteamService", "SceneManager",
		"SaveService", "FloatTextManager", "LootService", "MarketService", "AlchemyService", "SfxService",
	]
	var bad := 0
	for n in names:
		if _n(n) == null:
			printerr("MISSING autoload: ", n)
			bad += 1
		else:
			print("autoload OK: ", n)
	return bad


func _check_content() -> int:
	var db := _n("ContentDB")
	if db.call("get_stage", "sect") == null:
		printerr("missing stage sect")
		return 1
	if db.call("get_item", "spirit_grass") == null:
		printerr("missing item spirit_grass")
		return 1
	var recipes: Array = db.call("alchemy_recipes")
	if recipes.is_empty():
		printerr("empty alchemy recipes")
		return 1
	var listings: Array = db.call("market_npc_listings")
	if listings.is_empty():
		printerr("empty market listings")
		return 1
	print("content OK")
	return 0


func _check_market_logic() -> int:
	var market := _n("MarketService")
	var gs := _n("GameState")
	market.call("refresh_npc_listings")
	var before: int = gs.get("spirit_stones")
	gs.call("grant_item", "spirit_grass", 3, false)
	var sell: Dictionary = market.call("sell_to_npc", "spirit_grass", 1)
	if not bool(sell.get("ok", false)):
		printerr("sell failed ", sell)
		return 1
	if int(gs.get("spirit_stones")) <= before:
		printerr("sell did not increase stones")
		return 1
	print("market logic OK stones=", gs.get("spirit_stones"))
	return 0


func _check_alchemy_logic() -> int:
	var alchemy := _n("AlchemyService")
	var gs := _n("GameState")
	gs.call("grant_item", "spirit_grass", 10, false)
	gs.set("spirit_stones", maxi(int(gs.get("spirit_stones")), 50))
	var craft: Dictionary = alchemy.call("craft", "basic_pill")
	if not bool(craft.get("ok", false)):
		printerr("craft failed ", craft)
		return 1
	var pull: Dictionary = alchemy.call("gacha_pull", "white_pill_gacha")
	if not bool(pull.get("ok", false)):
		printerr("gacha failed ", pull)
		return 1
	print("alchemy OK got=", pull.get("item_id", ""))
	return 0


func _check_equipment_logic() -> int:
	var gs := _n("GameState")
	gs.call("grant_item", "wooden_sword", 1, false)
	if not bool(gs.call("equip_item", "wooden_sword")):
		printerr("equip wooden_sword failed")
		return 1
	var b: Dictionary = gs.call("equipment_bonus")
	if int(b.get("attack", 0)) < 1:
		printerr("equip bonus missing ", b)
		return 1
	print("equipment OK bonus=", b)
	return 0


func _check_scenes() -> int:
	var scenes := [
		"res://scenes/world/hub.tscn",
		"res://scenes/world/stage_select.tscn",
		"res://scenes/world/market.tscn",
		"res://scenes/world/equipment.tscn",
		"res://scenes/world/alchemy.tscn",
		"res://scenes/world/combat.tscn",
	]
	var bad := 0
	for path in scenes:
		var packed: PackedScene = load(path)
		if packed == null:
			printerr("cannot load scene ", path)
			bad += 1
			continue
		var node := packed.instantiate()
		root.add_child(node)
		await process_frame
		await process_frame
		print("scene OK: ", path)
		node.queue_free()
		await process_frame
	return bad
