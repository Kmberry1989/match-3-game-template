extends PanelContainer

@onready var music_slider = $MarginContainer/VBoxContainer/MusicSlider
@onready var sfx_slider = $MarginContainer/VBoxContainer/SfxSlider

func _ready():
	music_slider.value = AudioManager.get_music_volume()
	sfx_slider.value = AudioManager.get_sfx_volume()

func _on_music_slider_value_changed(value):
	AudioManager.set_music_volume(value)

func _on_sfx_slider_value_changed(value):
	AudioManager.set_sfx_volume(value)

func _on_resume_button_pressed():
	get_tree().paused = false
	queue_free()

func _on_quit_button_pressed():
	get_tree().paused = false
	get_tree().change_scene_to_file("res://Scenes/Menu.tscn")
