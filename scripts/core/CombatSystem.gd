class_name CombatSystem
## Stateless combat math shared by Player and Monster attacks.
## hit_chance = 75 base + (attacker.accuracy - defender.evasion), clamped 5..95.

static func resolve_attack(attacker: Actor, defender: Actor) -> Dictionary:
	var hit_chance: int = clampi(75 + (attacker.stats.accuracy - defender.stats.evasion), 5, 95)
	var roll: int = randi_range(1, 100)
	var result: Dictionary = {"hit": false, "damage": 0, "defender_died": false}
	if roll <= hit_chance:
		var raw_dmg: int = randi_range(attacker.stats.attack_min, attacker.stats.attack_max)
		var dmg: int = max(1, raw_dmg - defender.stats.defense)
		defender.take_damage(dmg)
		result.hit = true
		result.damage = dmg
		result.defender_died = not defender.is_alive
	return result
