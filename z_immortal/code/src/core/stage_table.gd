class_name StageTable
extends RefCounted

var _by_id: Dictionary = {}
var _ordered: Array[StageDef] = []

func load_from_array(rows: Array) -> void:
	_by_id.clear()
	_ordered.clear()
	for raw in rows:
		if typeof(raw) != TYPE_DICTIONARY:
			continue
		var row: StageDef = StageDef.from_dict(raw)
		if row.id.is_empty():
			continue
		_by_id[row.id] = row
		_ordered.append(row)
	_ordered.sort_custom(func(a: StageDef, b: StageDef) -> bool: return a.order < b.order)

func get_stage(id: String) -> StageDef:
	return _by_id.get(id) as StageDef

func get_by_order(order: int) -> StageDef:
	for row in _ordered:
		if row.order == order:
			return row
	return null

func all_stages() -> Array[StageDef]:
	return _ordered.duplicate()
