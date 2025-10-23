extends Control

@onready var code_edit: LineEdit = $Panel/VBox/CodeHBox/Code
@onready var url_label: Label = $Panel/VBox/Url
@onready var status_label: Label = $Panel/VBox/Status
@onready var btn_create: Button = $Panel/VBox/Buttons/Create
@onready var btn_join: Button = $Panel/VBox/Buttons/Join
@onready var btn_leave: Button = $Panel/VBox/Buttons/Leave
@onready var btn_ready: Button = $Panel/VBox/Buttons/Ready
@onready var btn_start: Button = $Panel/VBox/Buttons/Start
@onready var mode_opt: OptionButton = $Panel/VBox/ModeHBox/Mode
@onready var target_spin: SpinBox = $Panel/VBox/TargetHBox/Target
@onready var find_match_button: Button = Button.new()

var _joined: bool = false
var _is_host: bool = false

func _ready() -> void:
	var url: String = ProjectSettings.get_setting("simple_multiplayer/server_url", "ws://127.0.0.1:9090")
	url_label.text = "Server: " + url
	
	# Hide old UI
	$Panel/VBox/CodeHBox.hide()
	btn_create.hide()
	btn_join.hide()

	# Add new button
	find_match_button.text = "Find Match"
	$Panel/VBox/Buttons.add_child(find_match_button)

	_wire_buttons()
	_update_buttons()

	if Engine.has_singleton("WebSocketClient"):
		WebSocketClient.connection_succeeded.connect(_on_connected)
		WebSocketClient.connection_failed.connect(_on_connection_failed)
		WebSocketClient.disconnected.connect(_on_disconnected)
		WebSocketClient.room_joined.connect(_on_room_joined)
		WebSocketClient.start_game.connect(_on_start_game)
		WebSocketClient.waiting_for_match.connect(_on_waiting_for_match)

	var return_button = Button.new()
	return_button.text = "Return to Main Menu"
	$Panel/VBox.add_child(return_button)
	return_button.pressed.connect(_on_return_to_menu_pressed)

func _on_return_to_menu_pressed():
	if _joined:
		WebSocketClient.leave_room()
	
	if WebSocketClient.is_ws_connected():
		WebSocketClient.disconnect_from_server()

	get_tree().change_scene_to_file("res://Scenes/Menu.tscn")

func _wire_buttons() -> void:
	find_match_button.pressed.connect(_on_find_match_pressed)
	btn_leave.pressed.connect(_on_leave)
	btn_ready.pressed.connect(_on_ready)
	btn_start.pressed.connect(_on_start)

func _update_buttons() -> void:
	var is_connected = WebSocketClient.is_ws_connected() if Engine.has_singleton("WebSocketClient") else false
	find_match_button.disabled = not is_connected or _joined
	btn_leave.disabled = not _joined
	btn_ready.disabled = not _joined
	btn_start.disabled = not _joined or not _is_host
	$Panel/VBox/ModeHBox.visible = _is_host
	$Panel/VBox/TargetHBox.visible = _is_host

func _on_connected() -> void:
	status_label.text = "Connected. Click \"Find Match\" to start."
	_update_buttons()

func _on_find_match_pressed() -> void:
	if Engine.has_singleton("WebSocketClient"):
		WebSocketClient.find_match()
	status_label.text = "Finding match..."
	find_match_button.disabled = true

func _on_waiting_for_match() -> void:
	status_label.text = "Waiting for another player..."

func _on_connection_failed() -> void:
	status_label.text = "Failed to connect."

func _on_disconnected() -> void:
	status_label.text = "Disconnected."
	_joined = false
	_is_host = false
	_update_buttons()

func _on_leave() -> void:
	WebSocketClient.leave_room()
	status_label.text = "Left room."
	_joined = false
	_is_host = false
	_update_buttons()

func _on_ready() -> void:
	WebSocketClient.send_ready()
	status_label.text = "Ready. Waiting for others..."

func _on_start() -> void:
	var m := mode_opt.get_selected_id()
	var mode := ("vs" if m == 1 else "coop")
	var target := int(target_spin.value)
	var seed_value := int(Time.get_unix_time_from_system())
	WebSocketClient.request_start_game({"mode": mode, "target": target, "seed": seed_value})
	status_label.text = "Starting (" + mode + ")..."

func _on_room_joined(code: String, _id: String, is_host: bool) -> void:
	code_edit.text = code
	_joined = true
	_is_host = is_host
	if _is_host:
		status_label.text = "You are the host. Choose game mode and press Start."
	else:
		status_label.text = "Joined room. Waiting for host to start the game."
	_update_buttons()

func _on_start_game() -> void:
	status_label.text = "Game starting..."
	# Transition to the actual game scene
	get_tree().change_scene_to_file("res://Scenes/Game.tscn")