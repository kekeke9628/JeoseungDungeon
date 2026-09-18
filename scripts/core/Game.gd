extends Node2D
## Main scene controller: builds the world and UI, spawns the player, loads
## floors, routes input to the player, and handles game over.

const CLASS_PATH: String = "res://resources/classes/mudang.tres"
const MONSTERS_PER_FLOOR_MIN: int = 4
const MONSTERS_PER_FLOOR_MAX: int = 6
const LOOT_PER_FLOOR_MIN: int = 4
const LOOT_PER_FLOOR_MAX: int = 6
const GOLD_CHANCE: float = 0.4
const HP_PER_LEVEL: int = 7

var world: Node2D
var floor_node: Node2D
var player: Player
var camera: Camera2D

var hud: HUD
var message_log: MessageLog
var dpad: DPad
var inventory_panel: InventoryPanel
var game_over_screen: GameOverScreen

var _ended: bool = false

func _ready() -> void:
	randomize()
	GameState.reset_run()
	TurnManager.is_processing = false

	world = Node2D.new()
	add_child(world)
	_build_ui()

	GameState.game_over.connect(_on_game_over)
	GameState.leveled_up.connect(_on_leveled_up)
	GameState.gold_changed.connect(hud.set_gold)
	GameState.level_changed.connect(hud.set_level)
	MessageBus.message_logged.connect(message_log.add_message)

	_spawn_player()
	_load_floor(1)
	hud.set_level(GameState.player_level, GameState.player_xp, GameState.player_xp_to_next)
	hud.set_gold(GameState.gold)

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	hud = HUD.new()
	message_log = MessageLog.new()
	dpad = DPad.new()
	inventory_panel = InventoryPanel.new()
	game_over_screen = GameOverScreen.new()
	for c in [hud, message_log, dpad, inventory_panel, game_over_screen]:
		layer.add_child(c)
	hud.inventory_pressed.connect(inventory_panel.toggle)
	dpad.direction_pressed.connect(_on_direction_pressed)
	dpad.wait_pressed.connect(_on_wait_pressed)
	inventory_panel.item_chosen.connect(_on_item_chosen)
	game_over_screen.restart_pressed.connect(_on_restart)

func _spawn_player() -> void:
	var class_data: CharacterClassData = load(CLASS_PATH)
	GameState.player_class = class_data
	player = Player.new()
	world.add_child(player)
	player.setup(class_data.stats.duplicate(), class_data.color, class_data.glyph, class_data.display_name)
	player.hp_changed.connect(hud.set_hp)
	hud.set_hp(player.current_hp, player.stats.max_hp)

	camera = Camera2D.new()
	camera.offset = Vector2(0, 110)
	player.add_child(camera)
	camera.position = Vector2(Constants.TILE_SIZE / 2.0, Constants.TILE_SIZE / 2.0)
	camera.make_current()

	for item_id in class_data.starting_item_ids:
		var item: ItemData = ItemDatabase.get_item(item_id)
		if item:
			GameState.add_item(item)
	var start_weapon: ItemData = ItemDatabase.get_item("spirit_dagger")
	if start_weapon:
		ItemEffects.use_item(start_weapon, player)

func _load_floor(floor_num: int) -> void:
	if floor_node:
		floor_node.queue_free()
	DungeonState.clear()
	TurnManager.monsters.clear()

	var result: Dictionary = DungeonGenerator.generate(Constants.GRID_WIDTH, Constants.GRID_HEIGHT, floor_num)
	DungeonState.grid = result.grid
	DungeonState.width = Constants.GRID_WIDTH
	DungeonState.height = Constants.GRID_HEIGHT
	DungeonState.stairs_pos = result.stairs_pos

	floor_node = load("res://scenes/dungeon/DungeonFloor.tscn").instantiate()
	world.add_child(floor_node)
	world.move_child(floor_node, 0)
	floor_node.render(DungeonState.grid, Constants.GRID_WIDTH, Constants.GRID_HEIGHT)

	player.move_to_grid(result.start_pos)
	DungeonState.set_actor_at(result.start_pos, player)

	var rooms: Array[Rect2i] = result.rooms
	_spawn_monsters(floor_num, rooms, result.stairs_pos)
	_spawn_loot(rooms, result.start_pos)

	GameState.current_floor = floor_num
	hud.set_floor(floor_num)
	MessageBus.log_message("저승 %d층에 발을 들였다..." % floor_num)

