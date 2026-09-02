extends SceneTree

## Headless parse check: load key scripts and report failures.

func _initialize() -> void:
	var paths := [
		"res://src/core/loot_service.gd",
		"res://src/world/mob.gd",
		"res://src/world/player.gd",
		"res://src/world/game_world.gd",
		"res://src/world/chest.gd",
		"res://src/world/hub.gd",
		"res://src/data/game_state.gd",
		"res://src/data/content_db.gd",
		"res://src/data/alchemy_service.gd",
		"res://src/data/market_service.gd",
		"res://src/data/save_service.gd",
		"res://src/ui/hud.gd",
		"res://src/ui/alchemy.gd",
		"res://src/ui/market.gd",
		"res://src/ui/equipment.gd",
		"res://src/ui/stage_select.gd",
		"res://src/ui/float_text_manager.gd",
		"res://src/ui/minimap.gd",
		"res://src/core/stage.gd",
		"res://src/core/equipment_loadout.gd",
	]
	var failed := 0
	for path in paths:
		var err := ResourceLoader.load_threaded_request(path)
		# Direct load surfaces parse errors to stderr
		var res = load(path)
		if res == null:
			printerr("FAIL load: ", path)
			failed += 1
		else:
			print("OK: ", path)
	print("done failed=", failed)
	quit(failed)
