extends Node2D
## Main scene controller: builds the world and UI, spawns the player, loads
## floors, routes input to the player, and handles saving and game over.

const CLASS_DIR: String = "res://resources/classes"
const MENU_SCENE: String = "res://scenes/MainMenu.tscn"
const MONSTERS_PER_FLOOR_MIN: int = 4
const MONSTERS_PER_FLOOR_MAX: int = 6
const BOSS_ESCORTS: int = 3
const LOOT_PER_FLOOR_MIN: int = 4
const LOOT_PER_FLOOR_MAX: int = 6
const GOLD_CHANCE: float = 0.4
const HP_PER_LEVEL: int = 9
const SUPPORTER_GLOW := Color(1.0, 0.85, 0.3, 0.3)
const REVIVE_HP_FRACTION: float = 0.5
const SHAKE_STRENGTH: float = 8.0
const SHAKE_TIME: float = 0.18
const CAMERA_BASE_OFFSET := Vector2(0, 110)
const WALK_STEP_DELAY: float = 0.08
const FADE_TIME: float = 0.4

var world: Node2D
var floor_node: Node2D
var player: Player
var camera: Camera2D

var hud: HUD
var message_log: MessageLog
var dpad: DPad
var inventory_panel: InventoryPanel
var game_over_screen: GameOverScreen
var settings_panel: SettingsPanel
var help_panel: HelpPanel

var _ended: bool = false
var _last_hp: int = 0
var _run_recorded: bool = false
var _walk_token: int = 0
var _fade: ColorRect
var _fade_tween: Tween
var _seen_monsters: Dictionary = {}
var _seen_species: Dictionary = {}

func _ready() -> void:
	randomize()
	var continuing: bool = GameState.pending_continue
	var save_data: Dictionary = SaveManager.load_data() if continuing else {}
	if save_data.is_empty():
		continuing = false
	GameState.reset_run()
	TurnManager.is_processing = false
	_seen_species.clear()

	world = Node2D.new()
	add_child(world)
	_build_ui()

	GameState.game_over.connect(_on_game_over)
	GameState.leveled_up.connect(_on_leveled_up)
	GameState.gold_changed.connect(hud.set_gold)
	GameState.level_changed.connect(hud.set_level)
	GameState.skill_changed.connect(_update_skill_button)
	MessageBus.message_logged.connect(message_log.add_message)

	var class_id: String = str(save_data.class_id) if continuing else GameState.selected_class_id
	_spawn_player(class_id, save_data if continuing else {})
	var start_floor: int = int(save_data.floor) if continuing else 1
	_load_floor(start_floor)
	hud.set_level(GameState.player_level, GameState.player_xp, GameState.player_xp_to_next)
	hud.set_gold(GameState.gold)
	hud.set_hp(player.current_hp, player.stats.max_hp)
	_last_hp = player.current_hp
	_update_skill_button()
	if not SettingsManager.tutorial_seen:
		help_panel.show_panel()

func _build_ui() -> void:
	var fade_layer := CanvasLayer.new()
	fade_layer.layer = 1
	add_child(fade_layer)
	_fade = ColorRect.new()
	_fade.color = Color.BLACK
	_fade.size = Vector2(720, 1280)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.modulate.a = 0.0
	fade_layer.add_child(_fade)
	var layer := CanvasLayer.new()
	layer.layer = 2
	add_child(layer)
	hud = HUD.new()
	message_log = MessageLog.new()
	dpad = DPad.new()
	inventory_panel = InventoryPanel.new()
	game_over_screen = GameOverScreen.new()
	settings_panel = SettingsPanel.new()
	help_panel = HelpPanel.new()
	for c in [hud, message_log, dpad, inventory_panel, settings_panel, help_panel, game_over_screen]:
		layer.add_child(c)
	for c in [hud, message_log, dpad, inventory_panel, settings_panel, help_panel, game_over_screen]:
		c.theme = UITheme.get_theme()
	hud.inventory_pressed.connect(inventory_panel.toggle)
	hud.settings_pressed.connect(settings_panel.show_panel)
	help_panel.closed.connect(SettingsManager.mark_tutorial_seen)
	dpad.direction_pressed.connect(_on_direction_pressed)
	dpad.wait_pressed.connect(_on_wait_pressed)
	dpad.skill_pressed.connect(_on_skill_pressed)
	inventory_panel.item_chosen.connect(_on_item_chosen)
	game_over_screen.restart_pressed.connect(_on_restart)
	game_over_screen.revive_pressed.connect(_on_revive)

