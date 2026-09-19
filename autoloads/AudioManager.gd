extends Node
## Plays pooled sound effects and looping music. Missing files are ignored so
## the game runs silently without assets. Autoloaded as "AudioManager".

const SFX_DIR: String = "res://assets/audio/sfx/"
const MUSIC_DIR: String = "res://assets/audio/music/"
const POOL_SIZE: int = 8

var _pool: Array[AudioStreamPlayer] = []
var _music: AudioStreamPlayer
var _current_music: String = ""
var _cache: Dictionary = {}

func _ready() -> void:
	for i in range(POOL_SIZE):
		var p := AudioStreamPlayer.new()
		add_child(p)
		_pool.append(p)
	_music = AudioStreamPlayer.new()
	add_child(_music)
	SettingsManager.changed.connect(_apply_music_volume)
	_apply_music_volume()

func _stream(path: String) -> AudioStream:
	if _cache.has(path):
		return _cache[path]
	var s: AudioStream = null
	if ResourceLoader.exists(path):
		s = load(path)
	_cache[path] = s
	return s

func play(sfx_name: String) -> void:
	var s: AudioStream = _stream(SFX_DIR + sfx_name + ".wav")
	if s == null or SettingsManager.sfx_volume <= 0.0:
		return
	for p in _pool:
		if not p.playing:
			p.stream = s
			p.volume_db = linear_to_db(SettingsManager.sfx_volume)
			p.play()
			return

func play_music(track: String) -> void:
	if track == _current_music:
		return
	_current_music = track
	var s: AudioStream = _stream(MUSIC_DIR + track + ".wav")
	if s == null:
		_music.stop()
		return
	if s is AudioStreamWAV:
		var wav := s as AudioStreamWAV
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = 0
		wav.loop_end = wav.data.size() / 2
	_music.stream = s
	_apply_music_volume()
	_music.play()

func stop_music() -> void:
	_current_music = ""
	_music.stop()

func _apply_music_volume() -> void:
	_music.volume_db = linear_to_db(maxf(SettingsManager.music_volume, 0.0001))
	if SettingsManager.music_volume <= 0.0:
		_music.stream_paused = true
	else:
		_music.stream_paused = false

func _exit_tree() -> void:
	for p in _pool:
		p.stop()
		p.stream = null
	_music.stop()
	_music.stream = null
	_cache.clear()
