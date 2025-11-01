extends Control

onready var name_edit = $CenterContainer/VBoxContainer/NameEdit
onready var login_button = $CenterContainer/VBoxContainer/LoginButton
onready var google_login_button = get_node_or_null("CenterContainer/VBoxContainer/GoogleLoginButton")
onready var remember_check = $CenterContainer/VBoxContainer/RememberCheck
onready var status_label = $CenterContainer/VBoxContainer/StatusLabel
onready var cancel_button = $CenterContainer/VBoxContainer/CancelButton
onready var firebase = get_node_or_null("/root/Firebase")

var auth_in_progress = false
var cancel_requested = false
var _web_client_id = ""
var avatar_container

func _ready():
	print("[Login.gd] _ready: Starting.")
	login_button.connect("pressed", self, "_on_login_pressed")
	if google_login_button != null:
		google_login_button.connect("pressed", self, "_on_google_login_pressed")
	cancel_button.connect("pressed", self, "_on_cancel_pressed")
	_load_local_name()
	print("[Login.gd] _ready: Local name loaded.")

	var scale_factor = 4.0
	var to_scale = [name_edit, login_button, google_login_button, cancel_button, remember_check]
	for c in to_scale:
		if c != null:
			c.set_scale(Vector2(scale_factor, scale_factor))

	if get_node_or_null("/root/AudioManager") != null:
		print("[Login.gd] _ready: Playing login music.")
		AudioManager.play_music("login")
	
	if firebase == null:
		print("[Login.gd] _ready: Firebase plugin not found.")
		if google_login_button:
			google_login_button.disabled = true
			google_login_button.visible = false

	print("[Login.gd] _ready: Firebase check complete.")

	if google_login_button != null:
		google_login_button.visible = false
		google_login_button.disabled = true
	
	if firebase:
		print("[Login.gd] _ready: Connecting Firebase signals.")
		firebase.Auth.connect("login_succeeded", self, "_on_authentication_succeeded")
		firebase.Auth.connect("login_failed", self, "_on_authentication_failed")
		firebase.Auth.connect("logged_out", self, "_on_logged_out")
		_web_client_id = _read_env_value("webClientId")

		if OS.has_feature("JavaScript"):
			print("[Login.gd] _ready: Web platform detected, checking for OAuth token.")
			var provider = _setup_web_oauth()
			var token = firebase.Auth.get_token_from_url(provider)
			if token != null and str(token) != "":
				print("[Login.gd] _ready: OAuth token found, beginning auth.")
				_begin_auth("Signing in...")
				firebase.Auth.login_with_oauth(token, provider)
		else:
			print("[Login.gd] _ready: Checking for auto-login on native platform.")
			yield(get_tree().create_timer(0.5), "timeout")
			print("[Login.gd] _ready: Timer finished. Checking for user.auth file.")
			var f = File.new()
			if f.file_exists("user://user.auth"):
				print("[Login.gd] _ready: user.auth file found.")
				if firebase.Auth.check_auth_file():
					print("[Login.gd] _ready: check_auth_file() returned true. Beginning auth.")
					_begin_auth("Signing in...")
				else:
					print("[Login.gd] _ready: check_auth_file() returned false.")
			else:
				print("[Login.gd] _ready: user.auth file not found. No auto-login.")

	if Engine.has_singleton("GodotGetImage"):
		print("[Login.gd] _ready: GodotGetImage plugin found, connecting signals.")
		var image_getter = get_node("/root/GodotGetImage")
		image_getter.connect("image_selected", self, "_on_image_selected")
		image_getter.connect("request_cancelled", self, "_on_avatar_picker_cancelled")
	
	print("[Login.gd] _ready: Finished.")


func _on_login_pressed():
	print("[Login.gd] _on_login_pressed: Button pressed.")
	if auth_in_progress:
		return
	var player_name = name_edit.text.strip_edges()
	if player_name == "":
		player_name = "Guest"
	PlayerManager.player_data["player_name"] = player_name
	SaveManager.save_player(PlayerManager.player_data)
	print("[Login.gd] _on_login_pressed: Player data saved.")

	if not PlayerManager.player_data.has("avatar"):
		print("[Login.gd] _on_login_pressed: No avatar found, prompting for one.")
		_prompt_for_avatar()
	else:
		print("[Login.gd] _on_login_pressed: Avatar found, changing to Menu scene.")
		get_tree().change_scene("res://Scenes/Menu.tscn")

func _on_google_login_pressed():
	if auth_in_progress:
		return
	status_label.text = "Google sign-in is disabled"