func _spawn_player(class_id: String, save_data: Dictionary) -> void:
	var class_data: CharacterClassData = load("%s/%s.tres" % [CLASS_DIR, class_id])
	GameState.player_class = class_data
	player = Player.new()
	world.add_child(player)
	player.setup(class_data.stats.duplicate(), class_data.color, class_data.glyph, class_data.display_name, class_data.id)
	player.hp_changed.connect(hud.set_hp)
	player.hp_changed.connect(_on_player_hp_changed)
	player.status_changed.connect(func(): hud.set_status(player.status_text()))
	if IAPManager.supporter:
		player.visual.color = SUPPORTER_GLOW

	camera = Camera2D.new()
	camera.offset = CAMERA_BASE_OFFSET
	player.add_child(camera)
	camera.position = Vector2(Constants.TILE_SIZE / 2.0, Constants.TILE_SIZE / 2.0)
	camera.make_current()

	if not save_data.is_empty():
		SaveManager.apply(save_data, player)
		return
	for item_id in class_data.starting_item_ids:
		var item: ItemData = ItemDatabase.get_item(item_id)
		if item:
			GameState.add_item(item)
	if IAPManager.supporter:
		var wine: ItemData = ItemDatabase.get_item("flower_wine")
		for i in range(IAPManager.SUPPORTER_BONUS_WINE):
			GameState.add_item(wine)
	for item_id in class_data.starting_equip_ids:
		var equip: ItemData = ItemDatabase.get_item(item_id)
		if equip:
			ItemEffects.use_item(equip, player)

func _load_floor(floor_num: int) -> void:
	if floor_node:
		floor_node.queue_free()
	DungeonState.clear()
	for old_monster in TurnManager.monsters:
		if is_instance_valid(old_monster):
			old_monster.queue_free()
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
	_spawn_loot(floor_num, rooms, result.start_pos)

	GameState.current_floor = floor_num
	hud.set_floor(floor_num)
	MessageBus.log_message("저승 %d층에 발을 들였다..." % floor_num)
	if floor_num > 1:
		AudioManager.play("stairs")
	AudioManager.play_music("boss" if MonsterDatabase.get_boss_for_floor(floor_num) != null else "ambient")
	_seen_monsters.clear()
	_refresh_vision()
	_fade_in()
	SaveManager.save_run(player)
	StatsManager.save_stats()

func _spawn_monsters(floor_num: int, rooms: Array[Rect2i], stairs_pos: Vector2i) -> void:
	var boss: MonsterData = MonsterDatabase.get_boss_for_floor(floor_num)
	if boss:
		_spawn_monster_at(boss, stairs_pos)
	var pool: Array[MonsterData] = MonsterDatabase.get_monsters_for_floor(floor_num - 1 if boss else floor_num)
	if pool.is_empty():
		return
	var count: int = BOSS_ESCORTS if boss else randi_range(MONSTERS_PER_FLOOR_MIN, MONSTERS_PER_FLOOR_MAX)
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

func _spawn_loot(floor_num: int, rooms: Array[Rect2i], start_pos: Vector2i) -> void:
	var pool: Array[ItemData] = []
	for id in ItemDatabase.get_all_ids():
		var item: ItemData = ItemDatabase.get_item(id)
		if item.min_floor <= floor_num:
			pool.append(item)
	if pool.is_empty():
		return
	var count: int = randi_range(LOOT_PER_FLOOR_MIN, LOOT_PER_FLOOR_MAX)
	for i in range(count):
		var pos: Vector2i = _random_pos_in(rooms[randi() % rooms.size()])
		if pos == start_pos or DungeonState.is_stairs(pos) or DungeonState.items_at.has(pos) or DungeonState.gold_at.has(pos):
			continue
		if randf() < GOLD_CHANCE:
			DungeonState.place_gold(pos, randi_range(5, 25) + floor_num * 3)
		else:
			DungeonState.place_item(pos, pool[randi() % pool.size()])

