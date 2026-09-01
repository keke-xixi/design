class_name RealmDef
extends RefCounted

## One cultivation realm row. Loaded from content/realms.json.
## Does not extend Node — keep this file free of scene references.

var id: String = ""
var display_name: String = ""
var order: int = 0
var breakthrough_qi: int = 0
var description: String = ""


static func from_dict(data: Dictionary) -> RealmDef:
	var row := RealmDef.new()
	row.id = str(data.get("id", ""))
	row.display_name = str(data.get("name", ""))
	row.order = int(data.get("order", 0))
	row.breakthrough_qi = int(data.get("breakthrough_qi", 0))
	row.description = str(data.get("description", ""))
	return row
