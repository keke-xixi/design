class_name CultivationState
extends RefCounted

## 攻 / 智 / 防。突破规则在这里，场景只负责播放结果。

var attack_realm_id: String = "ninglu_chu"
var attack: int = 1
var wisdom_rank: int = 1
var defense: int = 1

func cultivate_attack(gain: int, lo: int, hi: int) -> int:
	var before := attack
	attack = clampi(attack + max(gain, 0), lo, hi)
	return attack - before

func try_breakthrough(table: RealmTable, costs: Dictionary, mystic_resets: bool, mystic_start: int) -> Dictionary:
	var current := table.get_realm(attack_realm_id)
	var next_realm := table.get_next(attack_realm_id)
	if next_realm == null:
		return { "ok": false, "reason": "already_peak" }
	var cost := int(costs.get(next_realm.id, 0))
	if attack < cost:
		return {
			"ok": false,
			"reason": "not_enough_attack",
			"need": cost,
			"have": attack,
			"next_realm_id": next_realm.id,
		}
	var crossed_to_mystic := current != null and current.band != next_realm.band and next_realm.band == "mystic"
	attack_realm_id = next_realm.id
	if crossed_to_mystic and mystic_resets:
		attack = mystic_start
	return { "ok": true, "realm_id": next_realm.id, "realm": next_realm, "reset_attack": crossed_to_mystic and mystic_resets }

func attack_cap(mortal_max: int, mystic_max: int, table: RealmTable) -> int:
	var realm := table.get_realm(attack_realm_id)
	if realm != null and realm.band == "mystic":
		return mystic_max
	return mortal_max
