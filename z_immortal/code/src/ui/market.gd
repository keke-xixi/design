extends Control

@onready var _stones: Label = $Panel/Header/Stones
@onready var _list: VBoxContainer = $Panel/Scroll/List
@onready var _bag: VBoxContainer = $Panel/Body/BagPanel/BagVBox/BagList
@onready var _status: Label = $Panel/Status
@onready var _sell_item: OptionButton = $Panel/SellRow/SellItem
@onready var _sell_qty: SpinBox = $Panel/SellRow/SellQty
@onready var _sell_price: SpinBox = $Panel/SellRow/SellPrice


func _ready() -> void:
	MarketService.refresh_npc_listings()
	_refresh_header()
	_build_listings()
	_build_bag()
	_populate_sell_items()
	EventBus.market_trade.connect(func(_a, _i, _q, _p): _refresh_all())
	EventBus.item_gained.connect(func(_i, _a, _r): _refresh_all())


func _refresh_all() -> void:
	_refresh_header()
	_build_listings()
	_build_bag()
	_populate_sell_items()


func _refresh_header() -> void:
	_stones.text = "灵石 %d" % GameState.spirit_stones


func _build_listings() -> void:
	while _list.get_child_count() > 0:
		var c := _list.get_child(0)
		_list.remove_child(c)
		c.free()
	for raw in MarketService.all_listings():
		if typeof(raw) != TYPE_DICTIONARY:
			continue
		_list.add_child(_make_listing_row(raw))


func _make_listing_row(row: Dictionary) -> Control:
	var item_id := str(row.get("item_id", ""))
	var item := ContentDB.get_item(item_id)
	var name := item.display_name if item else item_id
	var qty := int(row.get("qty", 1))
	var price := int(row.get("price", 0))
	var seller := str(row.get("seller", "未知"))
	var listing_id := str(row.get("id", ""))

	var panel := PanelContainer.new()
	var h := HBoxContainer.new()
	panel.add_child(h)

	var info := Label.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.text = "[%s] %s x%d — %d 灵石" % [seller, name, qty, price]
	if item:
		info.add_theme_color_override("font_color", LootService.rarity_color(item.rarity))
	h.add_child(info)

	var btn := Button.new()
	btn.text = "购买"
	btn.pressed.connect(func() -> void: _on_buy(listing_id))
	h.add_child(btn)
	return panel


func _on_buy(listing_id: String) -> void:
	var result := MarketService.buy_listing(listing_id)
	if bool(result.get("ok", false)):
		_status.text = "购入 %s" % str(result.get("item_id", ""))
	else:
		var reason := str(result.get("reason", ""))
		if reason == "no_money":
			_status.text = "灵石不足，需要 %d" % int(result.get("need", 0))
		else:
			_status.text = "购买失败"


func _build_bag() -> void:
	while _bag.get_child_count() > 0:
		var c := _bag.get_child(0)
		_bag.remove_child(c)
		c.free()
	var counts := GameState.inventory.all_counts()
	if counts.is_empty():
		var empty := Label.new()
		empty.text = "背包为空"
		_bag.add_child(empty)
		return
	for item_id in counts.keys():
		var item := ContentDB.get_item(str(item_id))
		var name := item.display_name if item else str(item_id)
		var qty := int(counts[item_id])
		var row := HBoxContainer.new()
		var lbl := Label.new()
		lbl.text = "%s x%d" % [name, qty]
		if item:
			lbl.add_theme_color_override("font_color", LootService.rarity_color(item.rarity))
		row.add_child(lbl)
		if item and item.tradeable:
			var sell_btn := Button.new()
			sell_btn.text = "回收"
			sell_btn.pressed.connect(func() -> void: _on_quick_sell(str(item_id), 1))
			row.add_child(sell_btn)
		_bag.add_child(row)


func _populate_sell_items() -> void:
	_sell_item.clear()
	for item_id in GameState.inventory.all_counts().keys():
		var item := ContentDB.get_item(str(item_id))
		if item and item.tradeable:
			_sell_item.add_item(item.display_name, _sell_item.item_count)
			_sell_item.set_item_metadata(_sell_item.item_count - 1, str(item_id))
	_sell_qty.min_value = 1
	_sell_qty.max_value = 99
	_sell_price.min_value = 1
	_sell_price.max_value = 99999
	_sell_price.value = 50


func _on_quick_sell(item_id: String, qty: int) -> void:
	var result := MarketService.sell_to_npc(item_id, qty)
	if bool(result.get("ok", false)):
		_status.text = "回收得 %d 灵石" % int(result.get("payout", 0))
		_refresh_all()
	else:
		_status.text = "无法回收"


func _on_list_pressed() -> void:
	if _sell_item.item_count <= 0:
		_status.text = "没有可上架物品"
		return
	var idx := _sell_item.selected
	var item_id := str(_sell_item.get_item_metadata(idx))
	var qty := int(_sell_qty.value)
	var price := int(_sell_price.value)
	var result := MarketService.list_item(item_id, qty, price)
	if bool(result.get("ok", false)):
		_status.text = "已上架 %s" % item_id
		_refresh_all()
	else:
		_status.text = "上架失败"


func _on_back_pressed() -> void:
	SceneManager.go_hub()
