extends TextureRect

@export var textures: Array[Texture] = [
	preload("res://Assets/bg1.jpg"),
	preload("res://Assets/bg2.jpg"),
	preload("res://Assets/bg3.jpg"),
	preload("res://Assets/bg4.jpg")
]

@export var fade_duration: float = 1.0
@export var hold_duration: float = 5.0
@export var hue_shift_speed: float = 0.05

var current_texture_index = 0
var tween: Tween = null
var time = 0.0

func _ready():
	texture = textures[current_texture_index]
	cycle_background()

func cycle_background():
	if tween:
		tween.kill()
	
	tween = get_tree().create_tween()
	tween.tween_callback(Callable(self, "change_texture"))
	tween.tween_property(self, "modulate", Color(1, 1, 1, 1), fade_duration)
	tween.tween_interval(hold_duration)
	tween.tween_property(self, "modulate", Color(1, 1, 1, 0), fade_duration)
	tween.finished.connect(Callable(self, "cycle_background"))

func change_texture():
	current_texture_index = (current_texture_index + 1) % textures.size()
	texture = textures[current_texture_index]

func _process(_delta):
	#time += delta * hue_shift_speed
	#var hue = fmod(time, 1.0)
	#modulate = Color.from_hsv(hue, 0.5, 1.0)
	pass
