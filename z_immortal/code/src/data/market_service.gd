extends Node

## Mock trading platform: NPC listings + player buy/sell/list. Persisted in save.

const LISTING_PATH := "user://market_listings.json"

var npc_listings: Array = []
var player_listings: Array = []


func _ready() -> void:
	npc_listings = ContentDB.market_npc_listings()
	_load_player_listings()


func refresh_npc_listings() -> void:
	npc_listings = ContentDB.market_npc_listings()


func _load_player_listings() -> void:
	if not FileAccess.file_exists(LISTING_PATH):
		player_listings = []
		return
	var file := FileAccess.open(LISTING_PATH, FileAccess.READ)
	if file == null:
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	player_listings = parsed if typeof(parsed) == TYPE_ARRAY else []


func save_player_listings() -> void:
	var file := FileAccess.open(LISTING_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(player_listings, "\t"))


func all_listings() -> Array:
	var out: Array = []
	for raw in npc_listings:
		if typeof(raw) == TYPE_DICTIONARY:
			out.append(raw.duplicate())
	for raw in player_listings:
		if typeof(raw) == TYPE_DICTIONARY:
			var row := raw.duplicate()
			row["seller"] = "你"
			out.append(row)
	return out


func buy_listing(listing_id: String) -> Dictionary:
	for i in npc_listings.size():
		var row: Dictionary = npc_listings[i]
		if str(row.get("id", "")) != listing_id:
			continue
		return _complete_buy(row, true, i)
	for i in player_listings.size():
		var row: Dictionary = player_listings[i]
		if str(row.get("id", "")) != listing_id:
			continue
		return _complete_buy(row, false, i)
	return { "ok": false, "reason": "not_found" }


func _complete_buy(row: Dictionary, is_npc: bool, index: int) -> Dictionary:
	var price := int(row.get("price", 0))
	var item_id := str(row.get("item_id", ""))
	var qty := int(row.get("qty", 1))
	if item_id.is_empty() or qty <= 0:
		return { "ok": false, "reason": "invalid" }
	if GameState.spirit_stones < price:
		return { "ok": false, "reason": "no_money", "need": price }
	GameState.spirit_stones -= price
	GameState.grant_item(item_id, qty, false)
	if is_npc:
		npc_listings.remove_at(index)
	else:
		player_listings.remove_at(index)
		save_player_listings()
	SaveService.save_game()
	EventBus.market_trade.emit("buy", item_id, qty, price)
	return { "ok": true, "item_id": item_id, "qty": qty, "price": price }


func list_item(item_id: String, qty: int, price: int) -> Dictionary:
	if qty <= 0 or price <= 0:
		return { "ok": false, "reason": "invalid" }
	var item := ContentDB.get_item(item_id)
	if item == null or not item.tradeable:
		return { "ok": false, "reason": "not_tradeable" }
	if GameState.inventory.count_of(item_id) < qty:
		return { "ok": false, "reason": "not_enough" }
	GameState.inventory.remove(item_id, qty)
	var listing := {
		"id": "pl_%d_%d" % [Time.get_ticks_msec(), randi() % 10000],
		"item_id": item_id,
		"qty": qty,
		"price": price,
		"seller": "你",
	}
	player_listings.append(listing)
	save_player_listings()
	SaveService.save_game()
	EventBus.market_trade.emit("list", item_id, qty, price)
	return { "ok": true, "listing_id": listing["id"] }


func sell_to_npc(item_id: String, qty: int) -> Dictionary:
	if qty <= 0:
		return { "ok": false, "reason": "invalid" }
	var item := ContentDB.get_item(item_id)
	if item == null or not item.tradeable:
		return { "ok": false, "reason": "not_tradeable" }
	if GameState.inventory.count_of(item_id) < qty:
		return { "ok": false, "reason": "not_enough" }
	var payout := item.value * qty
	GameState.inventory.remove(item_id, qty)
	GameState.spirit_stones += payout
	SaveService.save_game()
	EventBus.market_trade.emit("sell", item_id, qty, payout)
	return { "ok": true, "payout": payout }
