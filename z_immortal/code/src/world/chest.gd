extends Area2D

var _opened := false
var _loot: Array = []

func setup(pos: Vector2, loot: Array) -> void:
	global_position = pos
	_loot = loot if typeof(loot) == TYPE_ARRAY else []

func _ready() -> void:
	add_to_group("chests")
	collision_layer = 0
	collision_mask = 2
	monitoring = false
	monitorable = false
	call_deferred("_enable_sensing")
	$Visual.color = Color(0.85, 0.72, 0.35, 0.95)

func _enable_sensing() -> void:
	set_deferred("monitoring", true)

func _physics_process(_delta: float) -> void:
	if _opened:
		return
	_pulse_visual()
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		return
	if global_position.distance_to(player.global_position) < 28.0:
		_open(player)

func _pulse_visual() -> void:
	var s := 1.0 + sin(Time.get_ticks_msec() * 0.005) * 0.06
	$Visual.scale = Vector2(s, s)

func _open(_player: Node2D) -> void:
	if _opened:
		return
	_opened = true
	_burst_open()
	var parent := get_tree().get_first_node_in_group("pickups")
	for i in _loot.size():
		var raw: Variant = _loot[i]
		if typeof(raw) != TYPE_DICTIONARY:
			continue
		var item_id := str(raw.get("item_id", ""))
		var amount := int(raw.get("amount", 1))
		if item_id.is_empty() or amount <= 0:
			continue
		if item_id == "spirit_stones":
			continue
		if parent:
			var pickup := preload("res://scenes/world/item_pickup.tscn").instantiate()
			parent.add_child(pickup)
			pickup.global_position = global_position + Vector2(i * 8 - 4, -6)
			if pickup.has_method("setup"):
				pickup.setup(item_id, amount)
		else:
			GameState.grant_item(item_id, amount)
	var stones := _loot_stones()
	if stones > 0:
		GameState.add_spirit_stones(stones)
	EventBus.chest_opened.emit(global_position)
	if SfxService:
		SfxService.play_pickup()
	FloatTextManager.show_message(global_position + Vector2(0, -18), "宝", Color(1.0, 0.88, 0.45))
	set_deferred("monitoring", false)
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.25)
	tw.tween_callback(queue_free)

func _burst_open() -> void:
	if has_node("Lid"):
		var lid := $Lid
		var tw := create_tween()
		tw.tween_property(lid, "position:y", lid.position.y - 10.0, 0.12)
		tw.parallel().tween_property(lid, "modulate:a", 0.0, 0.18)
	if has_node("Glow"):
		$Glow.color = Color(1.0, 0.92, 0.55, 0.45)
	var ring := Line2D.new()
	ring.width = 2.0
	ring.default_color = Color(1.0, 0.85, 0.4, 0.8)
	ring.z_index = 8
	for i in 21:
		var a := TAU * float(i) / 20.0
		ring.add_point(Vector2(cos(a), sin(a)) * 12.0)
	add_child(ring)
	var tw2 := ring.create_tween()
	tw2.tween_property(ring, "scale", Vector2(2.2, 2.2), 0.2)
	tw2.parallel().tween_property(ring, "modulate:a", 0.0, 0.2)
	tw2.tween_callback(ring.queue_free)

func _loot_stones() -> int:
	for raw in _loot:
		if typeof(raw) == TYPE_DICTIONARY and str(raw.get("item_id", "")) == "spirit_stones":
			return int(raw.get("amount", 0))
	return 0
