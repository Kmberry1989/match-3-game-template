extends Node2D

const PULSE_SCALE_MAX = Vector2(0.2725, 0.2725)
const PULSE_SCALE_MIN = Vector2(0.2575, 0.2575)

@export var color = ""
@onready var sprite = get_node("Sprite2D")
var matched = false

var pulse_tween: Tween = null
var float_tween: Tween = null
var shadow: Sprite2D = null

# Visual Effects
@onready var flash_texture = preload("res://Assets/Visuals/bright_flash.png")

# Animation state and textures
var animation_state = "normal"  # normal, blinking, sad, idle, surprised
var normal_texture: Texture
var blink_texture: Texture
var sad_texture: Texture
var sleepy_texture: Texture
var surprised_texture: Texture
var yawn_texture: Texture

var last_yawn_time = 0
const YAWN_COOLDOWN = 5000 # 5 seconds in milliseconds

@onready var blink_timer = Timer.new()

# Mapping from color to character name
var color_to_character = {
	"blue": "bethany",
	"green": "caleb",
	"pink": "eric",
	"red": "kristen",
	"yellow": "kyle",
	"purple": "maia",
	"orange": "rochelle",
	"brown": "vickie"
}

# Mapping from color to pulse duration
var color_to_pulse_duration = {
	"red": 0.8,
	"orange": 1.0,
	"yellow": 1.2,
	"green": 1.5,
	"blue": 1.8,
	"purple": 2.0,
	"pink": 2.2,
	"brown": 2.5
}

var mouse_inside = false

func _ready():
	load_textures()
	create_shadow()
	setup_blink_timer()
	start_floating()
	start_pulsing()
	
	var area = Area2D.new()
	var shape = CollisionShape2D.new()
	var circle = CircleShape2D.new()
	circle.radius = 50
	shape.shape = circle
	area.add_child(shape)
	add_child(area)
	area.connect("mouse_entered", Callable(self, "_on_mouse_entered"))
	area.connect("mouse_exited", Callable(self, "_on_mouse_exited"))

func _process(_delta):
	if mouse_inside:
		pass

func _on_mouse_entered():
	mouse_inside = true
	if pulse_tween:
		pulse_tween.kill()
	
	# Set scale to the largest size from the pulse animation
	sprite.scale = PULSE_SCALE_MAX
	play_surprised_animation()

func _on_mouse_exited():
	mouse_inside = false
	sprite.scale = PULSE_SCALE_MIN # Reset scale
	start_pulsing()
	set_normal_texture()

func play_surprised_animation():
	if animation_state == "normal":
		AudioManager.play_sound("surprised")
		animation_state = "surprised"
		sprite.texture = surprised_texture

func play_drag_sad_animation():
	animation_state = "sad"
	sprite.texture = sad_texture

