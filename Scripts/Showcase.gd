extends Panel

@onready var trophy_grid = $VBoxContainer/ScrollContainer/TrophyGrid

const TROPHY_DIR = "res://Assets/Trophies"

func _ready():
	load_trophies()

func load_trophies():
	var unlocked_trophies = PlayerManager.player_data.unlocks.trophies
	
	var dir = DirAccess.open(TROPHY_DIR)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if file_name.ends_with(".tres"):
				var trophy = load(TROPHY_DIR.path_join(file_name))
				var trophy_display = preload("res://Scenes/TrophyDisplay.tscn").instantiate()
				trophy_grid.add_child(trophy_display)
				
				if unlocked_trophies.has(trophy.id):
					trophy_display.set_trophy(trophy, true)
				else:
					trophy_display.set_trophy(trophy, false)
			
			file_name = dir.get_next()

func _on_back_button_pressed():
	get_tree().change_scene_to_file("res://Scenes/Menu.tscn")