func _on_authentication_succeeded(auth_data):
	print("[Login.gd] _on_authentication_succeeded: Firebase authentication succeeded!")
	if cancel_requested:
		cancel_requested = false
		_end_auth()
		status_label.text = "Canceled"
		if firebase != null and firebase.Auth.is_logged_in():
			firebase.Auth.logout()
		return
	if (remember_check == null or remember_check.is_pressed()) and not OS.has_feature("JavaScript"):
		status_label.text = "Saving..."
		firebase.Auth.save_auth(auth_data)
	
	PlayerManager.load_player_data(auth_data)
	print("[Login.gd] _on_authentication_succeeded: Player data loaded.")

	if not PlayerManager.player_data.has("avatar"):
		print("[Login.gd] _on_authentication_succeeded: No avatar found, prompting for one.")
		_prompt_for_avatar()
	else:
		print("[Login.gd] _on_authentication_succeeded: Avatar found, changing to Menu scene.")
		get_tree().change_scene("res://Scenes/Menu.tscn")


func _on_authentication_failed(code, message):
	var error_message = str(message) if message != null else "No error message provided."
	var msg = "Firebase authentication failed: " + str(code) + ": " + error_message
	print(msg)
	status_label.text = msg
	_end_auth()

func _on_logged_out():
	print("[Login.gd] _on_logged_out: Logged out.")
	_end_auth()

func _on_cancel_pressed():
	print("[Login.gd] _on_cancel_pressed: Cancel button pressed.")
	cancel_requested = true
	auth_in_progress = false
	cancel_button.visible = false
	status_label.text = "Canceling..."
	if firebase != null:
		firebase.Auth.remove_auth()
		if firebase.Auth.is_logged_in():
			firebase.Auth.logout()
	_end_auth()

func _prompt_for_avatar():
	print("[Login.gd] _prompt_for_avatar: Prompting for avatar.")
	$CenterContainer.visible = false
	status_label.text = "Select an avatar"
	status_label.visible = true

	avatar_container = VBoxContainer.new()
	avatar_container.set_align(BoxContainer.ALIGN_CENTER)
	add_child(avatar_container)
	avatar_container.set_anchors_preset(Control.PRESET_CENTER)

	if OS.get_name() == "Android" and Engine.has_singleton("GodotGetImage"):
		print("[Login.gd] _prompt_for_avatar: Android OS detected, showing native options.")
		var gallery_button = Button.new()
		gallery_button.text = "Select from Gallery"
		avatar_container.add_child(gallery_button)
		gallery_button.connect("pressed", self, "_on_gallery_pressed")

		var camera_button = Button.new()
		camera_button.text = "Take Photo"
		avatar_container.add_child(camera_button)
		camera_button.connect("pressed", self, "_on_camera_pressed")
	else:
		print("[Login.gd] _prompt_for_avatar: iOS or Desktop detected, showing placeholders.")
		var grid = GridContainer.new()
		grid.columns = 3
		avatar_container.add_child(grid)

		var placeholder_paths = _generate_placeholders()
		for path in placeholder_paths:
			var button = TextureButton.new()
			var img = Image.new()
			img.load(path)
			var tex = ImageTexture.new()
			tex.create_from_image(img)
			button.set_normal_texture(tex)
			button.set_custom_minimum_size(Vector2(150, 150))
			button.set_ignore_texture_size(true)
			grid.add_child(button)
			button.connect("pressed", self, "_on_placeholder_selected", [path])

	var skip_button = Button.new()
	skip_button.text = "Skip"
	avatar_container.add_child(skip_button)
	skip_button.connect("pressed", self, "_on_skip_avatar_pressed")

func _generate_placeholders():
	print("[Login.gd] _generate_placeholders: Generating 9 placeholder images.")
	var placeholder_paths = []
	var colors = [
		Color.palevioletred, Color.seagreen, Color.steelblue,
		Color.khaki, Color.mediumpurple, Color.salmon,
		Color.lightskyblue, Color.sandybrown, Color.lightgreen
	]
	for i in range(9):
		var img = Image.new()
		img.create(150, 150, false, Image.FORMAT_RGB8)
		img.fill(colors[i])
		var path = "user://placeholder_avatar_" + str(i) + ".png"
		var err = img.save_png(path)
		if err == OK:
			placeholder_paths.append(path)
	return placeholder_paths

func _on_placeholder_selected(path):
	print("[Login.gd] _on_placeholder_selected: Placeholder selected: " + path)
	_on_avatar_processed(path)

func _on_gallery_pressed():
	print("[Login.gd] _on_gallery_pressed: Gallery button pressed.")
	if Engine.has_singleton("GodotGetImage"):
		get_node("/root/GodotGetImage").getGalleryImage()
	else:
		print("[Login.gd] _on_gallery_pressed: GodotGetImage plugin not found. Skipping.")
		_on_avatar_processed(null)