func move(new_position):
	var tween = get_tree().create_tween()
	tween.tween_property(self, "position", new_position, 0.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	return tween

func play_match_animation(delay):
	var tween = get_tree().create_tween()
	tween.tween_interval(delay)
	tween.tween_callback(Callable(self, "show_flash"))
	tween.parallel().tween_property(self, "scale", scale * 1.5, 0.3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(self, "modulate:a", 0.0, 0.3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func show_flash():
	var flash = Sprite2D.new()
	flash.texture = flash_texture
	flash.modulate = Color(1,1,1,0.7)
	add_child(flash)
	var tween = get_tree().create_tween()
	tween.tween_property(flash, "scale", Vector2(2,2), 0.3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(flash, "modulate:a", 0.0, 0.3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_callback(Callable(flash, "queue_free"))

func play_sad_animation():
	animation_state = "sad"
	sprite.texture = sad_texture

func play_surprised_for_a_second():
	if animation_state == "normal":
		AudioManager.play_sound("surprised")
		animation_state = "surprised"
		sprite.texture = surprised_texture
		var timer = get_tree().create_timer(1.0)
		await timer.timeout
		if animation_state == "surprised":
			set_normal_texture()

func create_shadow():
	shadow = Sprite2D.new()
	var gradient = Gradient.new()
	gradient.colors = [Color(0,0,0,0.4), Color(0,0,0,0)] # Black center, transparent edge
	var gradient_tex = GradientTexture2D.new()
	gradient_tex.gradient = gradient
	gradient_tex.fill = GradientTexture2D.FILL_RADIAL
	gradient_tex.width = 64
	gradient_tex.height = 64
	shadow.texture = gradient_tex
	shadow.scale = Vector2(1, 0.5) # Make it oval
	shadow.z_index = -1
	shadow.position = Vector2(0, 35)
	add_child(shadow)

func load_textures():
	var character = color_to_character.get(color, "bethany") # Default to bethany if color not found
	
	# Construct texture paths to use the 'Dots' subfolder.
	var base_path = "res://Assets/Dots/" + character + "avatar"
	normal_texture = load(base_path + ".png")
	blink_texture = load(base_path + "blink.png")
	sad_texture = load(base_path + "sad.png")
	sleepy_texture = load(base_path + "sleepy.png")
	surprised_texture = load(base_path + "surprised.png")
	yawn_texture = load(base_path + "yawn.png")
	
	sprite.texture = normal_texture

func set_normal_texture():
	animation_state = "normal"
	sprite.texture = normal_texture

func reset_to_normal_state():
	set_normal_texture()

func setup_blink_timer():
	blink_timer.connect("timeout", Callable(self, "_on_blink_timer_timeout"))
	blink_timer.set_one_shot(true)
	add_child(blink_timer)
	blink_timer.start(randf_range(4.0, 12.0))

func start_floating():
	if float_tween:
		float_tween.kill()
	float_tween = get_tree().create_tween().set_loops()
	float_tween.tween_property(sprite, "position:y", -5, 1.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	float_tween.tween_property(sprite, "position:y", 5, 1.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func start_pulsing():
	if pulse_tween:
		pulse_tween.kill()

	var pulse_duration = color_to_pulse_duration.get(color, 1.5) # Default to 1.5 if color not found

	pulse_tween = get_tree().create_tween().set_loops()
	pulse_tween.tween_property(sprite, "scale", PULSE_SCALE_MAX, pulse_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	pulse_tween.tween_property(sprite, "scale", PULSE_SCALE_MIN, pulse_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _on_blink_timer_timeout():
	if animation_state == "normal":
		animation_state = "blinking"
		sprite.texture = blink_texture
		await get_tree().create_timer(0.15).timeout
		if animation_state == "blinking": # Ensure state wasn't changed by a higher priority animation
			set_normal_texture()
	
	blink_timer.start(randf_range(4.0, 12.0))

func play_idle_animation():
	var current_time = Time.get_ticks_msec()
	if current_time - last_yawn_time < YAWN_COOLDOWN:
		return # Cooldown is active, so we do nothing.

	if animation_state != "normal":
		return

	last_yawn_time = current_time
	animation_state = "idle"
	sprite.texture = sleepy_texture
	await get_tree().create_timer(0.5).timeout
	
	if animation_state == "idle": # Make sure we weren't interrupted
		sprite.texture = yawn_texture
		AudioManager.play_sound("yawn")
		
		var original_pos = self.position
		var original_shadow_scale = shadow.scale
		var original_shadow_opacity = shadow.modulate.a
		
		if pulse_tween:
			pulse_tween.kill()
		if float_tween:
			float_tween.kill()
			
		var tween = get_tree().create_tween()
		# Lift and inflate over 2 seconds
		tween.parallel().tween_property(self, "position", original_pos + Vector2(0, -15), 2.0).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
		tween.parallel().tween_property(sprite, "scale", PULSE_SCALE_MIN * 1.5, 2.0).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
		tween.parallel().tween_property(shadow, "scale", original_shadow_scale * 2.5, 2.0).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
		tween.parallel().tween_property(shadow, "modulate:a", 0.0, 2.0).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
		await tween.finished

		if animation_state == "idle":
			var down_tween = get_tree().create_tween()
			down_tween.parallel().tween_property(self, "position", original_pos, 1.0)
			down_tween.parallel().tween_property(sprite, "scale", PULSE_SCALE_MIN, 1.0)
			down_tween.parallel().tween_property(shadow, "scale", original_shadow_scale, 1.0)
			down_tween.parallel().tween_property(shadow, "modulate:a", original_shadow_opacity, 1.0)
			await down_tween.finished
			set_normal_texture()
			start_pulsing()
