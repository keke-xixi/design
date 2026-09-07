extends Area2D

var item_id: String = ""
var amount: int = 1
var _pulse := 0.0
var _visual: Polygon2D


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	monitoring = false
	monitorable = false
	call_deferred("_enable_sensing")
	_ensure_visual()
	_apply_rarity_visual()

func _enable_sensing() -> void:
	set_deferred("monitoring", true)


func setup(id: String, qty: int) -> void:
	item_id = id
	amount = maxi(qty, 1)
	_ensure_visual()
	_apply_rarity_visual()


func _ensure_visual() -> void:
	if _visual != null and is_instance_valid(_visual):
		return
	if has_node("Visual"):
		_visual = $Visual as Polygon2D


func _apply_rarity_visual() -> void:
	_ensure_visual()
	if _visual == null:
		return
	var item := ContentDB.get_item(item_id)
	var rarity := item.rarity if item else "common"
	var color := LootService.rarity_color(rarity)
	_visual.color = Color(color.r, color.g, color.b, 0.95)
	if has_node("Glow"):
		var glow := $Glow as Polygon2D
		if glow:
			glow.color = Color(color.r, color.g, color.b, 0.28 if rarity in ["rare", "epic", "legendary"] else 0.15)
	scale = Vector2(1.2, 1.2) if rarity in ["rare", "epic", "legendary"] else Vector2.ONE
	if rarity in ["epic", "legendary"] and not has_node("Spark"):
		var spark := Polygon2D.new()
		spark.name = "Spark"
		spark.z_index = 1
		spark.color = Color(color.r, color.g, color.b, 0.7)
		spark.polygon = [Vector2(0, -11), Vector2(2, -2), Vector2(11, 0), Vector2(2, 2), Vector2(0, 11), Vector2(-2, 2), Vector2(-11, 0), Vector2(-2, -2)]
		add_child(spark)


func _physics_process(delta: float) -> void:
	if item_id.is_empty():
		return
	_pulse += delta * (8.0 if _is_rare() else 5.0)
	var s := 1.0 + sin(_pulse) * (0.18 if _is_rare() else 0.1)
	scale = Vector2(s, s) * (1.15 if _is_rare() else 1.0)
	if has_node("Spark"):
		$Spark.rotation += delta * 2.5
		$Spark.modulate.a = 0.45 + 0.35 * sin(_pulse * 1.4)
	var tree := get_tree()
	if tree == null:
		return
	var player := tree.get_first_node_in_group("player") as Node2D
	if player == null:
		return
	var magnet := float(ContentDB.section("combat").get("item_magnet", 72))
	var dist := global_position.distance_to(player.global_position)
	if dist < magnet:
		global_position = global_position.move_toward(player.global_position, 260.0 * delta)
	if dist < 16.0:
		var item := ContentDB.get_item(item_id)
		if item and item.rarity in ["rare", "epic", "legendary"]:
			FloatTextManager.show_message(
				global_position + Vector2(0, -18),
				"+%s" % item.display_name,
				LootService.rarity_color(item.rarity)
			)
		if SfxService:
			SfxService.play_pickup()
		GameState.grant_item(item_id, amount)
		set_deferred("monitoring", false)
		call_deferred("queue_free")


func _is_rare() -> bool:
	var item := ContentDB.get_item(item_id)
	return item != null and item.rarity in ["rare", "epic", "legendary"]
