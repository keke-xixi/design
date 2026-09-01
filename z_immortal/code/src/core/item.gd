class_name ItemDef
extends RefCounted

## Item / pill / material row from content/items.json.

var id: String = ""
var display_name: String = ""
var kind: String = ""
var qi_restore: int = 0
var description: String = ""


static func from_dict(data: Dictionary) -> ItemDef:
	var row := ItemDef.new()
	row.id = str(data.get("id", ""))
	row.display_name = str(data.get("name", ""))
	row.kind = str(data.get("kind", ""))
	row.qi_restore = int(data.get("qi_restore", 0))
	row.description = str(data.get("description", ""))
	return row
