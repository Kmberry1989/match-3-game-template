extends Panel

@onready var tab_container := $VBoxContainer/TabContainer
@onready var trophy_grid := $VBoxContainer/TabContainer/Trophies/Scroll/TrophyGrid
@onready var frame_grid := $VBoxContainer/TabContainer/Frames/Scroll/FrameGrid
@onready var viewer_overlay := $ViewerOverlay
@onready var viewer_image := $ViewerOverlay/Center/VBox/LargeImage
@onready var viewer_label := $ViewerOverlay/Center/VBox/ItemLabel

const TROPHY_DIR := "res://Assets/Visuals/Trophies"
const VISUALS_DIR := "res://Assets/Visuals"

var trophies: Array = [] # [{id, path, texture, name, unlocked}]
var frames: Array = []   # [{id, path, texture, name, unlocked}]
var current_category: String = ""
var current_index: int = -1

var _drag_active := false
var _drag_start := Vector2.ZERO

func _ready():
	load_trophies()
	load_frames()

func load_trophies():
	trophies.clear()
	for child in trophy_grid.get_children():
		child.queue_free()
	var dir = DirAccess.open(TROPHY_DIR)
	if dir == null:
		return
	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and (file_name.to_lower().ends_with(".png") or file_name.to_lower().ends_with(".png.import")):
			var path = TROPHY_DIR.path_join(file_name)
			var tex: Texture2D = load(path)
			if tex:
				# Support both .png and .png.import entries
				var stem = file_name
				if stem.to_lower().ends_with(".import"):
					stem = stem.substr(0, stem.length() - ".import".length())
				var base: String = stem.get_basename() # removes .png
				var id: String = base
				var display: String = base.replace("trophy_", "").replace("_", " ").capitalize()
				var unlocked := false
				if typeof(PlayerManager.player_data) == TYPE_DICTIONARY:
					var unlocked_list: Array = PlayerManager.player_data.get("unlocks", {}).get("trophies", [])
					unlocked = unlocked_list.has(id)
				var item = {"id": id, "path": path, "texture": tex, "name": display, "unlocked": unlocked}
				var idx = trophies.size()
				trophies.append(item)
				_add_thumbnail(trophy_grid, tex, display, unlocked, func():
					_open_viewer("trophies", idx)
				)
		file_name = dir.get_next()
	dir.list_dir_end()

func load_frames():
	frames.clear()
	for child in frame_grid.get_children():
		child.queue_free()
	# Only list avatar_frame*.png; include both avatar_frame_*.png and avatar_frameNN.png
	var dir = DirAccess.open(VISUALS_DIR)
	if dir == null:
		return
	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.to_lower().ends_with(".png") and file_name.begins_with("avatar_frame"):
			var num_str: String = file_name
			# Accept both avatar_frame_2.png and avatar_frame10.png
			num_str = num_str.replace("avatar_frame_", "").replace("avatar_frame", "").trim_suffix(".png")
			var frame_name: String = "Frame " + num_str
			var path = VISUALS_DIR.path_join(file_name)
			var tex: Texture2D = load(path)
			if tex:
				var frame_id: String = "frame_" + num_str
				var unlocked := false
				if typeof(PlayerManager.player_data) == TYPE_DICTIONARY:
					var unlocked_frames: Array = PlayerManager.player_data.get("unlocks", {}).get("frames", [])
					unlocked = unlocked_frames.has(frame_id)
				var item = {"id": frame_id, "path": path, "texture": tex, "name": frame_name, "unlocked": unlocked}
				var idx = frames.size()
				frames.append(item)
				_add_thumbnail(frame_grid, tex, frame_name, unlocked, func():
					_open_viewer("frames", idx)
				)
		file_name = dir.get_next()
	dir.list_dir_end()

func _add_thumbnail(container: GridContainer, tex: Texture2D, label_text: String, unlocked: bool, on_click: Callable):
	var vb = VBoxContainer.new()
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var thumb = TextureRect.new()
	thumb.texture = tex
	thumb.custom_minimum_size = Vector2(128, 128)
	thumb.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	thumb.mouse_filter = Control.MOUSE_FILTER_STOP
	if not unlocked:
		thumb.modulate = Color(0.6, 0.6, 0.6, 1.0)
	thumb.gui_input.connect(func(event):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			on_click.call()
	)
	var lbl = Label.new()
	lbl.text = label_text + " - " + ("UNLOCKED" if unlocked else "LOCKED")
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(thumb)
	vb.add_child(lbl)
	container.add_child(vb)

func _open_viewer(category: String, index: int):
	current_category = category
	current_index = index
	_update_viewer()
	viewer_overlay.visible = true

func _close_viewer():
	viewer_overlay.visible = false
	current_category = ""
	current_index = -1

func _update_viewer():
	if current_index < 0:
		return
	var list = trophies if current_category == "trophies" else frames
	if current_index >= 0 and current_index < list.size():
		var item = list[current_index]
		viewer_image.texture = item["texture"]
		var unlocked := bool(item.get("unlocked", false))
		viewer_label.text = item["name"] + " - " + ("UNLOCKED" if unlocked else "LOCKED")

func _viewer_next():
	var list = trophies if current_category == "trophies" else frames
	if list.size() == 0:
		return
	current_index = (current_index + 1) % list.size()
	_update_viewer()

func _viewer_prev():
	var list = trophies if current_category == "trophies" else frames
	if list.size() == 0:
		return
	current_index = (current_index - 1 + list.size()) % list.size()
	_update_viewer()

func _input(event):
	if not viewer_overlay.visible:
		return
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_drag_active = true
				_drag_start = event.position
			else:
				if _drag_active:
					var delta = event.position - _drag_start
					_drag_active = false
					if abs(delta.x) > 60:
						if delta.x > 0:
							_viewer_prev()
						else:
							_viewer_next()
					else:
						_viewer_next()
	elif event is InputEventScreenTouch:
		if event.pressed:
			_drag_active = true
			_drag_start = event.position
		else:
			if _drag_active:
				var delta = event.position - _drag_start
				_drag_active = false
				if abs(delta.x) > 60:
					if delta.x > 0:
						_viewer_prev()
					else:
						_viewer_next()
				else:
					_viewer_next()
	elif event.is_action_pressed("ui_right"):
		_viewer_next()
	elif event.is_action_pressed("ui_left"):
		_viewer_prev()
	elif event.is_action_pressed("ui_cancel"):
		_close_viewer()

func _on_back_button_pressed():
	get_tree().change_scene_to_file("res://Scenes/Menu.tscn")
