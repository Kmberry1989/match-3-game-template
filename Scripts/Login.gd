extends Control

@onready var name_edit = $CenterContainer/VBoxContainer/NameEdit
@onready var login_button = $CenterContainer/VBoxContainer/LoginButton
@onready var google_login_button = $CenterContainer/VBoxContainer/GoogleLoginButton
@onready var remember_check: CheckBox = $CenterContainer/VBoxContainer/RememberCheck
@onready var status_label: Label = $CenterContainer/VBoxContainer/StatusLabel
@onready var cancel_button: Button = $CenterContainer/VBoxContainer/CancelButton
@onready var firebase = get_node_or_null("/root/Firebase")

var auth_in_progress: bool = false
var cancel_requested: bool = false
var _web_client_id: String = ""

func _ready():
	login_button.connect("pressed", Callable(self, "_on_login_pressed"))
	google_login_button.connect("pressed", Callable(self, "_on_google_login_pressed"))
	cancel_button.connect("pressed", Callable(self, "_on_cancel_pressed"))
	_load_local_name()

	# Scale login buttons and input fields to 2x for better readability
	var scale_factor := 2.0
	var to_scale: Array = [name_edit, login_button, google_login_button, cancel_button, remember_check]
	for c in to_scale:
		if c != null:
			c.scale = Vector2(scale_factor, scale_factor)

	# Play login music on the login screen
	if AudioManager != null:
		AudioManager.play_music("login")
	
	# Check if Firebase is available (autoload singleton present)
	if firebase == null:
		print("Firebase plugin not found. Please install and enable it.")
		google_login_button.disabled = true
		google_login_button.visible = false
		return

	# Show Google login if Firebase is available
	google_login_button.visible = true
	# Connect correct Firebase Auth signals for GodotFirebase
	firebase.Auth.login_succeeded.connect(Callable(self, "_on_authentication_succeeded"))
	firebase.Auth.login_failed.connect(Callable(self, "_on_authentication_failed"))
	firebase.Auth.logged_out.connect(Callable(self, "_on_logged_out"))
	_web_client_id = _read_env_value("webClientId")

	# Web: handle return from provider redirect (token in URL)
	if OS.has_feature("web"):
		var provider = _setup_web_oauth()
		var token = firebase.Auth.get_token_from_url(provider)
		if token != null and str(token) != "":
			_begin_auth("Signing in...")
			firebase.Auth.login_with_oauth(token, provider)
	else:
		# Attempt automatic sign-in if a saved auth file exists (not supported on web)
		# Guard the call to avoid the plugin printing an error when the file doesn't exist
		if FileAccess.file_exists("user://user.auth"):
			if firebase.Auth.check_auth_file():
				_begin_auth("Signing in...")

func _on_login_pressed():
	if auth_in_progress:
		return
	var player_name = name_edit.text.strip_edges()
	# If empty, default to Guest
	if player_name == "":
		player_name = "Guest"
	# Offline/local name login: store name directly and continue
	status_label.text = "Saving..."
	_save_local_name(player_name)
	PlayerManager.player_data["player_name"] = player_name
	get_tree().change_scene_to_file("res://Scenes/Menu.tscn")

func _on_google_login_pressed():
	if auth_in_progress:
		return
	if firebase != null:
		_begin_auth("Signing in...")
		if OS.has_feature("web"):
			var provider = _setup_web_oauth()
			# Redirect browser for OAuth (returns to this same page)
			firebase.Auth.get_auth_with_redirect(provider)
		else:
			# Desktop/native: use localhost capture
			firebase.Auth.get_auth_localhost()

func _on_authentication_succeeded(auth_data):
	print("Firebase authentication succeeded!")
	if cancel_requested:
		# User chose to cancel while auth was in flight; revert and stay on login
		cancel_requested = false
		_end_auth()
		status_label.text = "Canceled"
		if firebase != null and firebase.Auth.is_logged_in():
			firebase.Auth.logout()
		return
	# Persist auth if requested
	if (remember_check == null or remember_check.button_pressed) and not OS.has_feature("web"):
		status_label.text = "Saving..."
		firebase.Auth.save_auth(auth_data)
	PlayerManager.load_player_data(auth_data)
	get_tree().change_scene_to_file("res://Scenes/Menu.tscn")

func _on_authentication_failed(code, message):
	var msg = "Firebase authentication failed: " + str(code) + ": " + str(message)
	print(msg)
	status_label.text = msg
	_end_auth()

func _on_logged_out():
	print("Logged out.")
	_end_auth()

func _on_cancel_pressed():
	cancel_requested = true
	auth_in_progress = false
	cancel_button.visible = false
	status_label.text = "Canceling..."
	if firebase != null:
		# Remove saved auth to prevent auto-login and logout to clear any session
		firebase.Auth.remove_auth()
		if firebase.Auth.is_logged_in():
			firebase.Auth.logout()
	_end_auth()

func _setup_web_oauth():
	var provider = firebase.Auth.get_GoogleProvider()
	# Avoid code exchange (no client secret in browser); use implicit token
	provider.should_exchange = false
	provider.params.response_type = "token"
	# If a WEB client ID is provided in .env, prefer it on HTML5
	if _web_client_id != null and _web_client_id != "":
		provider.set_client_id(_web_client_id)
		provider.set_client_secret("")
	if OS.has_feature("JavaScript"):
		# Redirect back to current page (no query string)
		var redirect = JavaScriptBridge.eval("location.origin + location.pathname")
		firebase.Auth.set_redirect_uri(str(redirect))
	return provider

func _read_env_value(key: String) -> String:
	var cfg := ConfigFile.new()
	var err := cfg.load("res://addons/godot-firebase/.env")
	if err != OK:
		# Fallback to public env on Web exports
		err = cfg.load("res://addons/godot-firebase/.env.public")
	if err == OK:
		return str(cfg.get_value("firebase/environment_variables", key, ""))
	return ""

func _begin_auth(message: String):
	auth_in_progress = true
	cancel_requested = false
	status_label.text = message
	cancel_button.visible = true
	_set_ui_enabled(false)

func _end_auth():
	auth_in_progress = false
	cancel_button.visible = false
	_set_ui_enabled(true)

func _set_ui_enabled(enabled: bool):
	if login_button:
		login_button.disabled = not enabled
	if google_login_button:
		google_login_button.disabled = not enabled
	if name_edit:
		name_edit.editable = enabled
	if remember_check:
		remember_check.disabled = not enabled

func _load_local_name():
	var cfg = ConfigFile.new()
	var err = cfg.load("user://player.cfg")
	if err == OK:
		var n = cfg.get_value("player", "name", "")
		if typeof(n) == TYPE_STRING and n != "":
			name_edit.text = n

func _save_local_name(n: String):
	var cfg = ConfigFile.new()
	cfg.set_value("player", "name", n)
	cfg.save("user://player.cfg")
