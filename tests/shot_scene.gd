extends Node
## Builds a populated gameplay scene for screenshots (store listing / visual checks).
## Run: Godot --path . res://tests/ShotScene.tscn --write-movie out.png --fixed-fps 30 --quit-after 40
## Uses throwaway settings/save paths so the player's real data is untouched.

func _ready() -> void:
	SettingsManager.settings_path = "user://shot_settings.cfg"
	SettingsManager.tutorial_seen = true
	SaveManager.save_path = "user://shot_save.json"
	IAPManager.store_path = "user://shot_purchases.json"
	StatsManager.stats_path = "user://shot_stats.json"
	seed(11)
	GameState.selected_class_id = "hwarang"
	GameState.pending_continue = false
	var game: Node2D = load("res://scenes/Game.tscn").instantiate()
	add_child(game)
	await get_tree().process_frame
	game._load_floor(7)
	var p = game.player
	var free: Array[Vector2i] = []
	for pos in DungeonState.visible_tiles.keys():
		var d: int = maxi(absi(pos.x - p.grid_pos.x), absi(pos.y - p.grid_pos.y))
		if d >= 2 and d <= 4 and DungeonState.tile_at(pos) == DungeonState.Tile.FLOOR and DungeonState.get_actor_at(pos) == null:
			free.append(pos)
	free.shuffle()
	var ids: Array[String] = ["jeoseung_saja", "gumiho", "sangyeo_gwi"]
	for i in range(mini(ids.size(), free.size())):
		game._spawn_monster_at(MonsterDatabase.get_monster(ids[i]), free[i])
	var loot: Array[String] = ["elixir", "talisman", "soul_blade"]
	for i in range(ids.size(), mini(ids.size() + loot.size(), free.size())):
		DungeonState.place_item(free[i], ItemDatabase.get_item(loot[i - ids.size()]))
	game._refresh_vision()
	p.take_damage(9)
	if "--inventory" in OS.get_cmdline_user_args():
		for id in ["flower_wine", "antidote_herb", "teleport_talisman", "dragon_armor"]:
			GameState.add_item(ItemDatabase.get_item(id))
		game.inventory_panel.show_panel()
	for i in range(28):
		await get_tree().process_frame
	SaveManager.delete_save()
	get_tree().quit()
