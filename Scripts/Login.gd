extends Control

@onready var name_edit = $CenterContainer/VBoxContainer/NameEdit
@onready var login_button = $CenterContainer/VBoxContainer/LoginButton
@onready var google_login_button = $CenterContainer/VBoxContainer/GoogleLoginButton

func _ready():
	login_button.connect("pressed", Callable(self, "_on_login_pressed"))
	google_login_button.connect("pressed", Callable(self, "_on_google_login_pressed"))

	# Check if Firebase is available (plugin is installed and enabled)
	if not Engine.has_singleton("Firebase"):
		print("Firebase plugin not found. Please install and enable it.")
		google_login_button.disabled = true
		return

	Firebase.Auth.authentication_succeeded.connect(Callable(self, "_on_authentication_succeeded"))
	Firebase.Auth.authentication_failed.connect(Callable(self, "_on_authentication_failed"))

func _on_login_pressed():
	var player_name = name_edit.text
	if player_name.strip_edges() != "":
		PlayerManager.load_player_data(player_name)
		get_tree().change_scene_to_file("res://Scenes/Menu.tscn")
	else:
		# Optional: Show an error message if the name is empty
		pass

func _on_google_login_pressed():
	if Engine.has_singleton("Firebase"):
		Firebase.Auth.signInWithGoogle()

func _on_authentication_succeeded(user_info):
	print("Firebase authentication succeeded!")
	PlayerManager.load_player_data(user_info)
	get_tree().change_scene_to_file("res://Scenes/Menu.tscn")

func _on_authentication_failed(error_message):
	print("Firebase authentication failed: " + error_message)