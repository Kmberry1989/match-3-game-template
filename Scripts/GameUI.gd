extends Control

@onready var player_name_label: Label = $MarginContainer/HBoxContainer/PlayerInfo/HBox/AvatarFrame/PlayerNameLabel as Label
@onready var level_label: Label = $MarginContainer/HBoxContainer/PlayerInfo/HBox/AvatarFrame/LevelLabel as Label
@onready var xp_label: Label = $MarginContainer/HBoxContainer/PlayerInfo/HBox/AvatarFrame/XpLabel as Label
@onready var coins_label: Label = $MarginContainer/HBoxContainer/PlayerInfo/HBox/AvatarFrame/CoinsLabel as Label
# Pause button is looked up safely at runtime to avoid errors when missing
@onready var frame_sprite: Sprite2D = $MarginContainer/HBoxContainer/PlayerInfo/HBox/AvatarFrame/AvatarFrame2 as Sprite2D
var _avatar_photo: Sprite2D = null

# MEANER METER UI reference
var _meaner_bar: ProgressBar = null
var _meaner_label: Label = null

func _ready():
	set_player_name(PlayerManager.get_player_name())
	update_level_label(PlayerManager.get_current_level())
	update_xp_label()
	PlayerManager.level_up.connect(update_level_label)
	PlayerManager.coins_changed.connect(_on_coins_changed)
	PlayerManager.frame_changed.connect(_on_frame_changed)
	_on_coins_changed(PlayerManager.get_coins())
	_apply_current_frame()
	# Add a subtle gold border overlay around the screen while in-game
	_add_gold_border()
	# Add MEANER METER UI and connect signals
	_add_meaner_meter_ui()
	if not PlayerManager.meaner_meter_changed.is_connected(Callable(self, "_on_meaner_meter_changed")):
		PlayerManager.meaner_meter_changed.connect(Callable(self, "_on_meaner_meter_changed"))
	if not PlayerManager.meaner_meter_filled.is_connected(Callable(self, "_on_meaner_meter_filled")):
		PlayerManager.meaner_meter_filled.connect(Callable(self, "_on_meaner_meter_filled"))
	# Initialize bar to current value
	_on_meaner_meter_changed(PlayerManager.get_meaner_meter_current(), PlayerManager.get_meaner_meter_max())
	# Ensure pause/home/shop buttons are clickable above other UI (guard if not found)
	_wire_button("PauseButton", Callable(self, "_on_pause_pressed"))
	_wire_button("HomeButton", Callable(self, "_on_home_pressed"))
	_wire_button("ShopButton", Callable(self, "_on_shop_pressed"))
	# React to avatar changes
	if PlayerManager.has_signal("avatar_changed") and not PlayerManager.avatar_changed.is_connected(Callable(self, "_on_avatar_changed")):
		PlayerManager.avatar_changed.connect(Callable(self, "_on_avatar_changed"))

func set_player_name(p_name: String) -> void:
	player_name_label.text = p_name

func update_level_label(level: int) -> void:
	level_label.text = "Level: " + str(level)

func update_xp_label() -> void:
	var current_xp: int = PlayerManager.get_current_xp()
	var xp_needed: int = PlayerManager.get_xp_for_next_level()
	xp_label.text = "XP: " + str(current_xp) + "/" + str(xp_needed)

func _on_coins_changed(new_amount: int) -> void:
	coins_label.text = "Coins: " + str(new_amount)

func _on_frame_changed(_frame_name: String) -> void:
	_apply_current_frame()

func _apply_current_frame() -> void:
	var frame_name: String = PlayerManager.get_current_frame()
	var tex_path: String = _frame_to_texture_path(frame_name)
	var tex: Texture2D = load(tex_path) as Texture2D
	if tex:
		frame_sprite.texture = tex
		frame_sprite.z_index = 1000
		_fit_sprite_to_height(frame_sprite, 160.0)
		_update_avatar_photo()

