extends Control

# The URL of the WebSocket server you deployed on Render.
const SERVER_URL = "wss://match3-server.onrender.com"

var status_label: Label
var play_button: TextureButton
var offline_button: TextureButton
var profile_button: TextureButton

func _ready():
	status_label = Label.new()
	play_button = TextureButton.new()
	offline_button = TextureButton.new()
	profile_button = TextureButton.new()

	# Background
	var bg = ColorRect.new()
	bg.color = Color(0, 0, 0) # Black
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# Use a CenterContainer to ensure all elements are perfectly centered
	var center_container = CenterContainer.new()
	center_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center_container)

	# VBoxContainer holds our UI elements vertically
	var vbox = VBoxContainer.new()
	center_container.add_child(vbox)

	# Title Label
	var title = Label.new()
	title.text = " " # Updated game title
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 48)
	vbox.add_child(title)

	# Margin for spacing
	var margin = Control.new()
	margin.custom_minimum_size = Vector2(0, 40)
	vbox.add_child(margin)

	# Load button textures
	var normal_tex = load("res://Assets/Visuals/button_normal.svg")
	var hover_tex = load("res://Assets/Visuals/button_hover.svg")
	var pressed_tex = load("res://Assets/Visuals/button_pressed.svg")

	# Play Online Button
	play_button.texture_normal = normal_tex
	play_button.texture_pressed = pressed_tex
	play_button.texture_hover = hover_tex
	play_button.connect("pressed", _on_play_online_pressed)
	vbox.add_child(play_button)

	var play_label = Label.new()
	play_label.text = "Play Online"
	play_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	play_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	play_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	play_button.add_child(play_label)

	# Offline Button
	offline_button.texture_normal = normal_tex
	offline_button.texture_pressed = pressed_tex
	offline_button.texture_hover = hover_tex
	offline_button.connect("pressed", _on_offline_button_pressed)
	vbox.add_child(offline_button)

	var offline_label = Label.new()
	offline_label.text = "Play Offline"
	offline_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	offline_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	offline_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	offline_button.add_child(offline_label)

	# Profile Button
	profile_button.texture_normal = normal_tex
	profile_button.texture_pressed = pressed_tex
	profile_button.texture_hover = hover_tex
	profile_button.connect("pressed", _on_profile_button_pressed)
	vbox.add_child(profile_button)

	var profile_label = Label.new()
	profile_label.text = "Profile"
	profile_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	profile_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	profile_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	profile_button.add_child(profile_label)

	# Status Label
	status_label.text = ""
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.custom_minimum_size = Vector2(300, 50)
	vbox.add_child(status_label)

	# Connect to NetworkManager signals
	NetworkManager.connection_succeeded.connect(_on_connection_succeeded)
	NetworkManager.connection_failed.connect(_on_connection_failed)
	NetworkManager.server_disconnected.connect(_on_server_disconnected)
	NetworkManager.waiting_for_opponent.connect(_on_waiting_for_opponent)
	NetworkManager.game_started.connect(_on_game_started)

	# Play menu music
	AudioManager.play_music("menu")

func _on_play_online_pressed():
	AudioManager.play_sound("ui_click")
	play_button.disabled = true
	offline_button.disabled = true
	status_label.text = "Connecting to server..."
	NetworkManager.connect_to_server(SERVER_URL)

func _on_offline_button_pressed():
	AudioManager.play_sound("ui_click")
	_start_game()

func _on_profile_button_pressed():
	AudioManager.play_sound("ui_click")
	get_tree().change_scene_to_file("res://Scenes/Profile.tscn")

func _on_connection_succeeded():
	status_label.text = "Connected! Looking for a match..."

func _on_connection_failed():
	status_label.text = "Could not connect to server."
	play_button.disabled = false
	offline_button.disabled = false

func _on_server_disconnected():
	status_label.text = "Disconnected from server."
	play_button.disabled = false
	offline_button.disabled = false

func _on_waiting_for_opponent():
	status_label.text = "Waiting for an opponent..."

func _on_game_started():
	_start_game()

func _start_game():
	AudioManager.stop_music()
	AudioManager.play_sound("game_start")
	get_tree().change_scene_to_file("res://Scenes/Game.tscn")
