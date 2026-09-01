extends Node

## Steamworks wrapper. Development uses this mock; swap the body later
## without touching cultivation or UI code.

var enabled: bool = false


func is_online() -> bool:
	return false


func unlock_achievement(_id: String) -> void:
	pass


func cloud_save(_key: String, _payload: String) -> void:
	pass


func cloud_load(_key: String) -> String:
	return ""
