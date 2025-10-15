extends Panel

@onready var trophy_grid = $VBoxContainer/ScrollContainer/TrophyGrid

const TROPHY_DIR = "res://Assets/Visuals/Trophies"

func _ready():
    load_trophies()

func load_trophies():
    var unlocked_trophies = PlayerManager.player_data.unlocks.trophies
    var dir = DirAccess.open(TROPHY_DIR)
    if dir:
        dir.list_dir_begin()
        var file_name = dir.get_next()
        while file_name != "":
            if file_name.ends_with(".png"):
                var trophy_resource = Trophy.new()
                trophy_resource.unlocked_icon = load(TROPHY_DIR.path_join(file_name)) as Texture2D
                
                var trophy_name_text = file_name.get_file().replace("trophy_", "").replace("_", " ").capitalize()
                trophy_resource.trophy_name = trophy_name_text
                trophy_resource.description = file_name.get_file()
                var trophy_id = file_name.get_file()
                trophy_resource.id = trophy_id
                
                var trophy_display = preload("res://Scenes/TrophyDisplay.tscn").instantiate()
                trophy_grid.add_child(trophy_display)

                if unlocked_trophies.has(trophy_id):
                    trophy_display.set_trophy(trophy_resource, true)
                else:
                    trophy_display.set_trophy(trophy_resource, false)
            
            file_name = dir.get_next()

func _on_back_button_pressed():
    get_tree().change_scene_to_file("res://Scenes/Menu.tscn")

