class_name RealmTable
extends RefCounted

## Ordered lookup of RealmDef. File I/O stays in ContentDB.

var _by_id: Dictionary = {}
var _ordered: Array[RealmDef] = []

func load_from_array(rows: Array) -> void:
	_by_id.clear()
	_ordered.clear()
	for raw in rows:
		if typeof(raw) != TYPE_DICTIONARY:
			push_error("RealmTable: skip non-object row")
			continue
		var row: RealmDef = RealmDef.from_dict(raw)
		if row.id.is_empty():
			push_error("RealmTable: skip realm with empty id")
			continue
		if _by_id.has(row.id):
			push_error("RealmTable: duplicate realm id '%s'" % row.id)
			continue
		_by_id[row.id] = row
		_ordered.append(row)
	_ordered.sort_custom(func(a: RealmDef, b: RealmDef) -> bool: return a.order < b.order)

func get_realm(id: String) -> RealmDef:
	return _by_id.get(id) as RealmDef

func get_by_order(order: int) -> RealmDef:
	for row in _ordered:
		if row.order == order:
			return row
	return null

func get_next(id: String) -> RealmDef:
	var current := get_realm(id)
	if current == null:
		return null
	return get_by_order(current.order + 1)

func all_realms() -> Array[RealmDef]:
	return _ordered.duplicate()
