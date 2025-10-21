extends Panel

@onready var tab_container := $VBoxContainer/TabContainer
@onready var trophy_grid := $VBoxContainer/TabContainer/Trophies/Scroll/TrophyGrid
@onready var viewer_overlay := $ViewerOverlay
@onready var viewer_image := $ViewerOverlay/Center/VBox/LargeImage
@onready var viewer_label := $ViewerOverlay/Center/VBox/ItemLabel
var viewer_desc: Label = null

const TROPHY_DIR := "res://Assets/Trophies"

var trophies: Array = [] # [{id, path, unlocked_icon, locked_icon, name, unlocked, description}]
var current_index: int = -1

var _drag_active := false
var _drag_start := Vector2.ZERO

func _ready():
	# Only show trophies in the showcase
	load_trophies()
	# Hide/disable any Frames tab if present in the scene
	var frames_tab := tab_container.get_node_or_null("Frames")
	if frames_tab:
		frames_tab.visible = false
		frames_tab.queue_free()
	# Make back button behavior/layout match Shop
	var root_vbox := tab_container.get_parent() as VBoxContainer
	if root_vbox != null:
		root_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
		var back_btn: Button = root_vbox.get_node_or_null("BackButton")
		if back_btn == null:
			back_btn = Button.new()
			back_btn.name = "BackButton"
			back_btn.text = "Back"
			back_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			root_vbox.add_child(back_btn)
		else:
			back_btn.text = "Back"
			back_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		if not back_btn.is_connected("pressed", Callable(self, "_on_back_button_pressed")):
			back_btn.connect("pressed", Callable(self, "_on_back_button_pressed"))
	# Ensure a description label exists under the viewer name label
	if is_instance_valid(viewer_label):
		var vb := viewer_label.get_parent()
		if vb != null:
			viewer_desc = vb.get_node_or_null("DescLabel")
			if viewer_desc == null:
				viewer_desc = Label.new()
				viewer_desc.name = "DescLabel"
				viewer_desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				# Optional: wrap long descriptions
				viewer_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				viewer_desc.add_theme_font_size_override("font_size", 18)
				vb.add_child(viewer_desc)

func load_trophies():
	# Populate from trophy resources in res://Assets/Trophies
	trophies.clear()
	for child in trophy_grid.get_children():
		child.queue_free()
	var dir = DirAccess.open(TROPHY_DIR)
	if dir == null:
		return
	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.to_lower().ends_with(".tres"):
			var path = TROPHY_DIR.path_join(file_name)
			var trophy_res = load(path)
			if typeof(trophy_res) == TYPE_OBJECT and trophy_res != null:
				# Expect a Trophy resource with fields: id, trophy_name, description, unlocked_icon
				var id: String = str(trophy_res.id) if str(trophy_res.id) != "" else file_name.get_basename()
				var display: String = str(trophy_res.trophy_name) if str(trophy_res.trophy_name) != "" else id.replace("_", " ").capitalize()
				var unlocked := false
				if typeof(PlayerManager.player_data) == TYPE_DICTIONARY:
					var unlocked_list: Array = PlayerManager.player_data.get("unlocks", {}).get("trophies", [])
					unlocked = unlocked_list.has(id)
				
				var unlocked_icon = trophy_res.unlocked_icon
				var locked_icon = trophy_res.get("locked_icon", null) # Safely get locked_icon

				var display_icon = unlocked_icon if unlocked else locked_icon
				if display_icon == null: # Fallback for missing locked_icon
					display_icon = unlocked_icon

				var item = {"id": id, "path": path, "unlocked_icon": unlocked_icon, "locked_icon": locked_icon, "name": display, "unlocked": unlocked, "description": str(trophy_res.description)}
				var idx = trophies.size()
				trophies.append(item)
				_add_thumbnail(trophy_grid, display_icon, display, unlocked, func():
					_open_viewer(idx)
				)
		file_name = dir.get_next()
	dir.list_dir_end()

# Frames are no longer shown here; Showcase is trophy-only

func _add_thumbnail(container: GridContainer, tex: Texture2D, label_text: String, unlocked: bool, on_click: Callable):
	var vb = VBoxContainer.new()
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var thumb = TextureRect.new()
	thumb.texture = tex
	thumb.custom_minimum_size = Vector2(128, 128)
	thumb.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	thumb.mouse_filter = Control.MOUSE_FILTER_STOP
	thumb.gui_input.connect(func(event):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			on_click.call()
	)
	var lbl = Label.new()
	lbl.text = label_text
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var status_text := ("UNLOCKED" if unlocked else "LOCKED")
	lbl.tooltip_text = status_text
	thumb.tooltip_text = status_text
	vb.add_child(thumb)
	vb.add_child(lbl)
	container.add_child(vb)

func _open_viewer(index: int):
	current_index = index
	_update_viewer()
	viewer_overlay.visible = true

func _close_viewer():
	viewer_overlay.visible = false
	current_index = -1

func _update_viewer():
	if current_index < 0:
		return
	if current_index >= 0 and current_index < trophies.size():
		var item = trophies[current_index]
		var unlocked := bool(item.get("unlocked", false))
		
		var display_icon = item["unlocked_icon"] if unlocked else item["locked_icon"]
		if display_icon == null:
			display_icon = item["unlocked_icon"]
		
		viewer_image.texture = display_icon
		var status_text := ("UNLOCKED" if unlocked else "LOCKED")
		viewer_label.text = item["name"]
		if viewer_desc != null:
			viewer_desc.text = String(item.get("description", ""))
			viewer_desc.tooltip_text = status_text
		viewer_label.tooltip_text = status_text
		viewer_image.tooltip_text = status_text

func _viewer_next():
	if trophies.size() == 0:
		return
	current_index = (current_index + 1) % trophies.size()
	_update_viewer()

func _viewer_prev():
	if trophies.size() == 0:
		return
	current_index = (current_index - 1 + trophies.size()) % trophies.size()
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