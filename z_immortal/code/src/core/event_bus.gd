extends Node

## Global event bus. Gameplay systems emit; UI and world listen.
## Keep payloads as primitive values or resource ids, not scene nodes.

signal cultivation_broke_through(new_realm_id: String)
signal attack_gained(amount: int, total: int)
signal item_gained(item_id: String, amount: int)
