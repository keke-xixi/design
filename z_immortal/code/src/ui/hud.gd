extends CanvasLayer

const _DefenseBands := preload("res://src/core/defense_bands.gd")

@onready var _realm_label: Label = $Root/Panel/RealmLabel
@onready var _attack_label: Label = $Root/Panel/AttackLabel
@onready var _wisdom_label: Label = $Root/Panel/WisdomLabel
@onready var _defense_label: Label = $Root/Panel/DefenseLabel
@onready var _hint_label: Label = $Root/Panel/HintLabel


func _ready() -> void:
	EventBus.cultivation_broke_through.connect(_on_broke_through)
	EventBus.attack_gained.connect(_on_attack_gained)
	_refresh()


func _on_broke_through(_new_realm_id: String) -> void:
	_refresh()


func _on_attack_gained(_amount: int, _total: int) -> void:
	_refresh()


func _refresh() -> void:
	var c := GameState.cultivation
	var realm := ContentDB.realms.get_realm(c.attack_realm_id)
	var realm_name := realm.display_name if realm else c.attack_realm_id
	_realm_label.text = "攻境  %s" % realm_name
	var next_realm := ContentDB.realms.get_next(c.attack_realm_id)
	if next_realm:
		var need := int(ContentDB.breakthrough_costs().get(next_realm.id, 0))
		_attack_label.text = "攻    %d / %d（下一境 %s）" % [c.attack, need, next_realm.display_name]
	else:
		_attack_label.text = "攻    %d（已至攻境顶峰）" % c.attack
	_wisdom_label.text = "智    %d 阶" % c.wisdom_rank
	var def_name: String = _DefenseBands.name_for(c.defense, ContentDB.section("defense").get("bands", []))
	if def_name.is_empty():
		_defense_label.text = "防    %d" % c.defense
	else:
		_defense_label.text = "防    %d（%s）" % [c.defense, def_name]
	_hint_label.text = "WASD 移动    J 吐纳    K 突破"
