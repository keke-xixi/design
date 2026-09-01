class_name CultivationState
extends RefCounted

## Player cultivation progress. Breakthrough rules live here, not in scenes.

var realm_id: String = "mortal"
var qi: int = 0
var equipped_art_id: String = "basic_breathing"


func breathe(art: ArtDef) -> int:
	if art == null:
		return 0
	var gained: int = max(art.qi_per_tick, 0)
	qi += gained
	return gained


func try_breakthrough(table: RealmTable) -> Dictionary:
	var next_realm := table.get_next(realm_id)
	if next_realm == null:
		return { "ok": false, "reason": "already_peak" }
	if qi < next_realm.breakthrough_qi:
		return {
			"ok": false,
			"reason": "not_enough_qi",
			"need": next_realm.breakthrough_qi,
			"have": qi,
			"next_realm_id": next_realm.id,
		}
	qi -= next_realm.breakthrough_qi
	realm_id = next_realm.id
	return { "ok": true, "realm_id": next_realm.id, "realm": next_realm }
