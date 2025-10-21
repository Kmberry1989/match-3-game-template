extends Node

func _ready():
	print("[Loading.gd] _ready: Intermediate loading scene is ready.")
	call_deferred("load_game_scene")

func load_game_scene():
	print("[Loading.gd] load_game_scene: Changing to Game.tscn.")
	get_tree().change_scene_to_file("res://Scenes/Game.tscn")
