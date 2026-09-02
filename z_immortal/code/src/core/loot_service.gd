extends Node

## Rolls item drops from enemy loot tables + stage bonus.

const RARITY_COLORS := {
	"common": Color(0.85, 0.85, 0.85),
	"uncommon": Color(0.55, 0.95, 0.65),
	"rare": Color(0.55, 0.75, 1.0),
	"epic": Color(0.85, 0.55, 1.0),
	"legendary": Color(1.0, 0.82, 0.35),
}


func roll_enemy_loot(enemy: EnemyDef, stage_id: String) -> Array:
	if enemy == null:
		return []
	var drops: Array = []
	for raw in enemy.loot:
		if typeof(raw) != TYPE_DICTIONARY:
			continue
		var chance := float(raw.get("chance", 0.0))
		if chance <= 0.0 or randf() > chance:
			continue
		var item_id := str(raw.get("item_id", ""))
		if item_id.is_empty():
			continue
		var lo := int(raw.get("min", 1))
		var hi := int(raw.get("max", lo))
		var amount := randi_range(mini(lo, hi), maxi(lo, hi))
		if amount > 0:
			drops.append({ "item_id": item_id, "amount": amount })
	var bonus := _roll_stage_bonus(stage_id, enemy.is_boss)
	if not bonus.is_empty():
		drops.append(bonus)
	return drops


func rarity_color(rarity: String) -> Color:
	return RARITY_COLORS.get(rarity, RARITY_COLORS["common"])


func _roll_stage_bonus(stage_id: String, is_boss: bool) -> Dictionary:
	var cfg := ContentDB.section("loot")
	var base := float(cfg.get("stage_bonus_chance", 0.04))
	if is_boss:
		base += float(cfg.get("boss_bonus_chance", 0.25))
	if randf() > base:
		return {}
	var pool: Variant = cfg.get("stage_bonus_pool", {})
	var rows: Variant = pool.get(stage_id, pool.get("default", []))
	if typeof(rows) != TYPE_ARRAY or rows.is_empty():
		return {}
	var pick := rows[randi() % rows.size()]
	if typeof(pick) != TYPE_DICTIONARY:
		return {}
	var item_id := str(pick.get("item_id", ""))
	if item_id.is_empty():
		return {}
	return { "item_id": item_id, "amount": int(pick.get("amount", 1)) }
