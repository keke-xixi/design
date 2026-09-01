extends CanvasLayer

@onready var _realm_label: Label = $Root/Panel/RealmLabel
@onready var _qi_label: Label = $Root/Panel/QiLabel
@onready var _hint_label: Label = $Root/Panel/HintLabel


func _ready() -> void:
	EventBus.cultivation_broke_through.connect(_on_broke_through)
	EventBus.qi_gained.connect(_on_qi_gained)
	_refresh()


func _on_broke_through(_new_realm_id: String) -> void:
	_refresh()


func _on_qi_gained(_amount: int, _total: int) -> void:
	_refresh()


func _refresh() -> void:
	var realm := ContentDB.realms.get_realm(GameState.cultivation.realm_id)
	var realm_name := realm.display_name if realm else GameState.cultivation.realm_id
	_realm_label.text = "境界  %s" % realm_name
	var next_realm := ContentDB.realms.get_next(GameState.cultivation.realm_id)
	if next_realm:
		_qi_label.text = "灵气  %d / %d" % [GameState.cultivation.qi, next_realm.breakthrough_qi]
	else:
		_qi_label.text = "灵气  %d（已至样例顶峰）" % GameState.cultivation.qi
	_hint_label.text = "WASD 移动    J 吐纳    K 突破"
