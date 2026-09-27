class_name ItemEffects
## Stateless item-use logic. use_item() returns true when the action consumed
## a turn (and the item, if consumable); false when nothing happened.

const TALISMAN_RANGE: int = 6

static func use_item(item: ItemData, player: Player) -> bool:
	var used: bool = false
	var sfx: String = ""
	if item.is_equipment():
		used = _equip(item, player)
		sfx = "equip"
	match item.item_type:
		ItemData.ItemType.POTION:
			used = _drink(item, player)
			sfx = "potion"
		ItemData.ItemType.SCROLL:
			used = _read(item, player)
			sfx = "scroll"
		ItemData.ItemType.FOOD:
			used = _eat(item, player)
			sfx = "eat"
	if used:
		AudioManager.play(sfx)
	return used

static func _drink(item: ItemData, player: Player) -> bool:
	GameState.identify(item.id)
	GameState.remove_item(item)
	if item.value_b > 0:
		player.stats.max_hp += item.value_b
		MessageBus.log_message("최대 체력이 %d 늘어났다!" % item.value_b)
	if item.id == "antidote_herb":
		player.cure_status("poison")
		MessageBus.log_message("독기가 가셨다.")
	player.heal(item.value_a)
	MessageBus.log_message("%s 마셨다. 체력이 %d 회복됐다." % [Josa.eul_reul(item.identified_name), item.value_a])
	return true

## Food takes away value_a turns of hunger. Nothing is eaten on a full stomach.
static func _eat(item: ItemData, player: Player) -> bool:
	if GameState.hunger <= 0:
		MessageBus.log_message("배가 불러서 더 먹을 수 없다.")
		return false
	GameState.remove_item(item)
	GameState.hunger = maxi(0, GameState.hunger - item.value_a)
	var after: String = "배가 든든하다." if GameState.hunger < Player.HUNGRY else "아직 배가 고프다."
	MessageBus.log_message("%s 먹었다. %s" % [Josa.eul_reul(item.identified_name), after])
	player.status_changed.emit()
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
			Fx.flame(target)
			target.set_hit_from(player.grid_pos)
			target.take_damage(item.value_a)
			return true
		"teleport_talisman":
			var dest: Vector2i = DungeonState.random_free_floor_tile()
			if dest.x < 0:
				MessageBus.log_message("부적이 아무 반응도 하지 않는다.")
				return false
			GameState.identify(item.id)
			GameState.remove_item(item)
			Fx.teleport(player.get_parent(), player.grid_pos)
			DungeonState.move_actor(player, player.grid_pos, dest)
			Fx.teleport(player.get_parent(), dest)
			player.pick_up_here()
			MessageBus.log_message("몸이 순식간에 다른 곳으로 옮겨졌다!")
			return true
		"clairvoyance_talisman":
			GameState.identify(item.id)
			GameState.remove_item(item)
			DungeonState.reveal_all()
			TrapSystem.spot_all()
			MessageBus.log_message("눈앞에 이 층의 모습이 펼쳐진다. 숨은 함정까지 훤히 보인다.")
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

## Wears item in its body slot; whatever was there goes back into the bag.
static func _equip(item: ItemData, player: Player) -> bool:
	var slot: String = item.equip_slot()
	GameState.identify(item.id)
	GameState.remove_item(item)
	var old: ItemData = GameState.equipped.get(slot)
	if old != null:
		_apply_bonuses(player, old, -1)
		GameState.add_item(old)
	GameState.equipped[slot] = item
	_apply_bonuses(player, item, 1)
	GameState.equipment_changed.emit()
	Fx.equip(player, slot)
	MessageBus.log_message("%s 장착했다." % Josa.eul_reul(item.identified_name))
	return true

## Takes off what is worn in slot and puts it in the bag. Returns false if the
## slot was empty (no turn is spent).
static func unequip(slot: String, player: Player) -> bool:
	var item: ItemData = GameState.equipped.get(slot)
	if item == null:
		return false
	GameState.equipped.erase(slot)
	_apply_bonuses(player, item, -1)
	GameState.equipment_changed.emit()
	GameState.add_item(item)
	AudioManager.play("equip")
	MessageBus.log_message("%s 벗었다." % Josa.eul_reul(item.identified_name))
	return true

## Adds (factor 1) or removes (factor -1) an item's stat bonuses.
static func _apply_bonuses(player: Player, item: ItemData, factor: int) -> void:
	player.stats.attack_min += factor * item.value_a
	player.stats.attack_max += factor * item.value_a
	player.stats.defense += factor * item.value_b
	if item.bonus_hp != 0:
		player.change_max_hp(factor * item.bonus_hp)

## The closest monster within max_range that the player can see.
static func _nearest_monster(player: Player, max_range: int):
	var best = null
	var best_dist: int = 9999
	for m in TurnManager.monsters:
		if not is_instance_valid(m) or not m.is_alive or not DungeonState.visible_tiles.has(m.grid_pos):
			continue
		var d: int = maxi(absi(m.grid_pos.x - player.grid_pos.x), absi(m.grid_pos.y - player.grid_pos.y))
		if d <= max_range and d < best_dist:
			best = m
			best_dist = d
	return best
