class_name RealmDef
extends RefCounted

## One attack-realm row from content/realms.json.
## Breakthrough cost lives in content/balance.json, not here.

var id: String = ""
var display_name: String = ""
var band: String = "mortal"
var group: String = ""
var group_name: String = ""
var stage: String = ""
var stage_name: String = ""
var order: int = 0
var is_hidden: bool = false

static func from_dict(data: Dictionary) -> RealmDef:
	var row := RealmDef.new()
	row.id = str(data.get("id", ""))
	row.display_name = str(data.get("name", ""))
	row.band = str(data.get("band", "mortal"))
	row.group = str(data.get("group", ""))
	row.group_name = str(data.get("group_name", ""))
	row.stage = str(data.get("stage", ""))
	row.stage_name = str(data.get("stage_name", ""))
	row.order = int(data.get("order", 0))
	row.is_hidden = bool(data.get("is_hidden", false))
	return row
