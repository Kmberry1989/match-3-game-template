extends Control

onready var status_label = $Panel/VBox/Status
onready var btn_find_match = $Panel/VBox/Buttons/FindMatch
onready var btn_cancel_match = $Panel/VBox/Buttons/CancelMatch
onready var btn_leave = $Panel/VBox/Buttons/Leave
onready var btn_ready = $Panel/VBox/Buttons/Ready
onready var btn_start = $Panel/VBox/Buttons/Start
onready var mode_opt = $Panel/VBox/ModeHBox/Mode
onready var target_spin = $Panel/VBox/TargetHBox/Target

var _joined = false
var _finding_match = false

func _ready():
	var url = ProjectSettings.get_setting("simple_multiplayer/server_url", "ws://127.0.0.1:9090")
	$Panel/VBox/Url.text = "Server: " + url
	_wire_buttons()
	_update_buttons()
	if Engine.has_singleton("WebSocketClient"):
		WebSocketClient.connect("connection_succeeded", self, "_on_connected")
		WebSocketClient.connect("connection_failed", self, "_on_connection_failed")
		WebSocketClient.connect("disconnected", self, "_on_disconnected")
		WebSocketClient.connect("room_joined", self, "_on_room_joined")
		WebSocketClient.connect("start_game", self, "_on_start_game")
		WebSocketClient.connect("match_found", self, "_on_match_found")

	var return_button = Button.new()
	return_button.text = "Return to Main Menu"
	$Panel/VBox.add_child(return_button)
	return_button.connect("pressed", self, "_on_return_to_menu_pressed")

func _on_return_to_menu_pressed():
	if _joined:
		WebSocketClient.leave_room()
	
	if WebSocketClient.is_ws_connected():
		WebSocketClient.disconnect_from_server()

	get_tree().change_scene("res://Scenes/Menu.tscn")

func _wire_buttons():
	btn_find_match.connect("pressed", self, "_on_find_match")
	btn_cancel_match.connect("pressed", self, "_on_cancel_match")
	btn_leave.connect("pressed", self, "_on_leave")
	btn_ready.connect("pressed", self, "_on_ready")
	btn_start.connect("pressed", self, "_on_start")

func _update_buttons():
	btn_find_match.disabled = _finding_match or _joined
	btn_cancel_match.disabled = not _finding_match
	btn_leave.disabled = not _joined
	btn_ready.disabled = not _joined
	btn_start.disabled = not _joined

func _on_connected():
	status_label.text = "Connected."

func _on_connection_failed():
	status_label.text = "Failed to connect."

func _on_disconnected():
	status_label.text = "Disconnected."
	_joined = false
	_finding_match = false
	_update_buttons()

func _on_find_match():
	_finding_match = true
	_update_buttons()
	var m = mode_opt.get_selected_id()
	var mode = ("vs" if m == 1 else "coop")
	WebSocketClient.find_match({"mode": mode})
	status_label.text = "Finding match..."

func _on_cancel_match():
	_finding_match = false
	_update_buttons()
	WebSocketClient.cancel_match()
	status_label.text = "Matchmaking canceled."

func _on_leave():
	WebSocketClient.leave_room()
	status_label.text = "Left room."
	_joined = false
	_update_buttons()

func _on_ready():
	WebSocketClient.send_ready()
	status_label.text = "Ready. Waiting for others..."

func _on_start():
	var m = mode_opt.get_selected_id()
	var mode = ("vs" if m == 1 else "coop")
	var target = int(target_spin.value)
	var seed_value = int(OS.get_unix_time())
	WebSocketClient.request_start_game({"mode": mode, "target": target, "seed": seed_value})
	status_label.text = "Starting (" + mode + ")..."

func _on_match_found(code, player_id):
	_on_room_joined(code, player_id)

func _on_room_joined(code, _id):
	status_label.text = "Joined room: " + code
	_joined = true
	_finding_match = false
	_update_buttons()

func _on_start_game():
	status_label.text = "Game starting..."
	get_tree().change_scene("res://Scenes/Game.tscn")
