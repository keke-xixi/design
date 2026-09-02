extends Node

## Simple scene router: hub -> stage select -> combat.

const HUB := "res://scenes/world/hub.tscn"
const STAGE_SELECT := "res://scenes/world/stage_select.tscn"
const COMBAT := "res://scenes/world/combat.tscn"
const MARKET := "res://scenes/world/market.tscn"
const EQUIPMENT := "res://scenes/world/equipment.tscn"
const ALCHEMY := "res://scenes/world/alchemy.tscn"


func go_hub() -> void:
	SaveService.save_game()
	get_tree().change_scene_to_file(HUB)


func go_stage_select() -> void:
	SaveService.save_game()
	get_tree().change_scene_to_file(STAGE_SELECT)


func go_combat(stage_id: String) -> void:
	if not GameState.enter_stage(stage_id):
		push_warning("Cannot enter stage %s" % stage_id)
		return
	SaveService.save_game()
	get_tree().change_scene_to_file(COMBAT)


func go_market() -> void:
	SaveService.save_game()
	get_tree().change_scene_to_file(MARKET)


func go_equipment() -> void:
	SaveService.save_game()
	get_tree().change_scene_to_file(EQUIPMENT)


func go_alchemy() -> void:
	SaveService.save_game()
	get_tree().change_scene_to_file(ALCHEMY)
