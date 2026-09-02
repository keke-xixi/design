extends Area2D

var item_id: String = ""
var amount: int = 1
var _pulse := 0.0
var _visual: Polygon2D


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	monitoring = true
	monitorable = false
	_visual = $Visual
	_apply_rarity_visual()


func setup(id: String, qty: int) -> void:
	item_id = id
	amount = maxi(qty, 1)
	_apply_rarity_visual()


func _apply_rarity_visual() -> void:
	var item := ContentDB.get_item(item_id)
	var rarity := item.rarity if item else "common"
	var color := LootService.rarity_color(rarity)
	_visual.color = Color(color.r, color.g, color.b, 0.95)
	scale = Vector2(1.15, 1.15) if rarity in ["rare", "epic", "legendary"] else Vector2.ONE


func _physics_process(delta: float) -> void:
	_pulse += delta * (8.0 if _is_rare() else 5.0)
	var s := 1.0 + sin(_pulse) * (0.18 if _is_rare() else 0.1)
	scale = Vector2(s, s) * (1.15 if _is_rare() else 1.0)
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		return
	var magnet := float(ContentDB.section("combat").get("item_magnet", 72))
	var dist := global_position.distance_to(player.global_position)
	if dist < magnet:
		global_position = global_position.move_toward(player.global_position, 260.0 * delta)
	if dist < 16.0:
		GameState.grant_item(item_id, amount)
		queue_free()


func _is_rare() -> bool:
	var item := ContentDB.get_item(item_id)
	return item != null and item.rarity in ["rare", "epic", "legendary"]
