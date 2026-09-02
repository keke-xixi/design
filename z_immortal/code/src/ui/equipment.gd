extends Control

@onready var _weapon: Label = $Panel/Slots/Weapon/Value
@onready var _armor: Label = $Panel/Slots/Armor/Value
@onready var _accessory: Label = $Panel/Slots/Accessory/Value
@onready var _bonus: Label = $Panel/Bonus
@onready var _bag: VBoxContainer = $Panel/BagScroll/BagList
@onready var _status: Label = $Panel/Status

func _ready() -> void:
	_refresh()
	EventBus.equipment_changed.connect(_refresh)

func _refresh() -> void:
	_weapon.text = _slot_text("weapon")
	_armor.text = _slot_text("armor")
	_accessory.text = _slot_text("accessory")
	var b := GameState.equipment_bonus()
	_bonus.text = "加成  攻+%d  防+%d  血+%d  速+%d%%" % [
		int(b.get("attack", 0)),
		int(b.get("defense", 0)),
		int(b.get("hp", 0)),
		int(float(b.get("speed_pct", 0.0)) * 100.0),
	]
	_build_bag()

func _slot_text(slot: String) -> String:
	var item_id := GameState.equipment.get_slot(slot)
	if item_id.is_empty():
		return "（空）"
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
		lbl.text = "%s x%d" % [item.display_name, qty]
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(lbl)
		var btn := Button.new()
		btn.text = "穿戴"
		btn.pressed.connect(func() -> void: _equip(str(item_id)))
		row.add_child(btn)
		_bag.add_child(row)

func _equip(item_id: String) -> void:
	if GameState.equip_item(item_id):
		_status.text = "已装备 %s" % item_id
		_refresh()
	else:
		_status.text = "无法装备"

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
