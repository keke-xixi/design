extends Node

## Spawns floating combat text at world positions.

const _FloatTextScene := preload("res://scenes/ui/float_text.tscn")

var _layer: CanvasLayer

func _ready() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 10
	add_child(_layer)
	EventBus.damage_dealt.connect(_on_damage)
	EventBus.attack_gained.connect(_on_attack)
	EventBus.cultivation_broke_through.connect(_on_breakthrough)
	EventBus.mystic_crossed.connect(_on_mystic)
	EventBus.cultivation_stat_gained.connect(_on_stat_gained)
	EventBus.combo_milestone.connect(_on_combo)
	EventBus.item_gained.connect(_on_item_gained)

func _on_item_gained(item_id: String, amount: int, rarity: String) -> void:
	# Early runs celebrate common drops too (throttled); later only uncommon+.
	var early := GameState.stage_id in ["sect", "country"]
	if rarity not in ["uncommon", "rare", "epic", "legendary"]:
		if not early:
			return
		# Skip most grass spam; still show ~35% so bags feel alive.
		if rarity == "common" and randf() > 0.35:
			return
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		return
	var item := ContentDB.get_item(item_id)
	var name := item.display_name if item else item_id
	_spawn(player.global_position + Vector2(0, -20), "%s×%d" % [name, amount], LootService.rarity_color(rarity))

func _on_mystic() -> void:
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player:
		_spawn(player.global_position + Vector2(0, -48), "通玄", Color(0.65, 0.85, 1.0))

func _on_stat_gained(stat: String, value: int) -> void:
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		return
	var label := "悟性↑%d" % value if stat == "wisdom" else "体魄↑%d" % value
	_spawn(player.global_position + Vector2(0, -32), label, Color(0.75, 0.92, 1.0))
	# Extra beat so growth reads as a power spike.
	_spawn(player.global_position + Vector2(0, -48), "修为精进", Color(0.95, 0.88, 0.55))

func _on_combo(count: int) -> void:
	# Float on every milestone — HUD carries live count between pops.
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		return
	var col := Color(1.0, 0.82, 0.45)
	if count == 2:
		# 二连 — sect teal / dynasty gold short cue.
		if GameState.stage_id == "sect":
			col = Color(0.45, 0.98, 0.9)
		elif GameState.stage_id == "country":
			col = Color(1.0, 0.88, 0.42)
		else:
			col = Color(1.0, 0.94, 0.7)
	elif count >= 15:
		col = Color(1.0, 0.5, 0.26)
	elif count >= 8:
		# 疯斩 赤金 — pairs HUD banner / minimap hot rim.
		col = Color(1.0, 0.55, 0.26)
	var label := "二连!" if count == 2 else ("%d连·疯斩!" % count if count == 8 else "%d连!" % count)
	_spawn(player.global_position + Vector2(0, -40), label, col)
	# Stacked slash — dynasty 市斩 / sect 斩; 二连 uses stage color.
	var slash_col := Color(1.0, 0.92, 0.45)
	if count == 2 and GameState.stage_id == "sect":
		slash_col = Color(0.5, 0.98, 0.9)
	elif count == 2 and GameState.stage_id == "country":
		slash_col = Color(1.0, 0.88, 0.42)
	elif count >= 8:
		slash_col = Color(1.0, 0.58, 0.28)
	elif count >= 5:
		slash_col = Color(1.0, 0.86, 0.38)
	var slash_glyph := "市斩" if GameState.stage_id == "country" else "斩"
	_spawn(player.global_position + Vector2(-10, -58), slash_glyph, slash_col)
	if count >= 5:
		_spawn(player.global_position + Vector2(12, -70), slash_glyph, Color(slash_col.r, slash_col.g, slash_col.b, 0.85))
	var per := float(ContentDB.section("combat").get("combo_damage_per_stack", 0.03))
	var bonus_pct := int(round(per * float(count) * 100.0))
	if bonus_pct > 0 and count >= 3:
		_spawn(player.global_position + Vector2(0, -54), "伤+%d%%" % bonus_pct, Color(1.0, 0.9, 0.55))

func _on_damage(pos: Vector2, amount: int, is_player: bool) -> void:
	if is_player:
		# Only show meaningful hits to cut clutter.
		if amount < 3:
			return
		_spawn(pos, str(amount), Color(1.0, 0.45, 0.4))
		return
	# Thin auto-attack spam: skip tiny ticks often.
	if amount < 4 and randf() > 0.45:
		return
	var color := Color(0.85, 0.95, 0.55)
	if GameState.combo >= 10:
		color = Color(1.0, 0.55, 0.28)
	elif GameState.combo >= 6:
		color = Color(1.0, 0.78, 0.35)
	elif GameState.combo >= 3:
		color = Color(0.95, 0.92, 0.55)
	_spawn(pos, str(amount), color)

func _on_attack(gain: int, _total: int) -> void:
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player:
		_spawn(player.global_position + Vector2(0, -24), "+%d攻" % gain, Color(0.55, 0.95, 0.65))

func _on_breakthrough(realm_id: String) -> void:
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		return
	var realm := ContentDB.realms.get_realm(realm_id)
	var name := realm.display_name if realm else realm_id
	_spawn(player.global_position + Vector2(0, -36), name, Color(1.0, 0.88, 0.45))

func show_message(world_pos: Vector2, text: String, color: Color) -> void:
	_spawn(world_pos, text, color)

func _spawn(world_pos: Vector2, text: String, color: Color) -> void:
	var node := _FloatTextScene.instantiate()
	_layer.add_child(node)
	if node.has_method("setup"):
		node.setup(_world_to_canvas(world_pos), text, color)

func _world_to_canvas(world_pos: Vector2) -> Vector2:
	var vp := get_viewport()
	if vp == null:
		return world_pos
	var canvas := vp.get_canvas_transform()
	return canvas * world_pos
