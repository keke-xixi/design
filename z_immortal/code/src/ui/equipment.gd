extends Control

const _UiStyle := preload("res://src/ui/ui_style.gd")

@onready var _weapon: Label = $Panel/Slots/Weapon/V/Value
@onready var _armor: Label = $Panel/Slots/Armor/V/Value
@onready var _accessory: Label = $Panel/Slots/Accessory/V/Value
@onready var _bonus: Label = $Panel/Bonus
@onready var _bag: VBoxContainer = $Panel/BagScroll/BagList
@onready var _status: Label = $Panel/Status
@onready var _hero: TextureRect = get_node_or_null("Hero")

func _ready() -> void:
	_UiStyle.apply_button($Panel/Header/BackButton)
	_UiStyle.apply_panel($Panel/Slots/Weapon)
	_UiStyle.apply_panel($Panel/Slots/Armor)
	_UiStyle.apply_panel($Panel/Slots/Accessory)
	_UiStyle.apply_button($Panel/Slots/Weapon/V/Unequip)
	_UiStyle.apply_button($Panel/Slots/Armor/V/Unequip)
	_UiStyle.apply_button($Panel/Slots/Accessory/V/Unequip)
	if _hero and not ResourceLoader.exists("res://assets/characters/hub_hero.png"):
		_hero.texture = load("res://assets/characters/player_clear.png")
	_refresh()
	EventBus.equipment_changed.connect(_refresh)

func _process(_delta: float) -> void:
	if _hero:
		var t := Time.get_ticks_msec() * 0.0018
		_hero.position.y = 40.0 + sin(t) * 3.0

func _refresh() -> void:
	_weapon.text = _slot_text("weapon")
	_armor.text = _slot_text("armor")
	_accessory.text = _slot_text("accessory")
	var b := GameState.equipment_bonus()
	_bonus.text = "攻+%d  防+%d  血+%d  速+%d%%" % [
		int(b.get("attack", 0)),
		int(b.get("defense", 0)),
		int(b.get("hp", 0)),
		int(float(b.get("speed_pct", 0.0)) * 100.0),
	]
	_build_bag()

func _slot_text(slot: String) -> String:
	var item_id := GameState.equipment.get_slot(slot)
	if item_id.is_empty():
		return "—"
	var item := ContentDB.get_item(item_id)
	return item.display_name if item else item_id

func _build_bag() -> void:
	while _bag.get_child_count() > 0:
		var c := _bag.get_child(0)
		_bag.remove_child(c)
		c.free()
	for item_id in GameState.inventory.all_counts().keys():
		var item := ContentDB.get_item(str(item_id))
		if item == null or item.equip_slot.is_empty():
			continue
		var qty := GameState.inventory.count_of(str(item_id))
		var row := HBoxContainer.new()
		var lbl := Label.new()
		lbl.text = "%s×%d" % [item.display_name, qty]
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lbl.add_theme_font_size_override("font_size", 11)
		lbl.add_theme_color_override("font_color", LootService.rarity_color(item.rarity))
		row.add_child(lbl)
		var btn := Button.new()
		btn.text = "穿"
		_UiStyle.apply_button(btn)
		btn.pressed.connect(func() -> void: _equip(str(item_id)))
		row.add_child(btn)
		var wrap := PanelContainer.new()
		_UiStyle.apply_panel(wrap, Color(0.55, 0.78, 0.88, 0.35))
		wrap.add_child(row)
		_bag.add_child(wrap)

func _equip(item_id: String) -> void:
	if GameState.equip_item(item_id):
		_status.text = "已穿戴"
		_refresh()
	else:
		_status.text = "失败"

func _on_unequip_weapon() -> void:
	_unequip("weapon")

func _on_unequip_armor() -> void:
	_unequip("armor")

func _on_unequip_accessory() -> void:
	_unequip("accessory")

func _unequip(slot: String) -> void:
	GameState.unequip_slot(slot)
	_status.text = "已卸下"
	_refresh()

func _on_back_pressed() -> void:
	SceneManager.go_hub()
