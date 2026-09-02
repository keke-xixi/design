class_name Inventory
extends RefCounted

## Counted bag. Item definitions stay in ContentDB.

var _counts: Dictionary = {}

func add(item_id: String, amount: int = 1) -> void:
	if item_id.is_empty() or amount <= 0:
		return
	_counts[item_id] = count_of(item_id) + amount

func remove(item_id: String, amount: int = 1) -> bool:
	if count_of(item_id) < amount:
		return false
	var next_count := count_of(item_id) - amount
	if next_count <= 0:
		_counts.erase(item_id)
	else:
		_counts[item_id] = next_count
	return true

func count_of(item_id: String) -> int:
	return int(_counts.get(item_id, 0))

func all_counts() -> Dictionary:
	return _counts.duplicate()