func _on_camera_pressed():
	print("[Login.gd] _on_camera_pressed: Camera button pressed.")
	if Engine.has_singleton("GodotGetImage"):
		get_node("/root/GodotGetImage").getCameraImage()
	else:
		print("[Login.gd] _on_camera_pressed: GodotGetImage plugin not found. Skipping.")
		_on_avatar_processed(null)

func _on_skip_avatar_pressed():
	print("[Login.gd] _on_skip_avatar_pressed: Skip button pressed.")
	_on_avatar_processed(null)

func _on_image_selected(path):
	print("[Login.gd] _on_image_selected: Image selected from native picker: " + path)
	var img = Image.new()
	var err = img.load(path)
	if err != OK:
		print("[Login.gd] _on_image_selected: Error loading image.")
		_on_avatar_processed(null)
		return

	var crop_size = min(img.get_width(), img.get_height())
	var x = int((img.get_width() - crop_size) / 2)
	var y = int((img.get_height() - crop_size) / 2)
	var region = Rect2(x, y, int(crop_size), int(crop_size))
	var cropped_img = img.get_rect(region)

	cropped_img.resize(150, 150)

	var save_path = "user://avatar.png"
	err = cropped_img.save_png(save_path)
	if err != OK:
		print("[Login.gd] _on_image_selected: Error saving avatar.")
		_on_avatar_processed(null)
		return

	print("[Login.gd] _on_image_selected: Avatar processed and saved to " + save_path)
	_on_avatar_processed(save_path)

func _on_avatar_picker_cancelled():
	print("[Login.gd] _on_avatar_picker_cancelled: Avatar selection cancelled.")
	_on_avatar_processed(null)

func _on_avatar_processed(avatar_path = null):
	if avatar_path != null and str(avatar_path) != "":
		print("[Login.gd] _on_avatar_processed: Processing with avatar path: " + str(avatar_path))
		PlayerManager.player_data["avatar"] = avatar_path
		SaveManager.save_player(PlayerManager.player_data)
	else:
		print("[Login.gd] _on_avatar_processed: No avatar path provided, skipping.")

	if is_instance_valid(avatar_container):
		avatar_container.queue_free()
	
	$CenterContainer.visible = true
	status_label.text = ""
	status_label.visible = false

	print("[Login.gd] _on_avatar_processed: Changing to Menu scene.")
	get_tree().change_scene("res://Scenes/Menu.tscn")

func _setup_web_oauth():
	var provider = firebase.Auth.get_GoogleProvider()
	provider.should_exchange = false
	provider.params.response_type = "token"
	if _web_client_id != null and _web_client_id != "":
		provider.set_client_id(_web_client_id)
		provider.set_client_secret("")
	if OS.has_feature("JavaScript"):
		var redirect = JavaScript.eval("location.origin + location.pathname")
		if redirect:
			firebase.Auth.set_redirect_uri(str(redirect))
	return provider

func _read_env_value(key):
	var cfg = ConfigFile.new()
	var err = cfg.load("res://addons/godot-firebase/.env")
	if err != OK:
		err = cfg.load("res://addons/godot-firebase/.env.public")
	if err == OK:
		return str(cfg.get_value("firebase/environment_variables", key, ""))
	return ""

func _begin_auth(message):
	print("[Login.gd] _begin_auth: " + message)
	auth_in_progress = true
	cancel_requested = false
	status_label.text = message
	cancel_button.visible = true
	_set_ui_enabled(false)

func _end_auth():
	print("[Login.gd] _end_auth: Ending auth process.")
	auth_in_progress = false
	cancel_button.visible = false
	_set_ui_enabled(true)

func _set_ui_enabled(enabled):
	if login_button:
		login_button.disabled = not enabled
	if google_login_button:
		google_login_button.disabled = not enabled
	if name_edit:
		name_edit.editable = enabled
	if remember_check:
		remember_check.disabled = not enabled

func _load_local_name():
	var data = SaveManager.load_player()
	if typeof(data) == TYPE_DICTIONARY and data.has("player_name"):
		var player_name = data["player_name"]
		if player_name != null and player_name != "":
			name_edit.text = player_name
		PlayerManager.player_data = data
		return
	var cfg = ConfigFile.new()
	var err = cfg.load("user://player.cfg")
	if err == OK:
		var n = cfg.get_value("player", "name", "")
		if typeof(n) == TYPE_STRING and n != "":
			name_edit.text = n
			PlayerManager.player_data["player_name"] = n
			SaveManager.save_player(PlayerManager.player_data)

func _save_local_name(n):
	var cfg = ConfigFile.new()
	cfg.set_value("player", "name", n)
	cfg.save("user://player.cfg")
