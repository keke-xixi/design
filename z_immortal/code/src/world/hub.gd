extends Control

@onready var _portrait: TextureRect = $PortraitPanel/Portrait


func _ready() -> void:
	var tex := load("res://assets/portraits/player.png")
	if tex:
		_portrait.texture = tex


func _on_challenge_pressed() -> void:
	SceneManager.go_stage_select()


func _on_quit_pressed() -> void:
	get_tree().quit()