func _random_pos_in(room: Rect2i) -> Vector2i:
	return Vector2i(
		randi_range(room.position.x, room.position.x + room.size.x - 1),
		randi_range(room.position.y, room.position.y + room.size.y - 1))

func _fade_in() -> void:
	if _fade_tween != null and _fade_tween.is_valid():
		_fade_tween.kill()
	_fade.modulate.a = 1.0
	_fade_tween = _fade.create_tween()
	_fade_tween.tween_property(_fade, "modulate:a", 0.0, FADE_TIME)

func _refresh_vision() -> void:
	DungeonState.compute_fov(player.grid_pos, Constants.VISION_RADIUS)
	for m in TurnManager.monsters:
		if not is_instance_valid(m):
			continue
		m.visible = DungeonState.visible_tiles.has(m.grid_pos)
		if m.visible:
			_announce_monster(m)

## Logs a monster the first time it is seen on a floor, with a short lore line
## the first time its species is met in a run.
func _announce_monster(m: Monster) -> void:
	var id: int = m.get_instance_id()
	if _seen_monsters.has(id):
		return
	_seen_monsters[id] = true
	MessageBus.log_message("%s 나타났다!" % Josa.i_ga(m.display_name))
	if not _seen_species.has(m.data.id):
		_seen_species[m.data.id] = true
		MessageBus.log_message("  %s" % m.data.description)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var cell := Vector2i((get_global_mouse_position() / float(Constants.TILE_SIZE)).floor())
		_on_map_tapped(cell)
		return
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
		KEY_E, KEY_Q:
			_on_skill_pressed()
		KEY_I:
			inventory_panel.toggle()

## Tap-to-move: a tap on a tile walks (or attacks) toward it. Walking stops when
## a new monster comes into view, damage is taken, or the floor changes.
func _on_map_tapped(cell: Vector2i) -> void:
	_walk_token += 1
	if not _can_act():
		return
	if _guard_stun():
		return
	if cell == player.grid_pos:
		_on_wait_pressed()
		return
	var path: Array[Vector2i] = Pathfinder.find_path(player.grid_pos, cell)
	if path.size() < 2:
		return
	await _walk(path, _walk_token)

func _visible_monster_count() -> int:
	var n: int = 0
	for m in TurnManager.monsters:
		if is_instance_valid(m) and DungeonState.visible_tiles.has(m.grid_pos):
			n += 1
	return n

func _walk(path: Array[Vector2i], token: int) -> void:
	var floor_at_start: int = GameState.current_floor
	var hp_at_start: int = player.current_hp
	var seen_at_start: int = _visible_monster_count()
	for i in range(1, path.size()):
		if token != _walk_token or not _can_act() or GameState.current_floor != floor_at_start:
			return
		var step: Vector2i = path[i] - player.grid_pos
		if absi(step.x) + absi(step.y) != 1:
			return  # displaced (trap teleport etc.): abandon the route
		if player.has_status("stun") or not player.try_move(step):
			return
		_after_player_action()
		if seen_at_start > 0:
			return  # enemies in view: one careful step per tap
		if not is_instance_valid(player) or not player.is_alive or player.current_hp < hp_at_start:
			return
		if _visible_monster_count() > seen_at_start:
			return
		await get_tree().create_timer(WALK_STEP_DELAY).timeout

## A stunned player loses the action: the turn passes and the stun ticks down.
func _guard_stun() -> bool:
	if not player.has_status("stun"):
		return false
	MessageBus.log_message("기절해서 움직일 수 없다!")
	TurnManager.end_player_turn()
	_after_player_action()
	return true

func _can_act() -> bool:
	return not _ended and is_instance_valid(player) and player.is_alive and not _modal_open()

func _modal_open() -> bool:
	return inventory_panel.visible or settings_panel.visible or help_panel.visible

