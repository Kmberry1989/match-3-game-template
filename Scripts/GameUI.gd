extends Control

@onready var player_name_label = $MarginContainer/HBoxContainer/PlayerInfo/HBox/AvatarFrame/VBox/PlayerNameLabel
@onready var level_label = $MarginContainer/HBoxContainer/PlayerInfo/HBox/AvatarFrame/VBox/LevelLabel
@onready var xp_label = $MarginContainer/HBoxContainer/PlayerInfo/HBox/AvatarFrame/VBox/XpLabel

func _ready():
	set_player_name(PlayerManager.get_player_name())
	update_level_label(PlayerManager.get_current_level())
	update_xp_label()
	PlayerManager.level_up.connect(update_level_label)

func set_player_name(p_name):
	player_name_label.text = p_name

func update_level_label(level):
	level_label.text = "Level: " + str(level)

func update_xp_label():
	var current_xp = PlayerManager.get_current_xp()
	var xp_needed = PlayerManager.get_xp_for_next_level()
	xp_label.text = "XP: " + str(current_xp) + "/" + str(xp_needed)
