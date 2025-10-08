extends Node

# This manager handles all sound and music playback.

var sfx_players = []
var music_player: AudioStreamPlayer = null

const MAX_SFX_PLAYERS = 8 # Max simultaneous sound effects

var sounds = {}
var music_tracks = {}

func _ready():
	# Create a pool of audio players for sound effects
	for i in range(MAX_SFX_PLAYERS):
		var player = AudioStreamPlayer.new()
		add_child(player)
		sfx_players.append(player)

	# Create a dedicated player for music
	music_player = AudioStreamPlayer.new()
	music_player.name = "MusicPlayer"
	add_child(music_player)

	# Preload all sounds and music
	load_sounds()
	load_music()

func load_sounds():
	sounds["match_pop"] = load("res://Assets/Sounds/match_pop.ogg")
	sounds["match_chime"] = load("res://Assets/Sounds/match_chime.ogg")
	sounds["match_fanfare"] = load("res://Assets/Sounds/match_fanfare.ogg")
	sounds["dot_land"] = load("res://Assets/Sounds/dot_land.ogg")
	sounds["ui_click"] = load("res://Assets/Sounds/ui_click.ogg")
	sounds["game_start"] = load("res://Assets/Sounds/game_start_swoosh.ogg")

func load_music():
	music_tracks["menu"] = load("res://Assets/Sounds/music_menu.ogg")
	# No game music for now, as requested
	# music_tracks["game"] = load("res://Assets/Sounds/music_game.ogg")

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
