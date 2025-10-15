extends Control

@onready var player_name_label = $MarginContainer/VBoxContainer/PlayerNameLabel
@onready var time_played_label = $MarginContainer/VBoxContainer/TimePlayedLabel
@onready var level_label = $MarginContainer/VBoxContainer/LevelLabel
@onready var xp_label = $MarginContainer/VBoxContainer/XpLabel
@onready var best_combo_label = $MarginContainer/VBoxContainer/BestComboLabel
@onready var lines_cleared_label = $MarginContainer/VBoxContainer/LinesClearedLabel
@onready var avatar_texture_rect = $MarginContainer/VBoxContainer/HBoxContainer/AvatarFrame/Avatar
@onready var avatar_frame_rect = $MarginContainer/VBoxContainer/HBoxContainer/AvatarFrame
@onready var file_dialog = $FileDialog
@onready var objectives_container = $MarginContainer/VBoxContainer/ObjectivesContainer
@onready var trophies_container = $MarginContainer/VBoxContainer/TrophiesContainer
@onready var frame_selection_button = $MarginContainer/VBoxContainer/HBoxContainer/VBoxContainer/FrameSelection
@onready var change_avatar_button = $MarginContainer/VBoxContainer/HBoxContainer/VBoxContainer/ChangeAvatarButton
@onready var back_button = $MarginContainer/VBoxContainer/BackButton

func _ready():
	display_player_data()
	
	# Platform-specific feature handling for avatar upload
	var os_name = OS.get_name()
	if os_name == "Android" or os_name == "iOS":
		change_avatar_button.disabled = true
		change_avatar_button.text = "Upload not on mobile"
	else:
		change_avatar_button.connect("pressed", _on_change_avatar_pressed)
		file_dialog.connect("file_selected", _on_file_selected)

	back_button.connect("pressed", _on_back_button_pressed)
	frame_selection_button.connect("item_selected", _on_frame_selected)

func display_player_data():
	var data = PlayerManager.player_data
	player_name_label.text = "Name: " + data["player_name"]
	var time_played = data["time_played"]
	var hours = int(time_played / 3600)
	var minutes = int((time_played % 3600) / 60)
	var seconds = time_played % 60
	time_played_label.text = "Time Played: %02d:%02d:%02d" % [hours, minutes, seconds]
	level_label.text = "Level: " + str(data["current_level"])
	xp_label.text = "XP: " + str(data["current_xp"]) + "/" + str(PlayerManager.get_xp_for_next_level())
	best_combo_label.text = "Best Combo: " + str(data["best_combo"])
	lines_cleared_label.text = "Dots Cleared: " + str(data["total_lines_cleared"])
	
	# Load avatar
	var avatar_path = "user://avatars/" + PlayerManager.get_player_name() + ".png"
	if FileAccess.file_exists(avatar_path):
		var img = Image.load_from_file(avatar_path)
		var tex = ImageTexture.create_from_image(img)
		avatar_texture_rect.texture = tex

	# Display Objectives
	for child in objectives_container.get_children():
		child.queue_free()
	for objective_name in data["objectives"]:
		var objective_label = Label.new()
		var status = "[In Progress]"
		if data["objectives"][objective_name]:
			status = "[Completed]"
		objective_label.text = objective_name.replace("_", " ").capitalize() + ": " + status
		objectives_container.add_child(objective_label)

	# Display Trophies
	for child in trophies_container.get_children():
		child.queue_free()
	for trophy_name in data["unlocks"]["trophies"]:
		var trophy_texture = load("res://Assets/Visuals/Trophies/" + trophy_name + ".png")
		var trophy_rect = TextureRect.new()
		trophy_rect.texture = trophy_texture
		trophy_rect.custom_minimum_size = Vector2(592, 592)
		trophy_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		trophies_container.add_child(trophy_rect)

	# Populate Frame Selection
	frame_selection_button.clear()
	var current_frame_index = 0
	for i in range(data["unlocks"]["frames"].size()):
		var frame_name = data["unlocks"]["frames"][i]
		frame_selection_button.add_item(frame_name.capitalize())
		if frame_name == PlayerManager.get_current_frame():
			current_frame_index = i
	frame_selection_button.select(current_frame_index)
	update_avatar_frame()

func update_avatar_frame():
	var frame_name = PlayerManager.get_current_frame()
	var frame_path = "res://Assets/Visuals/avatar_frame.png" # Default
	if frame_name != "default":
		frame_path = "res://Assets/Visuals/avatar_" + frame_name + ".png"
	avatar_frame_rect.texture = load(frame_path)

func _on_frame_selected(index):
	var frame_name = frame_selection_button.get_item_text(index).to_lower()
	PlayerManager.set_current_frame(frame_name)
	update_avatar_frame()
	PlayerManager.save_player_data()

# For desktop platforms, this function opens a file dialog.
# For mobile, a native plugin would be needed to open the photo gallery.
# You would then call _on_file_selected with the path from the native plugin.
func _on_change_avatar_pressed():
	file_dialog.popup_centered()

func _on_file_selected(path):
	var img = Image.load_from_file(path)
	if img:
		# Ensure avatars directory exists
		DirAccess.make_dir_absolute("user://avatars")
		var avatar_path = "user://avatars/" + PlayerManager.get_player_name() + ".png"
		img.save_png(avatar_path)
		
		# Update texture
		var tex = ImageTexture.create_from_image(img)
		avatar_texture_rect.texture = tex
		
		PlayerManager.save_player_data()

func _on_back_button_pressed():
	get_tree().change_scene_to_file("res://Scenes/Menu.tscn")
