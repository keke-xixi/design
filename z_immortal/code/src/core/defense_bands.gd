class_name DefenseBands
extends RefCounted

## Maps a defense value to 凡 / 灵 / 绝 / 玄 using balance.json bands.

static func name_for(defense: int, bands: Variant) -> String:
	if typeof(bands) != TYPE_ARRAY:
		return ""
	for raw in bands:
		if typeof(raw) != TYPE_DICTIONARY:
			continue
		var lo := int(raw.get("min", 0))
		var hi := int(raw.get("max", 0))
		if defense >= lo and defense <= hi:
			return str(raw.get("name", ""))
	return ""
