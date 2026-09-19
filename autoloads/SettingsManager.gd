extends Node
## Persistent user settings (volumes). Autoloaded as "SettingsManager".

signal changed

const DEFAULT_SFX: float = 0.8
const DEFAULT_MUSIC: float = 0.5

## Overridable so tests never touch the player's real settings.
var settings_path: String = "user://settings.cfg"
var sfx_volume: float = DEFAULT_SFX
var music_volume: float = DEFAULT_MUSIC
var tutorial_seen: bool = false

func _ready() -> void:
	load_settings()

func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(settings_path) != OK:
		return
	sfx_volume = clampf(float(cfg.get_value("audio", "sfx", DEFAULT_SFX)), 0.0, 1.0)
	music_volume = clampf(float(cfg.get_value("audio", "music", DEFAULT_MUSIC)), 0.0, 1.0)
	tutorial_seen = bool(cfg.get_value("ui", "tutorial_seen", false))
	changed.emit()

func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "sfx", sfx_volume)
	cfg.set_value("audio", "music", music_volume)
	cfg.set_value("ui", "tutorial_seen", tutorial_seen)
	var err: int = cfg.save(settings_path)
	if err != OK:
		push_warning("SettingsManager: cannot save %s (error %d)" % [settings_path, err])

func set_sfx_volume(v: float) -> void:
	sfx_volume = clampf(v, 0.0, 1.0)
	changed.emit()
	save_settings()

func set_music_volume(v: float) -> void:
	music_volume = clampf(v, 0.0, 1.0)
	changed.emit()
	save_settings()

func mark_tutorial_seen() -> void:
	tutorial_seen = true
	save_settings()
