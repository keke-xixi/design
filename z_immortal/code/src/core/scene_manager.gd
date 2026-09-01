extends Node

## Simple scene router: hub -> stage select -> combat.

const HUB := "res://scenes/world/hub.tscn"
const STAGE_SELECT := "res://scenes/world/stage_select.tscn"
const COMBAT := "res://scenes/world/combat.tscn"


func go_hub() -> void:
	get_tree().change_scene_to_file(HUB)


func go_stage_select() -> void:
	get_tree().change_scene_to_file(STAGE_SELECT)


func go_combat(stage_id: String) -> void:
	if not GameState.enter_stage(stage_id):
		push_warning("Cannot enter stage %s" % stage_id)
		return
	get_tree().change_scene_to_file(COMBAT)
