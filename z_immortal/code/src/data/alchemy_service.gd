extends Node

## Crafting and gacha pulls. Recipes in content/alchemy.json.

func craft(recipe_id: String) -> Dictionary:
	var recipe := _find_recipe(recipe_id)
	if recipe.is_empty():
		return { "ok": false, "reason": "no_recipe" }
	var cost := int(recipe.get("cost_stones", 0))
	if GameState.spirit_stones < cost:
		return { "ok": false, "reason": "no_money", "need": cost }
	for raw in recipe.get("inputs", []):
		if typeof(raw) != TYPE_DICTIONARY:
			continue
		var item_id := str(raw.get("item_id", ""))
		var qty := int(raw.get("qty", 1))
		if GameState.inventory.count_of(item_id) < qty:
			return { "ok": false, "reason": "no_material", "item_id": item_id }
	for raw in recipe.get("inputs", []):
		if typeof(raw) != TYPE_DICTIONARY:
			continue
		GameState.inventory.remove(str(raw.get("item_id", "")), int(raw.get("qty", 1)))
	GameState.spirit_stones -= cost
	var out: Variant = recipe.get("output", {})
	if typeof(out) == TYPE_DICTIONARY:
		var item_id := str(out.get("item_id", ""))
		var qty := int(out.get("qty", 1))
		GameState.grant_item(item_id, qty)
		SaveService.save_game()
		EventBus.alchemy_crafted.emit(recipe_id, item_id, qty)
		return { "ok": true, "item_id": item_id, "qty": qty }
	return { "ok": false, "reason": "bad_output" }

func gacha_pull(pool_config_id: String) -> Dictionary:
	var pool := _find_gacha_pool(pool_config_id)
	if pool.is_empty():
		return { "ok": false, "reason": "no_pool" }
	var cost := int(pool.get("cost_stones", 10))
	if GameState.spirit_stones < cost:
		return { "ok": false, "reason": "no_money", "need": cost }
	var rarity_id := str(pool.get("rarity_id", "white"))
	var pool_id := str(pool.get("pool_id", "pill"))
	var entries := ContentDB.gacha_pool_entries(rarity_id, pool_id)
	if entries.is_empty():
		return { "ok": false, "reason": "empty_pool" }
	var rolled: Dictionary = GachaRoller.roll(entries, ContentDB.section("gacha"))
	if rolled.is_empty():
		return { "ok": false, "reason": "roll_failed" }
	var entry_id := str(rolled.get("id", ""))
	var reward := ContentDB.gacha_reward(entry_id)
	var item_id := str(reward.get("item_id", ""))
	var qty := int(reward.get("qty", 1))
	if item_id.is_empty():
		return { "ok": false, "reason": "bad_reward" }
	GameState.spirit_stones -= cost
	GameState.grant_item(item_id, qty)
	SaveService.save_game()
	EventBus.gacha_rolled.emit(pool_config_id, item_id, qty)
	return { "ok": true, "item_id": item_id, "qty": qty, "entry_id": entry_id }

func _find_recipe(recipe_id: String) -> Dictionary:
	for raw in ContentDB.alchemy_recipes():
		if typeof(raw) == TYPE_DICTIONARY and str(raw.get("id", "")) == recipe_id:
			return raw
	return {}

func _find_gacha_pool(pool_id: String) -> Dictionary:
	for raw in ContentDB.alchemy_gacha_pools():
		if typeof(raw) == TYPE_DICTIONARY and str(raw.get("id", "")) == pool_id:
			return raw
	return {}
