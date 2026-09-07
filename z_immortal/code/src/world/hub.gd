extends Control

const _UiStyle := preload("res://src/ui/ui_style.gd")

@onready var _hero: TextureRect = $HeroBleed
@onready var _tagline: Label = $Tagline
@onready var _status: Label = $StatusStrip
@onready var _equip_hint: Label = $Footer/EquipHint
@onready var _challenge: Button = $ChallengeButton

func _ready() -> void:
	if has_node("MenuFrame"):
		_UiStyle.apply_panel($MenuFrame, Color(0.55, 0.78, 0.88, 0.55))
	_UiStyle.apply_primary_button(_challenge)
	_UiStyle.apply_button($SubNav/EquipmentButton)
	_UiStyle.apply_button($SubNav/AlchemyButton)
	_UiStyle.apply_button($SubNav/MarketButton)
	_UiStyle.apply_button($Footer/QuitButton)
	_load_hero_art()
	var tag := ContentDB.lore_tagline()
	_tagline.text = tag if tag.length() <= 18 else tag.substr(0, 18)
	_refresh_status()
	EventBus.cultivation_broke_through.connect(func(_id): _refresh_status())
	EventBus.attack_gained.connect(func(_a, _t): _refresh_status())
	EventBus.item_gained.connect(func(_i, _a, _r): _refresh_status())
	EventBus.market_trade.connect(func(_a, _i, _q, _p): _refresh_status())
	EventBus.equipment_changed.connect(_refresh_status)

func _load_hero_art() -> void:
	var preferred := "res://assets/characters/hub_hero.png"
	var fallback := "res://assets/characters/player_clear.png"
	var path := preferred if ResourceLoader.exists(preferred) else fallback
	var tex: Texture2D = load(path)
	if tex:
		_hero.texture = tex

func _process(_delta: float) -> void:
	if _challenge == null:
		return
	var t := Time.get_ticks_msec() * 0.002
	var glow := 1.0 + 0.07 * sin(t)
	_challenge.modulate = Color(glow, glow * 0.97, glow * 0.9)
	# Soft hero float.
	if _hero:
		_hero.position.y = -18.0 + sin(t * 0.8) * 4.0
	if has_node("Brand"):
		$Brand.modulate = Color(1.0, 1.0, 1.0, 0.92 + 0.08 * sin(t * 0.6))

func _refresh_status() -> void:
	var c := GameState.cultivation
	var realm := ContentDB.realms.get_realm(c.attack_realm_id)
	var realm_name := realm.display_name if realm else c.attack_realm_id
	var bonus := GameState.equipment_bonus()
	_status.text = "%s  ·  攻 %d  ·  石 %d" % [
		realm_name,
		c.attack + int(bonus.get("attack", 0)),
		GameState.spirit_stones,
	]
	var next_stage := _recommended_stage()
	_challenge.text = "进入 · %s" % next_stage.display_name if next_stage else "进入战场"
	if next_stage:
		_challenge.tooltip_text = "推荐挑战：%s" % next_stage.display_name
	var eq := GameState.equipment
	_equip_hint.text = "武 %s · 甲 %s · 饰 %s" % [_name(eq.weapon), _name(eq.armor), _name(eq.accessory)]

func _recommended_stage() -> StageDef:
	var best: StageDef = null
	for stage in ContentDB.stages.all_stages():
		if stage == null or not GameState.can_enter(stage):
			continue
		if best == null or stage.order > best.order:
			best = stage
	return best

func _name(item_id: String) -> String:
	if item_id.is_empty():
		return "—"
	var item := ContentDB.get_item(item_id)
	return item.display_name if item else item_id

func _on_challenge_pressed() -> void:
	SceneManager.go_stage_select()

func _on_market_pressed() -> void:
	SceneManager.go_market()

func _on_equipment_pressed() -> void:
	SceneManager.go_equipment()

func _on_alchemy_pressed() -> void:
	SceneManager.go_alchemy()

func _on_quit_pressed() -> void:
	SaveService.save_game()
	get_tree().quit()