func _on_direction_pressed(dir: Vector2i) -> void:
	_walk_token += 1
	if not _can_act() or _guard_stun():
		return
	if player.try_move(dir):
		_after_player_action()

func _on_wait_pressed() -> void:
	_walk_token += 1
	if _can_act() and not _guard_stun():
		player.wait_turn()
		_after_player_action()

func _on_skill_pressed() -> void:
	_walk_token += 1
	if not _can_act() or _guard_stun():
		return
	if GameState.skill_cooldown_left > 0:
		MessageBus.log_message("아직 기술을 쓸 수 없다. (%d턴)" % GameState.skill_cooldown_left)
		return
	var c: CharacterClassData = GameState.player_class
	if SkillEffects.use(c.skill_id, player):
		AudioManager.play("skill")
		GameState.skill_cooldown_left = c.skill_cooldown + 1
		TurnManager.end_player_turn()
		_after_player_action()

func _on_item_chosen(item: ItemData) -> void:
	_walk_token += 1
	if _ended or not is_instance_valid(player) or not player.is_alive or _guard_stun():
		return
	if ItemEffects.use_item(item, player):
		TurnManager.end_player_turn()
		_after_player_action()

func _after_player_action() -> void:
	if _ended or not is_instance_valid(player) or not player.is_alive:
		return
	if DungeonState.is_stairs(player.grid_pos) and GameState.current_floor < Constants.MAX_FLOOR:
		_load_floor(GameState.current_floor + 1)
		return
	_refresh_vision()

func _update_skill_button() -> void:
	var c: CharacterClassData = GameState.player_class
	if c:
		dpad.set_skill(c.skill_name, GameState.skill_cooldown_left)

func _on_player_hp_changed(current: int, _max_hp: int) -> void:
	if current < _last_hp and is_instance_valid(camera):
		var tw := camera.create_tween()
		for i in range(3):
			var jitter := Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * SHAKE_STRENGTH
			tw.tween_property(camera, "offset", CAMERA_BASE_OFFSET + jitter, SHAKE_TIME / 4.0)
		tw.tween_property(camera, "offset", CAMERA_BASE_OFFSET, SHAKE_TIME / 4.0)
	_last_hp = current

func _on_leveled_up(new_level: int) -> void:
	if not is_instance_valid(player):
		return
	player.stats.max_hp += HP_PER_LEVEL
	player.stats.attack_max += 1
	if new_level % 2 == 0:
		player.stats.attack_min += 1
	player.heal(HP_PER_LEVEL)
	MessageBus.log_message("레벨 %d 달성! 몸에 힘이 차오른다." % new_level)
	AudioManager.play("levelup")

func _on_game_over(victory: bool) -> void:
	if _ended:
		return
	_ended = true
	AudioManager.stop_music()
	AudioManager.play("victory" if victory else "defeat")
	game_over_screen.show_result(victory, GameState.current_floor, GameState.player_level, GameState.turn_count, IAPManager.revive_tokens, GameState.last_attacker)
	if victory or IAPManager.revive_tokens <= 0:
		_finish_run(victory)

func _on_revive() -> void:
	if not _ended or not is_instance_valid(player) or player.is_alive or not IAPManager.consume_revive():
		return
	player.revive(REVIVE_HP_FRACTION)
	_ended = false
	game_over_screen.visible = false
	MessageBus.log_message("부활 부적이 타오르며 다시 숨이 돌아왔다!")
	AudioManager.play("levelup")
	AudioManager.play_music("boss" if MonsterDatabase.get_boss_for_floor(GameState.current_floor) != null else "ambient")
	SaveManager.save_run(player)
	_refresh_vision()

## Records the run once. A defeat that can still be revived is recorded only
## when the player gives up and restarts.
func _finish_run(victory: bool) -> void:
	if _run_recorded:
		return
	_run_recorded = true
	SaveManager.delete_save()
	StatsManager.record_run_end(victory, GameState.current_floor, GameState.player_level, GameState.turn_count, GameState.player_class.display_name)

func _on_restart() -> void:
	_finish_run(false)
	get_tree().change_scene_to_file(MENU_SCENE)
