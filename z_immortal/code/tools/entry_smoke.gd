extends SceneTree

func _initialize() -> void:
	await process_frame
	var gs = root.get_node("GameState")
	var sm = root.get_node("SceneManager")
	print("unlocked=", gs.get("unlocked_order"), " stage=", gs.get("stage_id"))
	var ok = gs.call("enter_stage", "sect")
	print("enter_stage sect => ", ok)
	sm.call("go_combat", "sect")
	await process_frame
	await process_frame
	await process_frame
	var scene = root.get_tree().current_scene
	print("current_scene=", scene)
	if scene:
		print("scene_name=", scene.name, " path=", scene.scene_file_path)
		print("has_player=", scene.get_node_or_null("Player") != null)
		print("has_mobs=", scene.get_node_or_null("Mobs") != null)
		var overlay = null
		for c in scene.get_children():
			if str(c.get_script()) .contains("run_overlay"):
				overlay = c
				break
		print("overlay=", overlay, " visible=", overlay.visible if overlay else null)
	else:
		printerr("NO CURRENT SCENE")
	# Also test stage_select instantiate
	var sel = load("res://scenes/world/stage_select.tscn").instantiate()
	root.add_child(sel)
	await process_frame
	var btn = sel.get_node_or_null("Root/Panel/Body/Detail/EnterButton")
	print("enter_btn=", btn, " disabled=", btn.disabled if btn else null)
	print("btn_global=", btn.get_global_rect() if btn else null)
	sel.queue_free()
	quit(0 if scene and scene.get_node_or_null("Player") else 1)
