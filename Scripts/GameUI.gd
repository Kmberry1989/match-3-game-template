extends Control

@onready var player_name_label = $MarginContainer/HBoxContainer/PlayerInfo/HBox/AvatarFrame/PlayerNameLabel
@onready var level_label = $MarginContainer/HBoxContainer/PlayerInfo/HBox/AvatarFrame/LevelLabel
@onready var xp_label = $MarginContainer/HBoxContainer/PlayerInfo/HBox/AvatarFrame/XpLabel
@onready var coins_label = $MarginContainer/HBoxContainer/PlayerInfo/HBox/AvatarFrame/CoinsLabel
@onready var pause_button = $PauseButton
@onready var frame_sprite = $MarginContainer/HBoxContainer/PlayerInfo/HBox/AvatarFrame/AvatarFrame2

func _ready():
	set_player_name(PlayerManager.get_player_name())
	update_level_label(PlayerManager.get_current_level())
	update_xp_label()
	PlayerManager.level_up.connect(update_level_label)
	PlayerManager.coins_changed.connect(_on_coins_changed)
	PlayerManager.frame_changed.connect(_on_frame_changed)
	_on_coins_changed(PlayerManager.get_coins())
	_apply_current_frame()
	pause_button.connect("pressed", Callable(self, "_on_pause_pressed"))

func set_player_name(p_name):
	player_name_label.text = p_name

func update_level_label(level):
	level_label.text = "Level: " + str(level)

func update_xp_label():
	var current_xp = PlayerManager.get_current_xp()
	var xp_needed = PlayerManager.get_xp_for_next_level()
	xp_label.text = "XP: " + str(current_xp) + "/" + str(xp_needed)

func _on_coins_changed(new_amount):
	coins_label.text = "Coins: " + str(new_amount)

func _on_frame_changed(_frame_name):
	_apply_current_frame()

func _apply_current_frame():
	var frame_name = PlayerManager.get_current_frame()
	var tex_path = _frame_to_texture_path(frame_name)
	var tex = load(tex_path)
	if tex:
		frame_sprite.texture = tex
		_fit_sprite_to_height(frame_sprite, 160.0)

func _frame_to_texture_path(frame_name: String) -> String:
	if frame_name == "default":
		# Use an existing avatar frame as the default visual now that frame_standard.png is removed
		return "res://Assets/Visuals/avatar_frame_2.png"
	# e.g., frame_2 -> avatar_frame_2.png
	return "res://Assets/Visuals/" + "avatar_" + frame_name + ".png"

func _fit_sprite_to_height(sprite: Sprite2D, target_h: float):
	if sprite.texture == null:
		return
	var h = float(sprite.texture.get_height())
	if h <= 0.0:
		return
	var sf = target_h / h
	sprite.scale = Vector2(sf, sf)

func _on_pause_pressed():
	var root = get_tree().get_current_scene()
	if root == null:
		return
	# Find or create the CanvasLayer to host overlays
	var layer: Node = root.get_node_or_null("CanvasLayer")
	if layer == null:
		layer = root.find_child("CanvasLayer", true, false)
	if layer == null:
		layer = CanvasLayer.new()
		layer.name = "CanvasLayer"
		root.add_child(layer)

	var existing = layer.get_node_or_null("PauseMenu")
	if existing:
		existing.show_menu()
		return
	var pause_menu = preload("res://Scenes/PauseMenu.tscn").instantiate()
	pause_menu.name = "PauseMenu"
	layer.add_child(pause_menu)
	pause_menu.show_menu()

func _unhandled_input(event):
	# Fallback: allow Esc/back to open pause
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			_on_pause_pressed()

func get_xp_anchor_pos() -> Vector2:
	return xp_label.get_global_transform().origin
