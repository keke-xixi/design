extends Area2D

var amount: int = 1
var _pulse := 0.0


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	monitoring = true
	monitorable = false
	$Visual.modulate = Color(0.45, 0.98, 0.55, 0.95)


func _physics_process(delta: float) -> void:
	_pulse += delta * 6.0
	var s := 1.0 + sin(_pulse) * 0.12
	scale = Vector2(s, s)
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		return
	var magnet := float(ContentDB.section("combat").get("essence_magnet", 48))
	var dist := global_position.distance_to(player.global_position)
	if dist < magnet:
		global_position = global_position.move_toward(player.global_position, 220.0 * delta)
	if dist < 14.0:
		GameState.cultivate_attack_amount(amount)
		queue_free()
