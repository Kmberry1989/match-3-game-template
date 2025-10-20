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

var _joined: bool = false

func _ready() -> void:
    var url: String = ProjectSettings.get_setting("simple_multiplayer/server_url", "ws://127.0.0.1:9090")
    url_label.text = "Server: " + url
    _wire_buttons()
    _update_buttons()
    if Engine.has_singleton("WebSocketClient") or (typeof(WebSocketClient) != TYPE_NIL):
        WebSocketClient.connection_succeeded.connect(_on_connected)
        WebSocketClient.connection_failed.connect(_on_connection_failed)
        WebSocketClient.disconnected.connect(_on_disconnected)
        WebSocketClient.room_created.connect(_on_room_created)
        WebSocketClient.room_joined.connect(_on_room_joined)
        WebSocketClient.start_game.connect(_on_start_game)

func _wire_buttons() -> void:
    btn_create.pressed.connect(_on_create)
    btn_join.pressed.connect(_on_join)
    btn_leave.pressed.connect(_on_leave)
    btn_ready.pressed.connect(_on_ready)
    btn_start.pressed.connect(_on_start)

func _update_buttons() -> void:
    btn_leave.disabled = not _joined
    btn_ready.disabled = not _joined
    btn_start.disabled = not _joined

func _on_connected() -> void:
    status_label.text = "Connected."

func _on_connection_failed() -> void:
    status_label.text = "Failed to connect."

func _on_disconnected() -> void:
    status_label.text = "Disconnected."
    _joined = false
    _update_buttons()

func _on_create() -> void:
    var c := code_edit.text.strip_edges().to_upper()
    if c == "":
        c = ""
    WebSocketClient.create_room(c)
    status_label.text = "Creating room..."

func _on_join() -> void:
    var c := code_edit.text.strip_edges().to_upper()
    if c == "":
        status_label.text = "Enter a room code."
        return
    WebSocketClient.join_room(c)
    status_label.text = "Joining room..."

func _on_leave() -> void:
    WebSocketClient.leave_room()
    status_label.text = "Left room."
    _joined = false
    _update_buttons()

func _on_ready() -> void:
    WebSocketClient.send_ready()
    status_label.text = "Ready. Waiting for others..."

func _on_start() -> void:
    var m := mode_opt.get_selected_id()
    var mode := ("vs" if m == 1 else "coop")
    var target := int(target_spin.value)
    var seed := int(Time.get_unix_time_from_system())
    WebSocketClient.request_start_game({"mode": mode, "target": target, "seed": seed})
    status_label.text = "Starting (" + mode + ")..."

func _on_room_created(code: String) -> void:
    code_edit.text = code
    status_label.text = "Room created: " + code

func _on_room_joined(code: String, _id: String) -> void:
    code_edit.text = code
    status_label.text = "Joined room: " + code
    _joined = true
    _update_buttons()

func _on_start_game() -> void:
    status_label.text = "Game starting..."
    # Transition to the actual game scene
    get_tree().change_scene_to_file("res://Scenes/Game.tscn")
