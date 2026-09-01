extends CanvasLayer

const _DefenseBands := preload("res://src/core/defense_bands.gd")

@onready var _stage_label: Label = $Root/Panel/StageLabel
@onready var _hp_label: Label = $Root/Panel/HpLabel
@onready var _kill_label: Label = $Root/Panel/KillLabel
@onready var _realm_label: Label = $Root/Panel/RealmLabel
@onready var _attack_label: Label = $Root/Panel/AttackLabel
@onready var _wisdom_label: Label = $Root/Panel/WisdomLabel
@onready var _defense_label: Label = $Root/Panel/DefenseLabel
@onready var _hint_label: Label = $Root/Panel/HintLabel
@onready var _portrait: TextureRect = $Root/Portrait


func _ready() -> void:
	EventBus.cultivation_broke_through.connect(_on_broke)
	EventBus.attack_gained.connect(_on_attack)
	EventBus.enemy_killed.connect(_on_kill)
	EventBus.player_hp_changed.connect(_on_hp)
	EventBus.player_died.connect(_on_any_noargs)
	EventBus.stage_changed.connect(_on_stage)
	EventBus.stage_cleared.connect(_on_stage)
	var tex := load("res://assets/portraits/player.png")
	if tex and _portrait:
		_portrait.texture = tex
	_refresh()


func _on_broke(_new_realm_id: String) -> void:
	_refresh()


func _on_attack(_amount: int, _total: int) -> void:
	_refresh()


func _on_kill(_enemy_id: String, _stage_id: String) -> void:
	_refresh()


func _on_hp(_hp: int, _max_hp: int) -> void:
	_refresh()


func _on_any_noargs() -> void:
	_refresh()


func _on_stage(_stage_id: String) -> void:
	_refresh()


func _refresh() -> void:
	var c := GameState.cultivation
	var stage := GameState.current_stage()
	var stage_name := stage.display_name if stage else GameState.stage_id
	_stage_label.text = "关卡  %s" % stage_name
	_hp_label.text = "气血  %d / %d" % [GameState.hp, GameState.max_hp]
	if stage:
		_kill_label.text = "杀敌  %d / %d" % [GameState.stage_kills(), stage.kill_target]
	else:
		_kill_label.text = "杀敌  %d" % GameState.stage_kills()
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
	if GameState.dead:
		_hint_label.text = "已阵亡    R 重生    Esc 返回选关"
	else:
		_hint_label.text = "WASD 移动    自动攻击    J 吐纳    K 突破    Esc 返回选关"
