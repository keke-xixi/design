extends Node

## Runtime player state. Survives scene changes; not a save file yet.

var cultivation: CultivationState
var inventory: Inventory


func _ready() -> void:
	cultivation = CultivationState.new()
	inventory = Inventory.new()
	var start := ContentDB.section("start")
	cultivation.attack = int(start.get("attack", 1))
	cultivation.wisdom_rank = int(start.get("wisdom_rank", 1))
	cultivation.defense = int(start.get("defense", 1))
	cultivation.attack_realm_id = str(start.get("attack_realm_id", "ninglu_chu"))


func cultivate_attack() -> int:
	var atk := ContentDB.section("attack")
	var cap := cultivation.attack_cap(int(atk.get("mortal_max", 1)), int(atk.get("mystic_max", 1)), ContentDB.realms)
	var gained := cultivation.cultivate_attack(int(atk.get("cultivate_gain", 0)), int(atk.get("min", 1)), cap)
	if gained > 0:
		EventBus.attack_gained.emit(gained, cultivation.attack)
	return gained


func try_breakthrough() -> Dictionary:
	var atk := ContentDB.section("attack")
	var result := cultivation.try_breakthrough(
		ContentDB.realms,
		ContentDB.breakthrough_costs(),
		bool(atk.get("mystic_resets_attack", true)),
		int(atk.get("mystic_start", 1)),
	)
	if bool(result.get("ok", false)):
		EventBus.cultivation_broke_through.emit(str(result.get("realm_id", "")))
	return result
