class_name ItemEffects
## Stateless item-use logic. use_item() returns true when the action consumed
## a turn (and the item, if consumable); false when nothing happened.

const TALISMAN_RANGE: int = 6

static func use_item(item: ItemData, player: Player) -> bool:
	match item.item_type:
		ItemData.ItemType.POTION:
			return _drink(item, player)
		ItemData.ItemType.SCROLL:
			return _read(item, player)
		ItemData.ItemType.WEAPON, ItemData.ItemType.ARMOR:
			return _equip(item, player)
	return false

static func _drink(item: ItemData, player: Player) -> bool:
	GameState.identify(item.id)
	GameState.remove_item(item)
	if item.value_b > 0:
		player.stats.max_hp += item.value_b
		MessageBus.log_message("최대 체력이 %d 늘어났다!" % item.value_b)
	player.heal(item.value_a)
	MessageBus.log_message("%s 마셨다. 체력이 %d 회복됐다." % [Josa.eul_reul(item.identified_name), item.value_a])
	return true

static func _read(item: ItemData, player: Player) -> bool:
	match item.id:
		"talisman":
			var target = _nearest_monster(player, TALISMAN_RANGE)
			if target == null:
				MessageBus.log_message("부적을 쓸 만한 적이 가까이에 없다.")
				return false
			GameState.identify(item.id)
			GameState.remove_item(item)
			MessageBus.log_message("부적이 타오르며 %s에게 %d의 피해를 입혔다!" % [target.display_name, item.value_a])
			target.take_damage(item.value_a)
			return true
		"teleport_talisman":
			var dest: Vector2i = DungeonState.random_free_floor_tile()
			if dest.x < 0:
				MessageBus.log_message("부적이 아무 반응도 하지 않는다.")
				return false
			GameState.identify(item.id)
			GameState.remove_item(item)
			DungeonState.move_actor(player, player.grid_pos, dest)
			MessageBus.log_message("몸이 순식간에 다른 곳으로 옮겨졌다!")
			return true
		"clairvoyance_talisman":
			GameState.identify(item.id)
			GameState.remove_item(item)
			DungeonState.reveal_all()
			MessageBus.log_message("눈앞에 이 층의 모습이 펼쳐진다.")
			return true
		"ledger_fragment":
			var unknown: Array[ItemData] = []
			for entry in GameState.inventory:
				var d: ItemData = entry.item_data
				if d != item and not GameState.is_identified(d.id):
					unknown.append(d)
			if unknown.is_empty():
				MessageBus.log_message("감정할 물건이 없다.")
				return false
			var picked: ItemData = unknown[randi() % unknown.size()]
			GameState.identify(item.id)
			GameState.identify(picked.id)
			GameState.remove_item(item)
			MessageBus.log_message("명부에 적힌 이름이 드러났다. %s의 정체는 %s!" % [picked.unidentified_name, picked.identified_name])
			return true
	return false

static func _equip(item: ItemData, player: Player) -> bool:
	GameState.identify(item.id)
	GameState.remove_item(item)
	if item.item_type == ItemData.ItemType.WEAPON:
		var old: ItemData = GameState.equipped_weapon
		if old != null:
			player.stats.attack_min -= old.value_a
			player.stats.attack_max -= old.value_a
			GameState.add_item(old)
		GameState.equipped_weapon = item
		player.stats.attack_min += item.value_a
		player.stats.attack_max += item.value_a
	else:
		var old_armor: ItemData = GameState.equipped_armor
		if old_armor != null:
			player.stats.defense -= old_armor.value_b
			GameState.add_item(old_armor)
		GameState.equipped_armor = item
		player.stats.defense += item.value_b
	MessageBus.log_message("%s 장착했다." % Josa.eul_reul(item.identified_name))
	return true

static func _nearest_monster(player: Player, max_range: int):
	var best = null
	var best_dist: int = 9999
	for m in TurnManager.monsters:
		if not is_instance_valid(m) or not m.is_alive:
			continue
		var d: int = maxi(absi(m.grid_pos.x - player.grid_pos.x), absi(m.grid_pos.y - player.grid_pos.y))
		if d <= max_range and d < best_dist:
			best = m
			best_dist = d
	return best
