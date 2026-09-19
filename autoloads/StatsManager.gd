extends Node
## Lifetime run records shown on the records screen. Autoloaded as
## "StatsManager". Kills are counted in memory and flushed when a run ends.

signal changed

## Overridable so tests never touch the player's real records.
var stats_path: String = "user://stats.json"
var total_runs: int = 0
var wins: int = 0
var kills: int = 0
var best_floor: int = 0
var best_level: int = 0
var fastest_win_turns: int = 0
var class_wins: Dictionary = {}   # class display name -> wins

func _ready() -> void:
	load_stats()

func record_kill() -> void:
	kills += 1

func record_run_end(victory: bool, floor_reached: int, level: int, turns: int, class_name_ko: String) -> void:
	total_runs += 1
	best_floor = maxi(best_floor, floor_reached)
	best_level = maxi(best_level, level)
	if victory:
		wins += 1
		class_wins[class_name_ko] = int(class_wins.get(class_name_ko, 0)) + 1
		if fastest_win_turns == 0 or turns < fastest_win_turns:
			fastest_win_turns = turns
	save_stats()
	changed.emit()

func win_rate_percent() -> int:
	return 0 if total_runs == 0 else int(round(100.0 * wins / total_runs))

func load_stats() -> void:
	if not FileAccess.file_exists(stats_path):
		return
	var f := FileAccess.open(stats_path, FileAccess.READ)
	if f == null:
		return
	var d = JSON.parse_string(f.get_as_text())
	if typeof(d) != TYPE_DICTIONARY:
		return
	total_runs = int(d.get("total_runs", 0))
	wins = int(d.get("wins", 0))
	kills = int(d.get("kills", 0))
	best_floor = int(d.get("best_floor", 0))
	best_level = int(d.get("best_level", 0))
	fastest_win_turns = int(d.get("fastest_win_turns", 0))
	var cw = d.get("class_wins", {})
	class_wins = cw if typeof(cw) == TYPE_DICTIONARY else {}
	changed.emit()

func save_stats() -> void:
	var f := FileAccess.open(stats_path, FileAccess.WRITE)
	if f == null:
		push_warning("StatsManager: cannot write %s" % stats_path)
		return
	f.store_string(JSON.stringify({
		"total_runs": total_runs, "wins": wins, "kills": kills, "best_floor": best_floor,
		"best_level": best_level, "fastest_win_turns": fastest_win_turns, "class_wins": class_wins,
	}))

func reset_for_tests() -> void:
	total_runs = 0
	wins = 0
	kills = 0
	best_floor = 0
	best_level = 0
	fastest_win_turns = 0
	class_wins = {}
	if FileAccess.file_exists(stats_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(stats_path))