func _frame_to_texture_path(frame_name: String) -> String:
	if frame_name == "default":
		# Use an existing avatar frame as the default visual now that frame_standard.png is removed
		return "res://Assets/Visuals/avatar_frame_2.png"
	# e.g., frame_2 -> avatar_frame_2.png
	return "res://Assets/Visuals/" + "avatar_" + frame_name + ".png"

func _fit_sprite_to_height(sprite: Sprite2D, target_h: float) -> void:
	if sprite.texture == null:
		return
	var h: float = float(sprite.texture.get_height())
	if h <= 0.0:
		return
	# Do not upscale frames; only downscale if larger than target height
	var sf: float = target_h / h
	if sf > 1.0:
		sf = 1.0
	sprite.scale = Vector2(sf, sf)

func _ensure_avatar_photo_node() -> void:
	if _avatar_photo != null and is_instance_valid(_avatar_photo):
		return
	var parent_node: Node = frame_sprite.get_parent()
	if parent_node == null:
		return
	var existing: Node = parent_node.get_node_or_null("AvatarPhoto")
	if existing != null and existing is Sprite2D:
		_avatar_photo = existing as Sprite2D
		return
	_avatar_photo = Sprite2D.new()
	_avatar_photo.name = "AvatarPhoto"
	_avatar_photo.z_index = max(frame_sprite.z_index - 1, -100)
	_avatar_photo.position = frame_sprite.position
	parent_node.add_child(_avatar_photo)

func _update_avatar_photo() -> void:
	_ensure_avatar_photo_node()
	if _avatar_photo == null:
		return
	var path: String = "user://avatars/" + PlayerManager.get_player_name() + ".png"
	var tex: Texture2D = null
	if ResourceLoader.exists(path):
		tex = load(path) as Texture2D
	_avatar_photo.texture = tex
	if tex != null:
		# Fit just inside the frame so it doesn't get blocked too much
		_fit_sprite_to_height(_avatar_photo, 150.0)
		_avatar_photo.visible = true
	else:
		_avatar_photo.visible = false

func _on_pause_pressed() -> void:
	var root: Node = get_tree().get_current_scene()
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

	var existing: Node = layer.get_node_or_null("PauseMenu")
	if existing != null:
		if existing.has_method("show_menu"):
			existing.call("show_menu")
		return
	var pause_menu: Node = preload("res://Scenes/PauseMenu.tscn").instantiate()
	pause_menu.name = "PauseMenu"
	layer.add_child(pause_menu)
	if pause_menu.has_method("show_menu"):
		pause_menu.call("show_menu")

func _unhandled_input(event: InputEvent) -> void:
	# Fallback: allow Esc/back to open pause
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			_on_pause_pressed()

func get_xp_anchor_pos() -> Vector2:
	if is_instance_valid(xp_label):
		return xp_label.get_global_transform().origin
	return Vector2.ZERO

func _wire_button(node_name: String, handler: Callable) -> void:
	var n: Node = get_node_or_null(node_name)
	if n == null:
		n = find_child(node_name, true, false)
	var c: Control = n as Control
	if c != null:
		c.z_index = 1000
		c.mouse_filter = Control.MOUSE_FILTER_STOP
	var b: Button = n as Button
	if b != null and not b.is_connected("pressed", handler):
		b.connect("pressed", handler)

func _on_home_pressed() -> void:
	if AudioManager != null:
		AudioManager.play_sound("ui_click")
	get_tree().change_scene_to_file("res://Scenes/Menu.tscn")

func _on_shop_pressed() -> void:
	if AudioManager != null:
		AudioManager.play_sound("ui_click")
	get_tree().change_scene_to_file("res://Scenes/Shop.tscn")

