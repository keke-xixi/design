class_name GachaRoller
extends RefCounted

## Weighted roll. Weights come from balance.json via weight_key on each entry.


static func roll(entries: Array, weights: Dictionary) -> Dictionary:
	var total := 0
	var prepared: Array = []
	for raw in entries:
		if typeof(raw) != TYPE_DICTIONARY:
			continue
		var key := str(raw.get("weight_key", ""))
		var weight := int(weights.get(key, raw.get("weight", 0)))
		if weight <= 0:
			continue
		prepared.append({ "entry": raw, "weight": weight })
		total += weight
	if total <= 0:
		return {}
	var pick := randi() % total
	var acc := 0
	for row in prepared:
		acc += int(row["weight"])
		if pick < acc:
			return row["entry"]
	return prepared.back()["entry"]
