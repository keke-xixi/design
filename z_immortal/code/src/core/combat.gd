class_name CombatResolver
extends RefCounted

## Hit and HP formulas. Scenes only play the result.

static func hit_damage(atk: int, defense: int, flat: int = 0, scale: float = 1.0) -> int:
	return maxi(int(round(float(flat) + float(atk) * scale)) - defense, 1)

static func player_max_hp(hp_base: int, defense: int, hp_per_defense: int) -> int:
	return maxi(hp_base + defense * hp_per_defense, 1)

func resolve_hit(attacker_atk: int, defender_def: int) -> int:
	return hit_damage(attacker_atk, defender_def)
