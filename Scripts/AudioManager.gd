extends Node

# This manager handles all sound and music playback.

var sfx_players = []
var music_player: AudioStreamPlayer = null

const MAX_SFX_PLAYERS = 8 # Max simultaneous sound effects

var sounds = {}
var music_tracks = {}

var music_bus_idx: int
var sfx_bus_idx: int

func _ready():
	# Create audio buses for music and SFX
	AudioServer.add_bus()
	music_bus_idx = AudioServer.bus_count - 1
	AudioServer.set_bus_name(music_bus_idx, "Music")
	
	AudioServer.add_bus()
	sfx_bus_idx = AudioServer.bus_count - 1
	AudioServer.set_bus_name(sfx_bus_idx, "SFX")

	# Create a pool of audio players for sound effects
	for i in range(MAX_SFX_PLAYERS):
		var player = AudioStreamPlayer.new()
		player.bus = "SFX"
		add_child(player)
		sfx_players.append(player)

	# Create a dedicated player for music
	music_player = AudioStreamPlayer.new()
	music_player.name = "MusicPlayer"
	music_player.bus = "Music"
	add_child(music_player)

	# Preload all sounds and music
	load_sounds()
	load_music()

func load_sounds():
	sounds["match_pop"] = load("res://Assets/Sounds/pop.ogg")
	sounds["match_chime"] = load("res://Assets/Sounds/match_chime.ogg")
	sounds["match_fanfare"] = load("res://Assets/Sounds/match_fanfare.ogg")
	sounds["dot_land"] = load("res://Assets/Sounds/dot_land.ogg")
	sounds["ui_click"] = load("res://Assets/Sounds/ui_click.ogg")
	sounds["game_start"] = load("res://Assets/Sounds/game_start_swoosh.ogg")
	sounds["yawn"] = load("res://Assets/Sounds/yawn.ogg")
	sounds["surprised"] = load("res://Assets/Sounds/surprised.ogg")
	sounds["shuffle"] = load("res://Assets/Sounds/Music_fx_cymbal_rush.ogg")

func load_music():
	music_tracks["menu"] = load("res://Assets/Sounds/music_menu.ogg")
	music_tracks["game"] = load("res://Assets/Sounds/music_ingame.mp3")

func play_sound(sound_name):
	if not sounds.has(sound_name):
		print("Sound not found: ", sound_name)
		return

	# Find an available player and play the sound
	for player in sfx_players:
		if not player.playing:
			player.stream = sounds[sound_name]
			player.play()
			return

func play_music(track_name, loop = true):
	if not music_tracks.has(track_name):
		print("Music not found: ", track_name)
		return

	music_player.stream = music_tracks[track_name]
	music_player.stream.loop = loop
	music_player.play()

func stop_music():
	music_player.stop()

func set_music_volume(volume_db):
	AudioServer.set_bus_volume_db(music_bus_idx, volume_db)

func set_sfx_volume(volume_db):
	AudioServer.set_bus_volume_db(sfx_bus_idx, volume_db)

func get_music_volume():
	return AudioServer.get_bus_volume_db(music_bus_idx)

func get_sfx_volume():
	return AudioServer.get_bus_volume_db(sfx_bus_idx)
