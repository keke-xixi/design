extends Node

## Global event bus. Gameplay systems emit; UI and world listen.
## Keep payloads as primitive values or resource ids, not scene nodes.

signal cultivation_broke_through(new_realm_id: String)
signal mystic_crossed
signal attack_gained(amount: int, total: int)
signal item_gained(item_id: String, amount: int, rarity: String)
signal market_trade(action: String, item_id: String, qty: int, price: int)
signal wave_changed(hint: String)
signal boss_spawned(enemy_id: String)
signal enemy_killed(enemy_id: String, stage_id: String)
signal player_hp_changed(hp: int, max_hp: int)
signal player_died
signal death_pity_gained(amount: int)
signal stage_changed(stage_id: String)
signal stage_cleared(stage_id: String)
signal damage_dealt(world_pos: Vector2, amount: int, is_player_hurt: bool)
signal skill_used(skill_id: String, cooldown: float)
## Pressed while on CD / empty pill — HUD grey deny flash.
signal skill_denied(skill_id: String, reason: String)
signal equipment_changed
signal alchemy_crafted(recipe_id: String, item_id: String, qty: int)
signal gacha_rolled(pool_id: String, item_id: String, qty: int)
signal map_layout_updated(map_size: Vector2, obstacles: Array, zones: Array) # zones: {center, radius, effect} for minimap
signal boss_hp_changed(name: String, hp: int, max_hp: int)
signal boss_hp_cleared
signal chest_opened(world_pos: Vector2)
signal cultivation_stat_gained(stat: String, value: int)
signal stage_reward(spirit_stones: int)
signal spirit_stones_gained(amount: int)
signal combo_milestone(count: int)
signal run_node_changed(index: int, node: Dictionary)
signal run_phase_changed(phase: int, payload: Dictionary)
signal run_choice_resolved(choice_id: String)
