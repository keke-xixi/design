extends Area2D

var amount: int = 1
var _pulse := 0.0

func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	monitoring = false
	monitorable = false
	call_deferred("_enable_sensing")
	$Visual.modulate = Color(0.45, 0.98, 0.55, 0.95)

func _enable_sensing() -> void:
	set_deferred("monitoring", true)

func _physics_process(delta: float) -> void:
	_pulse += delta * 6.0
	var s := 1.0 + sin(_pulse) * 0.12
	scale = Vector2(s, s)
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		return
	var magnet := float(ContentDB.section("combat").get("essence_magnet", 48))
	magnet *= 1.0 + minf(float(GameState.combo) * 0.04, 0.8)
	var dist := global_position.distance_to(player.global_position)
	if dist < magnet:
		global_position = global_position.move_toward(player.global_position, (220.0 + float(GameState.combo) * 12.0) * delta)
	if dist < 14.0:
		GameState.cultivate_attack_amount(amount)
		if SfxService:
			SfxService.play_pickup()
		set_deferred("monitoring", false)
		call_deferred("queue_free")
