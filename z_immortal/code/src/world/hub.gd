extends Control
@onready var _portrait: TextureRect = $PortraitFrame/Portrait
@onready var _hero: TextureRect = $HeroSprite
@onready var _tagline: Label = $Tagline
@onready var _status: Label = $StatusPanel/Status
@onready var _lore: Label = $LorePanel/Lore
@onready var _bag_hint: Label = $BagHint
@onready var _equip_hint: Label = $EquipHint

func _ready() -> void:
	var portrait := load("res://assets/portraits/player.png")
	if portrait:
		_portrait.texture = portrait
	var hero := load("res://assets/characters/player_clear.png")
	if hero:
		_hero.texture = hero
	_tagline.text = ContentDB.lore_tagline()
	var intro := ContentDB.lore_intro()
	if intro.length() > 90:
		intro = intro.substr(0, 90) + "…"
	_lore.text = intro
	_refresh_status()
	EventBus.cultivation_broke_through.connect(func(_id): _refresh_status())
	EventBus.attack_gained.connect(func(_a, _t): _refresh_status())
	EventBus.item_gained.connect(func(_i, _a, _r): _refresh_status())
	EventBus.market_trade.connect(func(_a, _i, _q, _p): _refresh_status())
	EventBus.equipment_changed.connect(_refresh_status)

func _refresh_status() -> void:
	var c := GameState.cultivation
	var realm := ContentDB.realms.get_realm(c.attack_realm_id)
	var realm_name := realm.display_name if realm else c.attack_realm_id
	var bonus := GameState.equipment_bonus()
	_status.text = "%s · %s\n攻 %d(+%d)  防 %d(+%d)  智 %d阶\n灵石 %d  ·  已解锁第 %d 层" % [
		GameState.realm_band_name(),
		realm_name,
		c.attack,
		int(bonus.get("attack", 0)),
		c.defense,
		int(bonus.get("defense", 0)),
		c.wisdom_rank,
		GameState.spirit_stones,
		GameState.unlocked_order,
	]
	var eq := GameState.equipment
	_equip_hint.text = "装备  武:%s  甲:%s  饰:%s" % [
		_name(eq.weapon),
		_name(eq.armor),
		_name(eq.accessory),
	]
	var counts := GameState.inventory.all_counts()
	if counts.is_empty():
		_bag_hint.text = "背包：空（战斗可掉宝）"
	else:
		var parts: PackedStringArray = []
		for item_id in counts.keys():
			var item := ContentDB.get_item(str(item_id))
			var name := item.display_name if item else str(item_id)
			parts.append("%s×%d" % [name, int(counts[item_id])])
		_bag_hint.text = "背包：" + ", ".join(parts)

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