func _spawn_monsters(floor_num: int, rooms: Array[Rect2i], stairs_pos: Vector2i) -> void:
	var is_boss_floor: bool = floor_num == Constants.MAX_FLOOR
	if is_boss_floor:
		var boss: MonsterData = MonsterDatabase.get_boss_for_floor(floor_num)
		if boss:
			_spawn_monster_at(boss, stairs_pos)
	var pool_floor: int = Constants.MAX_FLOOR - 1 if is_boss_floor else floor_num
	var pool: Array[MonsterData] = MonsterDatabase.get_monsters_for_floor(pool_floor)
	if pool.is_empty():
		return
	var count: int = 3 if is_boss_floor else randi_range(MONSTERS_PER_FLOOR_MIN, MONSTERS_PER_FLOOR_MAX)
	for i in range(count):
		var room: Rect2i = rooms[randi_range(1, rooms.size() - 1)]
		var pos: Vector2i = _random_pos_in(room)
		if DungeonState.get_actor_at(pos) != null or not DungeonState.is_walkable(pos) or DungeonState.is_stairs(pos):
			continue
		_spawn_monster_at(pool[randi() % pool.size()], pos)

func _spawn_monster_at(m_data: MonsterData, pos: Vector2i) -> void:
	var m := Monster.new()
	world.add_child(m)
	m.setup_from_data(m_data)
	m.move_to_grid(pos)
	DungeonState.set_actor_at(pos, m)

func _spawn_loot(rooms: Array[Rect2i], start_pos: Vector2i) -> void:
	var ids: Array = ItemDatabase.get_all_ids()
	if ids.is_empty():
		return
	var count: int = randi_range(LOOT_PER_FLOOR_MIN, LOOT_PER_FLOOR_MAX)
	for i in range(count):
		var pos: Vector2i = _random_pos_in(rooms[randi() % rooms.size()])
		if pos == start_pos or DungeonState.is_stairs(pos) or DungeonState.items_at.has(pos) or DungeonState.gold_at.has(pos):
			continue
		if randf() < GOLD_CHANCE:
			DungeonState.place_gold(pos, randi_range(5, 25))
		else:
			DungeonState.place_item(pos, ItemDatabase.get_item(ids[randi() % ids.size()]))

func _random_pos_in(room: Rect2i) -> Vector2i:
	return Vector2i(
		randi_range(room.position.x, room.position.x + room.size.x - 1),
		randi_range(room.position.y, room.position.y + room.size.y - 1))

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	match event.keycode:
		KEY_UP, KEY_W:
			_on_direction_pressed(Vector2i(0, -1))
		KEY_DOWN, KEY_S:
			_on_direction_pressed(Vector2i(0, 1))
		KEY_LEFT, KEY_A:
			_on_direction_pressed(Vector2i(-1, 0))
		KEY_RIGHT, KEY_D:
			_on_direction_pressed(Vector2i(1, 0))
		KEY_SPACE:
			_on_wait_pressed()
		KEY_I:
			inventory_panel.toggle()

func _can_act() -> bool:
	return not _ended and is_instance_valid(player) and player.is_alive and not inventory_panel.visible

func _on_direction_pressed(dir: Vector2i) -> void:
	if _can_act() and player.try_move(dir):
		_after_player_action()

func _on_wait_pressed() -> void:
	if _can_act():
		player.wait_turn()
		_after_player_action()

func _on_item_chosen(item: ItemData) -> void:
	if _ended or not is_instance_valid(player) or not player.is_alive:
		return
	if ItemEffects.use_item(item, player):
		TurnManager.end_player_turn()
		_after_player_action()

func _after_player_action() -> void:
	if _ended or not is_instance_valid(player) or not player.is_alive:
		return
	if DungeonState.is_stairs(player.grid_pos) and GameState.current_floor < Constants.MAX_FLOOR:
		_load_floor(GameState.current_floor + 1)

func _on_leveled_up(new_level: int) -> void:
	if not is_instance_valid(player):
		return
	player.stats.max_hp += HP_PER_LEVEL
	player.stats.attack_max += 1
	if new_level % 2 == 0:
		player.stats.attack_min += 1
	player.heal(HP_PER_LEVEL)
	MessageBus.log_message("레벨 %d 달성! 몸에 힘이 차오른다." % new_level)

func _on_game_over(victory: bool) -> void:
	_ended = true
	game_over_screen.show_result(victory, GameState.current_floor, GameState.player_level, GameState.turn_count)

func _on_restart() -> void:
	get_tree().reload_current_scene()
