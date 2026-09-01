class_name ArtDef
extends RefCounted

## Cultivation art / technique row from content/arts.json.

var id: String = ""
var display_name: String = ""
var realm_req: String = ""
var qi_per_tick: int = 0
var description: String = ""


static func from_dict(data: Dictionary) -> ArtDef:
	var row := ArtDef.new()
	row.id = str(data.get("id", ""))
	row.display_name = str(data.get("name", ""))
	row.realm_req = str(data.get("realm_req", ""))
	row.qi_per_tick = int(data.get("qi_per_tick", 0))
	row.description = str(data.get("description", ""))
	return row
