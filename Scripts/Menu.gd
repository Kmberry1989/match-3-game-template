extends Control

var status_label
var offline_button
var profile_button
var showcase_button
var shop_button
var logout_button
var multiplayer_button
onready var firebase = get_node("/root/Firebase") if has_node("/root/Firebase") else null

func _ready():
	status_label = Label.new()
	offline_button = TextureButton.new()
	profile_button = TextureButton.new()
	showcase_button = TextureButton.new()
	shop_button = TextureButton.new()
	logout_button = TextureButton.new()
	multiplayer_button = TextureButton.new()

	var bg = TextureRect.new()
	bg.texture = load("res://Assets/Visuals/main_menu_background.png")
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.expand = true
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	move_child(bg, 0)

	var center_container = CenterContainer.new()
	center_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center_container)

	var offset_container = MarginContainer.new()
	offset_container.add_constant_override("margin_top", 200)
	center_container.add_child(offset_container)

	var vbox = VBoxContainer.new()
	vbox.add_constant_override("separation", 0)
	offset_container.add_child(vbox)

	var title = Label.new()
	title.text = " "
	title.align = Label.ALIGN_CENTER
	vbox.add_child(title)

	var margin = Control.new()
	margin.set_custom_minimum_size(Vector2(0, 40))
	vbox.add_child(margin)

	var normal_tex = load("res://Assets/Visuals/button_normal.svg")
	var hover_tex = load("res://Assets/Visuals/button_hover.svg")
	var pressed_tex = load("res://Assets/Visuals/button_pressed.svg")

	offline_button.set_normal_texture(normal_tex)
	offline_button.set_pressed_texture(pressed_tex)
	offline_button.set_hover_texture(hover_tex)
	offline_button.connect("pressed", self, "_on_offline_button_pressed")
	offline_button.set_scale(Vector2(0.8, 0.8))
	vbox.add_child(offline_button)

	var offline_label = Label.new()
	offline_label.text = "Play"
	offline_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	offline_label.align = Label.ALIGN_CENTER
	offline_label.valign = Label.VALIGN_CENTER
	offline_button.add_child(offline_label)

	profile_button.set_normal_texture(normal_tex)
	profile_button.set_pressed_texture(pressed_tex)
	profile_button.set_hover_texture(hover_tex)
	profile_button.connect("pressed", self, "_on_profile_button_pressed")
	profile_button.set_scale(Vector2(0.8, 0.8))
	vbox.add_child(profile_button)

	var profile_label = Label.new()
	profile_label.text = "Profile"
	profile_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	profile_label.align = Label.ALIGN_CENTER
	profile_label.valign = Label.VALIGN_CENTER
	profile_button.add_child(profile_label)

	showcase_button.set_normal_texture(normal_tex)
	showcase_button.set_pressed_texture(pressed_tex)
	showcase_button.set_hover_texture(hover_tex)
	showcase_button.connect("pressed", self, "_on_showcase_button_pressed")
	showcase_button.set_scale(Vector2(0.8, 0.8))
	vbox.add_child(showcase_button)

	var showcase_label = Label.new()
	showcase_label.text = "Showcase"
	showcase_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	showcase_label.align = Label.ALIGN_CENTER
	showcase_label.valign = Label.VALIGN_CENTER
	showcase_button.add_child(showcase_label)

	shop_button.set_normal_texture(normal_tex)
	shop_button.set_pressed_texture(pressed_tex)
	shop_button.set_hover_texture(hover_tex)
	shop_button.connect("pressed", self, "_on_shop_button_pressed")
	shop_button.set_scale(Vector2(0.8, 0.8))
	vbox.add_child(shop_button)

	var shop_label = Label.new()
	shop_label.text = "Shop"
	shop_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	shop_label.align = Label.ALIGN_CENTER
	shop_label.valign = Label.VALIGN_CENTER
	shop_button.add_child(shop_label)

	multiplayer_button.set_normal_texture(normal_tex)
	multiplayer_button.set_pressed_texture(pressed_tex)
	multiplayer_button.set_hover_texture(hover_tex)
	multiplayer_button.connect("pressed", self, "_on_multiplayer_button_pressed")
	multiplayer_button.set_scale(Vector2(0.8, 0.8))
	vbox.add_child(multiplayer_button)

	var mp_label = Label.new()
	mp_label.text = "Multiplayer"
	mp_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	mp_label.align = Label.ALIGN_CENTER
	mp_label.valign = Label.VALIGN_CENTER
	multiplayer_button.add_child(mp_label)

	logout_button.set_normal_texture(normal_tex)
	logout_button.set_pressed_texture(pressed_tex)
	logout_button.set_hover_texture(hover_tex)
	logout_button.connect("pressed", self, "_on_logout_button_pressed")
	logout_button.set_scale(Vector2(0.8, 0.8))
	vbox.add_child(logout_button)

	var logout_label = Label.new()
	logout_label.text = "Logout"
	logout_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	logout_label.align = Label.ALIGN_CENTER
	logout_label.valign = Label.VALIGN_CENTER
	logout_button.add_child(logout_label)

	_update_logout_visibility()

	status_label.text = ""
	status_label.align = Label.ALIGN_CENTER
	status_label.set_custom_minimum_size(Vector2(300, 50))
	vbox.add_child(status_label)

	AudioManager.play_music("menu")

	if firebase != null:
		firebase.Auth.connect("login_succeeded", self, "_update_logout_visibility")
		firebase.Auth.connect("logged_out", self, "_update_logout_visibility")

func _on_offline_button_pressed():
	print("[Menu.gd] Play button pressed.")
	AudioManager.play_sound("ui_click")
	_start_game()

func _on_profile_button_pressed():
	AudioManager.play_sound("ui_click")
	get_tree().change_scene("res://Scenes/Profile.tscn")

func _on_showcase_button_pressed():
	AudioManager.play_sound("ui_click")
	get_tree().change_scene("res://Scenes/Showcase.tscn")

func _on_shop_button_pressed():
	AudioManager.play_sound("ui_click")
	get_tree().change_scene("res://Scenes/Shop.tscn")

func _on_multiplayer_button_pressed():
	AudioManager.play_sound("ui_click")
	get_tree().change_scene("res://Scenes/MultiplayerLobby.tscn")

func _start_game():
	print("[Menu.gd] _start_game: Stopping music and playing sound.")
	AudioManager.stop_music()
	AudioManager.play_sound("game_start")
	print("[Menu.gd] _start_game: Setting session mode to single-player.")
	if Engine.has_singleton("MultiplayerManager"):
		MultiplayerManager.session_mode = "singleplayer"
	print("[Menu.gd] _start_game: Changing to intermediate Loading scene.")
	get_tree().change_scene("res://Scenes/Loading.tscn")

func _update_logout_visibility():
	var logout_visible = false
	if firebase != null:
		logout_visible = firebase.Auth.is_logged_in()
	logout_button.visible = logout_visible

func _on_logout_button_pressed():
	AudioManager.play_sound("ui_click")
	if firebase != null:
		firebase.Auth.logout()
	PlayerManager.player_uid = ""
	get_tree().change_scene("res://Scenes/Login.tscn")
