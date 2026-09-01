class_name CombatResolver
extends RefCounted

## Placeholder for turn / hit resolution.
## Keep formulas here so scenes only play animations from the result.

func resolve_hit(attacker_atk: int, defender_def: int) -> int:
	return max(attacker_atk - defender_def, 1)
