class_name CombatSystem
## Stateless combat math shared by Player and Monster attacks.
## hit_chance = 75 base + (attacker.accuracy - defender.evasion), clamped 5..95.

## Rolls hit and damage without applying them, so a caller can log the blow
## before Monster.die() logs the kill.
static func roll_attack(attacker: Actor, defender: Actor) -> Dictionary:
	var hit_chance: int = clampi(75 + (attacker.stats.accuracy - defender.stats.evasion), 5, 95)
	var roll: int = randi_range(1, 100)
	var result: Dictionary = {"hit": false, "damage": 0}
	if roll <= hit_chance:
		var raw_dmg: int = randi_range(attacker.stats.attack_min, attacker.stats.attack_max)
		result.hit = true
		result.damage = max(1, raw_dmg - defender.stats.defense)
	return result

static func resolve_attack(attacker: Actor, defender: Actor) -> Dictionary:
	var result := roll_attack(attacker, defender)
	if result.hit:
		defender.take_damage(result.damage)
	return result