# MEANER METER: when filled, show the bonus slot
func _on_meaner_meter_filled() -> void:
	# Instead of showing the BonusSlotMachine, trigger an in-place grid animation for now.
	var root: Node = get_tree().get_current_scene()
	if root == null:
		return
	var grid: Node = root.get_node_or_null("Grid")
	if grid != null and grid.has_method("trigger_meaner_animation"):
		grid.call_deferred("trigger_meaner_animation")
	else:
		# Fallback: if grid not found, still try to show the bonus slot
		_show_bonus_slot()

func _ensure_canvas_layer() -> CanvasLayer:
	var root: Node = get_tree().get_current_scene()
	if root == null:
		return null
	var layer: Node = root.get_node_or_null("CanvasLayer")
	if layer == null:
		layer = root.find_child("CanvasLayer", true, false)
	if layer == null:
		layer = CanvasLayer.new()
		layer.name = "CanvasLayer"
		root.add_child(layer)
	return layer as CanvasLayer

func _show_bonus_slot() -> void:
	var layer: CanvasLayer = _ensure_canvas_layer()
	if layer == null:
		return
	var existing: Node = layer.get_node_or_null("BonusSlot")
	if existing != null:
		return
	var slot_scene: PackedScene = preload("res://Scenes/BonusSlotMachine.tscn")
	var slot: Node = slot_scene.instantiate()
	# Safety: ensure the correct script is attached in case the scene was saved with a wrong script
	var expected_script_path: String = "res://Scripts/BonusSlotMachine.gd"
	# Force-attach the correct script to avoid stale/cached wrong scripts
	slot.set_script(load(expected_script_path))
	slot.name = "BonusSlot"
	if slot.has_signal("finished"):
		slot.connect("finished", Callable(self, "_on_bonus_slot_closed"))
	layer.add_child(slot)

func _on_bonus_slot_closed() -> void:
	# Reset the meter after the bonus has been played
	PlayerManager.reset_meaner_meter()
	# Track frequent flyer achievement progress
	if PlayerManager != null and PlayerManager.has_method("increment_bonus_spins"):
		PlayerManager.increment_bonus_spins()

func _on_meaner_meter_changed(cur: int, mx: int) -> void:
	if _meaner_bar != null:
		_meaner_bar.max_value = float(mx)
		_meaner_bar.value = float(cur)
	# Gauge already conveys percentage; keep label simple
	if _meaner_label != null:
		_meaner_label.text = "MEANER METER"

func _add_meaner_meter_ui() -> void:
	# Avoid duplicates
	if get_node_or_null("MeanerMeterPanel") != null:
		return
	var panel: Panel = Panel.new()
	panel.name = "MeanerMeterPanel"
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.z_index = 1004
	# Top-center anchored bar
	panel.anchor_left = 0.5
	panel.anchor_top = 0.0
	panel.anchor_right = 0.5
	panel.anchor_bottom = 0.0
	panel.offset_left = -220.0
	panel.offset_right = 220.0
	panel.offset_top = 10.0
	panel.offset_bottom = 80.0
	var psb: StyleBoxFlat = StyleBoxFlat.new()
	psb.bg_color = Color(0, 0, 0, 0.4)
	psb.border_color = Color(1.0, 0.84, 0.0, 1.0)
	psb.border_width_top = 2
	psb.border_width_bottom = 2
	psb.border_width_left = 2
	psb.border_width_right = 2
	psb.corner_radius_top_left = 10
	psb.corner_radius_top_right = 10
	psb.corner_radius_bottom_left = 10
	psb.corner_radius_bottom_right = 10
	panel.add_theme_stylebox_override("panel", psb)
	add_child(panel)

	var vb: VBoxContainer = VBoxContainer.new()
	vb.anchor_left = 0
	vb.anchor_top = 0
	vb.anchor_right = 1
	vb.anchor_bottom = 1
	vb.offset_left = 10
	vb.offset_top = 6
	vb.offset_right = -10
	vb.offset_bottom = -6
	panel.add_child(vb)

	var lbl: Label = Label.new()
	lbl.text = "MEANER METER:"
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 18)
	vb.add_child(lbl)
	_meaner_label = lbl

	var pb: ProgressBar = ProgressBar.new()
	pb.min_value = 0
	pb.max_value = 100
	pb.value = 0
	pb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# Style the fill and background for visibility
	var sb_bg: StyleBoxFlat = StyleBoxFlat.new()
	sb_bg.bg_color = Color(0.1, 0.1, 0.1, 0.9)
	pb.add_theme_stylebox_override("background", sb_bg)
	var sb_fill: StyleBoxFlat = StyleBoxFlat.new()
	sb_fill.bg_color = Color(1.0, 0.84, 0.0, 1.0)
	pb.add_theme_stylebox_override("fill", sb_fill)
	vb.add_child(pb)
	_meaner_bar = pb

