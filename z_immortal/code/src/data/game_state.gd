extends Node

## Runtime player state. Survives scene changes; not a save file yet.

var cultivation: CultivationState
var inventory: Inventory


func _ready() -> void:
	cultivation = CultivationState.new()
	inventory = Inventory.new()


func breathe_equipped() -> int:
	var art := ContentDB.get_art(cultivation.equipped_art_id)
	var gained := cultivation.breathe(art)
	if gained > 0:
		EventBus.qi_gained.emit(gained, cultivation.qi)
	return gained


func try_breakthrough() -> Dictionary:
	var result := cultivation.try_breakthrough(ContentDB.realms)
	if bool(result.get("ok", false)):
		EventBus.cultivation_broke_through.emit(str(result.get("realm_id", "")))
	return result