# Adds a gold border to the outside edge of the display.
# Implemented as a full-screen Panel with a StyleBoxFlat border.
func _add_gold_border() -> void:
	# Avoid duplicates if _ready is called again
	var existing: Node = get_node_or_null("GoldBorderPanel")
	if existing != null:
		return
	var panel: Panel = Panel.new()
	panel.name = "GoldBorderPanel"
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.z_index = 1000
	# Full-rect anchors
	panel.anchor_left = 0.0
	panel.anchor_top = 0.0
	panel.anchor_right = 1.0
	panel.anchor_bottom = 1.0
	panel.offset_left = 0.0
	panel.offset_top = 0.0
	panel.offset_right = 0.0
	panel.offset_bottom = 0.0
	# Gold-looking color and thickness
	var border_thickness: int = 8
	var gold: Color = Color(1.0, 0.84, 0.0, 1.0)
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0) # transparent center
	sb.border_color = gold
	sb.border_width_top = border_thickness
	sb.border_width_bottom = border_thickness
	sb.border_width_left = border_thickness
	sb.border_width_right = border_thickness
	# Optional rounded corners for a polished look
	sb.corner_radius_top_left = 10
	sb.corner_radius_top_right = 10
	sb.corner_radius_bottom_left = 10
	sb.corner_radius_bottom_right = 10
	panel.add_theme_stylebox_override("panel", sb)
	add_child(panel)

	# Very thin black inside stroke around the inner edge of the gold border
	var inner: Panel = Panel.new()
	inner.name = "GoldBorderInnerStroke"
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.z_index = 1001
	# Anchor full, then inset by the gold thickness so the stroke hugs the inner edge
	inner.anchor_left = 0.0
	inner.anchor_top = 0.0
	inner.anchor_right = 1.0
	inner.anchor_bottom = 1.0
	inner.offset_left = border_thickness
	inner.offset_top = border_thickness
	inner.offset_right = -border_thickness
	inner.offset_bottom = -border_thickness
	var inner_sb: StyleBoxFlat = StyleBoxFlat.new()
	inner_sb.bg_color = Color(0, 0, 0, 0)
	inner_sb.border_color = Color(0, 0, 0, 1)
	# Thicker inner stroke
	var inner_w: int = 3
	inner_sb.border_width_top = inner_w
	inner_sb.border_width_bottom = inner_w
	inner_sb.border_width_left = inner_w
	inner_sb.border_width_right = inner_w
	# Match corner radius to sit inside the outer radius
	# Rounder inner corners to better match the outer border
	var inner_radius: int = 8
	inner_sb.corner_radius_top_left = inner_radius
	inner_sb.corner_radius_top_right = inner_radius
	inner_sb.corner_radius_bottom_left = inner_radius
	inner_sb.corner_radius_bottom_right = inner_radius
	inner.add_theme_stylebox_override("panel", inner_sb)
	panel.add_child(inner)

	# Gold border gradient: fade from gold at the outer edge to white toward the inner edge
	var grad: ColorRect = ColorRect.new()
	grad.name = "GoldBorderGradient"
	grad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Place above panel and stroke; will not cover stroke due to inner cut below
	grad.z_index = 1003
	grad.anchor_left = 0.0
	grad.anchor_top = 0.0
	grad.anchor_right = 1.0
	grad.anchor_bottom = 1.0
	grad.offset_left = 0.0
	grad.offset_top = 0.0
	grad.offset_right = 0.0
	grad.offset_bottom = 0.0
	var min_dim: float = min(get_viewport().get_visible_rect().size.x, get_viewport().get_visible_rect().size.y)
	var thickness_norm: float = 0.06
	var inner_cut_norm: float = 0.0
	if min_dim > 0.0:
		thickness_norm = float(border_thickness) / min_dim
		inner_cut_norm = float(inner_w) / min_dim
	var gsh: Shader = Shader.new()
	gsh.code = "shader_type canvas_item;\n"
	gsh.code += "uniform float thickness = 0.06;\n"
	gsh.code += "uniform float inner_cut = 0.0;\n"
	gsh.code += "uniform vec4 outer_color : source_color = vec4(1.0, 0.84, 0.0, 1.0);\n"
	gsh.code += "uniform vec4 inner_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);\n"
	gsh.code += "void fragment() {\n"
	gsh.code += "    vec2 uv = UV;\n"
	gsh.code += "    float d = min(min(uv.x, 1.0 - uv.x), min(uv.y, 1.0 - uv.y));\n"
	gsh.code += "    float usable = max(thickness - inner_cut, 0.0);\n"
	gsh.code += "    float a = step(d, usable);\n"
	gsh.code += "    float denom = max(usable, 1e-6);\n"
	gsh.code += "    float t = clamp(d / denom, 0.0, 1.0);\n"
	gsh.code += "    vec4 col = mix(outer_color, inner_color, t);\n"
	gsh.code += "    COLOR = vec4(col.rgb, col.a * a);\n"
	gsh.code += "}\n"
	var gmat: ShaderMaterial = ShaderMaterial.new()
	gmat.shader = gsh
	gmat.set_shader_parameter("thickness", thickness_norm)
	gmat.set_shader_parameter("inner_cut", inner_cut_norm)
	gmat.set_shader_parameter("outer_color", gold)
	gmat.set_shader_parameter("inner_color", Color(1, 1, 1, 1))
	grad.material = gmat
	panel.add_child(grad)

	# Subtle black inner glow vignette inside the inner stroke
	var glow: ColorRect = ColorRect.new()
	glow.name = "GoldBorderInnerGlow"
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	glow.z_index = 1002
	# Inset so the glow starts at the inner stroke edge
	glow.anchor_left = 0.0
	glow.anchor_top = 0.0
	glow.anchor_right = 1.0
	glow.anchor_bottom = 1.0
	var inset: float = float(border_thickness + inner_w)
	glow.offset_left = inset
	glow.offset_top = inset
	glow.offset_right = -inset
	glow.offset_bottom = -inset
	# CanvasItem shader to draw a soft inner black glow using UV distance to edges
	var sh: Shader = Shader.new()
	sh.code = "shader_type canvas_item;\n"
	sh.code += "uniform float thickness : hint_range(0.0, 0.2) = 0.03;\n"
	sh.code += "uniform float strength : hint_range(0.0, 1.0) = 0.5;\n"
	sh.code += "void fragment() {\n"
	sh.code += "    vec2 uv = UV;\n"
	sh.code += "    float d = min(min(uv.x, 1.0 - uv.x), min(uv.y, 1.0 - uv.y));\n"
	sh.code += "    float a = smoothstep(thickness, 0.0, d) * strength;\n"
	sh.code += "    COLOR = vec4(0.0, 0.0, 0.0, a);\n"
	sh.code += "}\n"
	var mat: ShaderMaterial = ShaderMaterial.new()
	mat.shader = sh
	mat.set_shader_parameter("thickness", 0.03)
	mat.set_shader_parameter("strength", 0.5)
	glow.material = mat
	panel.add_child(glow)
