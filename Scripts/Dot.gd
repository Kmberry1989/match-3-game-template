extends Node2D

const PULSE_SCALE_MAX = Vector2(0.2725, 0.2725)
const PULSE_SCALE_MIN = Vector2(0.2575, 0.2575)
const DOT_SCALE := 2.0 # Global multiplier to enlarge dot visuals
const REFERENCE_DOT_PX = 512.0

@export var color = ""
@onready var sprite = get_node("Sprite2D")
var matched = false
var scale_multiplier: float = 1.0
var is_wildcard: bool = false

# Emitted when the match fade-out finishes; used to trigger XP orbs immediately.
signal match_faded(global_pos, color_name)

var pulse_tween: Tween = null
var float_tween: Tween = null
var shadow: Sprite2D = null # Godot 4

# Whether an XP orb has already been spawned for this dot in the current match.
var orb_spawned: bool = false

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
const YAWN_COOLDOWN = 2500 # 2.5 seconds in milliseconds

@onready var blink_timer = Timer.new()
@onready var wildcard_timer = Timer.new()
var wildcard_textures: Array[Texture] = []
var _wildcard_index: int = 0

# Mapping from color to character name
var color_to_character = {
	"yellow": "bethany",
	"brown": "caleb",
	"gray": "eric",
	"pink": "kristen",
	"green": "kyle",
	"purple": "connie",
	"red": "rochelle",
	"blue": "vickie",
	"orange": "maia"
}

# Mapping from color to pulse duration
var color_to_pulse_duration = {
	"red": 1,
	"orange": 1,
	"yellow": 1,
	"green": 1,
	"blue": 1,
	"purple": 1,
	"pink": 1,
	"brown": 1,
	"gray": 1
}

var mouse_inside = false

# --- FIX for "zombie" async functions ---
var _is_active: bool = true

var _tweens: Array[Tween] = []

func create_tracked_tween() -> Tween:
	var tween := create_tween()
	tween.finished.connect(func():
		if _tweens.has(tween):
			_tweens.erase(tween)
	)
	_tweens.append(tween)
	return tween

func _ready():
	load_textures()
	# Adjust dot scale based on texture size so in-game size stays consistent
	if sprite and sprite.texture:
		var tex_w: float = float(sprite.texture.get_width())
		var tex_h: float = float(sprite.texture.get_height())
		var max_dim: float = max(tex_w, tex_h)
		if max_dim > 0.0:
			scale_multiplier = (REFERENCE_DOT_PX / max_dim) * DOT_SCALE
	create_shadow()
	setup_blink_timer()
	setup_wildcard_timer()
	
	# Set initial scale
	sprite.scale = PULSE_SCALE_MIN * scale_multiplier
	
	# Start animations
	activate_animations()
	
	# Create input detection area only in the editor for debugging overlays.
	if Engine.is_editor_hint():
		var area = Area2D.new()
		add_child(area)
		area.mouse_entered.connect(_on_mouse_entered) # Godot 4
		area.mouse_exited.connect(_on_mouse_exited) # Godot 4

	# Wait for the sprite texture to be loaded
	await get_tree().process_frame

	var texture = sprite.texture
	if texture and Engine.is_editor_hint():
		var collision_shape = CollisionShape2D.new()
		var square_shape = RectangleShape2D.new()
		var max_dimension = max(texture.get_width(), texture.get_height())
		var target_scale = max(PULSE_SCALE_MAX.x, PULSE_SCALE_MAX.y) * scale_multiplier
		var side_length = max_dimension * target_scale
		square_shape.size = Vector2(side_length, side_length) # Godot 4
		collision_shape.shape = square_shape
		# `area` exists only in editor hint branch above
		if has_node("Area2D"):
			get_node("Area2D").add_child(collision_shape)

# This function is called by DotPool.gd when the dot is returned to the pool
func reset():
	_is_active = false
	
	# --- FIX for "Zombie" Tweens (Godot 4) ---
	# This kills all tweens bound to this node, solving the scale bug
	for tween in _tweens:
		if is_instance_valid(tween):
			tween.kill()
	_tweens.clear()
	# ----------------------------------------
	
	# Stop timers
	blink_timer.stop()
	wildcard_timer.stop()

	# Null out refs
	pulse_tween = null
	float_tween = null

	# Reset state variables
	matched = false
	orb_spawned = false
	is_wildcard = false
	set_normal_texture()
	
	# Reset visual properties
	self.modulate = Color(1, 1, 1, 1)
	self.scale = Vector2(1, 1) # CRITICAL: Reset Node2D scale
	sprite.scale = PULSE_SCALE_MIN * scale_multiplier # Reset sprite scale
	sprite.position = Vector2.ZERO
	mouse_inside = false
	self.visible = false # Hide for the pool

# This function is called by Grid.gd *after* add_child()
func activate_animations():
	_is_active = true
	
	# Ensure we are in the tree before creating tweens
	if not is_inside_tree():
		await get_tree().process_frame
		if not is_inside_tree():
			push_error("Dot: Cannot activate animations, node is not in scene tree.")
			return
			
	# Start fresh animations
	start_floating()
	start_pulsing()
	
	# Start timers
	if is_inside_tree():
		blink_timer.start(randf_range(4.0, 12.0))


func _process(_delta):
	if mouse_inside:
		pass

func _on_mouse_entered():
	mouse_inside = true
	if is_instance_valid(pulse_tween): 
		pulse_tween.kill() 
	
	# Set scale to the largest size from the pulse animation
	sprite.scale = PULSE_SCALE_MAX * scale_multiplier
	play_surprised_animation()

func _on_mouse_exited():
	mouse_inside = false
	sprite.scale = PULSE_SCALE_MIN * scale_multiplier # Reset scale
	start_pulsing()
	set_normal_texture()

func play_surprised_animation():
	if animation_state == "normal":
		if typeof(AudioManager) != TYPE_NIL:
			AudioManager.play_sound("surprised")
		animation_state = "surprised"
		sprite.texture = surprised_texture

func play_drag_sad_animation():
	animation_state = "sad"
	sprite.texture = sad_texture

func move(new_position, duration := 0.2):
	if not is_inside_tree():
		return
	var tween = create_tracked_tween() # <-- FIX: Use node-bound tween
	if not is_instance_valid(tween): return
	
	tween.tween_property(self, "position", new_position, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	return tween

func play_match_animation(delay):
	if not is_inside_tree():
		return
	var tween = create_tracked_tween() # <-- FIX: Use node-bound tween
	if not is_instance_valid(tween): return

	tween.tween_interval(delay)
	tween.tween_callback(show_flash) # Godot 4
	
	# Use explicit scale
	tween.parallel().tween_property(self, "scale", Vector2(1.5, 1.5), 0.3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	
	tween.parallel().tween_property(self, "modulate:a", 0.0, 0.3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.finished.connect(_on_match_fade_finished) # Godot 4

func _on_match_fade_finished():
	if not orb_spawned:
		orb_spawned = true
		emit_signal("match_faded", global_position, color)

func show_flash():
	if not is_inside_tree():
		return
	var flash = Sprite2D.new() # Godot 4
	flash.texture = flash_texture
	flash.centered = true
	flash.modulate = Color(1,1,1,0.7)
	add_child(flash)
	
	# This tween is OK, as it's self-contained
	var tween = create_tracked_tween() 
	tween.tween_property(flash, "scale", Vector2(2,2), 0.3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(flash, "modulate:a", 0.0, 0.3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await tween.finished
	flash.queue_free() # Godot 4

func play_sad_animation():
	animation_state = "sad"
	sprite.texture = sad_texture

func play_surprised_for_a_second():
	if not is_inside_tree():
		return
	if animation_state == "normal":
		if typeof(AudioManager) != TYPE_NIL:
			AudioManager.play_sound("surprised")
		animation_state = "surprised"
		sprite.texture = surprised_texture
		var timer = get_tree().create_timer(1.0)
		await timer.timeout
		
		# Check if we were pooled
		if not _is_active: return
		
		if animation_state == "surprised":
			set_normal_texture()

func create_shadow():
	shadow = Sprite2D.new() # Godot 4
	var gradient = Gradient.new()
	gradient.colors = [Color(0,0,0,0.4), Color(0,0,0,0)] # Black center, transparent edge
	var gradient_tex = GradientTexture2D.new() # Godot 4
	gradient_tex.gradient = gradient
	gradient_tex.fill = GradientTexture2D.FILL_RADIAL # Godot 4
	gradient_tex.width = 64
	gradient_tex.height = 64
	shadow.texture = gradient_tex
	shadow.scale = Vector2(1, 0.5) # Make it oval
	shadow.z_index = -1
	shadow.position = Vector2(0, 35)
	add_child(shadow)
	# Hide shadow to remove it visually
	shadow.visible = false
	shadow.modulate.a = 0.0

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
	if is_wildcard:
		return
	animation_state = "normal"
	sprite.texture = normal_texture

func reset_to_normal_state():
	if is_wildcard:
		return
	set_normal_texture()

func setup_blink_timer():
	blink_timer.timeout.connect(_on_blink_timer_timeout) # Godot 4
	blink_timer.one_shot = true
	add_child(blink_timer)

func setup_wildcard_timer():
	add_child(wildcard_timer)
	wildcard_timer.one_shot = false
	wildcard_timer.wait_time = 0.12
	wildcard_timer.timeout.connect(_on_wildcard_tick) # Godot 4

func _on_wildcard_tick():
	if not is_wildcard:
		wildcard_timer.stop()
		return
	if wildcard_textures.size() == 0:
		return
	_wildcard_index = (_wildcard_index + 1) % wildcard_textures.size()
	sprite.texture = wildcard_textures[_wildcard_index]

func set_wildcard(enable: bool = true):
	is_wildcard = enable
	if enable:
		animation_state = "wildcard"
		# Build a list of normal textures across all characters/colors
		wildcard_textures.clear()
		for col in color_to_character.keys():
			var character = color_to_character[col]
			var base_path = "res://Assets/Dots/" + character + "avatar"
			var tex: Texture = load(base_path + ".png")
			if tex:
				wildcard_textures.append(tex)
		if wildcard_textures.size() > 0:
			_wildcard_index = 0
			sprite.texture = wildcard_textures[_wildcard_index]
			wildcard_timer.start()
		# Make the shadow slightly brighter for wildcard
		if shadow:
			shadow.modulate = Color(0.2,0.2,0.2,0.6)
	else:
		wildcard_timer.stop()
		animation_state = "normal"
		set_normal_texture()

func start_floating():
	if is_instance_valid(float_tween): 
		float_tween.kill()
	
	if not is_inside_tree():
		return
		
	float_tween = create_tracked_tween() # <-- FIX: Use node-bound tween
	if not is_instance_valid(float_tween): return
	
	float_tween.set_loops() 
	float_tween.tween_property(sprite, "position:y", -5, 1.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	float_tween.tween_property(sprite, "position:y", 5, 1.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func start_pulsing():
	if is_instance_valid(pulse_tween): 
		pulse_tween.kill()

	if not is_inside_tree():
		return

	var pulse_duration = color_to_pulse_duration.get(color, 1.5)

	pulse_tween = create_tracked_tween() # <-- FIX: Use node-bound tween
	if not is_instance_valid(pulse_tween): return
	
	pulse_tween.set_loops()
	pulse_tween.tween_property(sprite, "scale", PULSE_SCALE_MAX * scale_multiplier, pulse_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	pulse_tween.tween_property(sprite, "scale", PULSE_SCALE_MIN * scale_multiplier, pulse_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _on_blink_timer_timeout():
	# Check if we are still active and in the tree
	if not is_inside_tree() or not _is_active:
		return
		
	if animation_state == "normal":
		animation_state = "blinking"
		sprite.texture = blink_texture
		await get_tree().create_timer(0.15).timeout
		
		# Check again after await
		if not is_inside_tree() or not _is_active: 
			return
			
		if animation_state == "blinking": # Ensure state wasn't changed
			set_normal_texture()
	
	# Restart timer
	if is_inside_tree():
		blink_timer.start(randf_range(4.0, 12.0))

func play_idle_animation():
	if not is_inside_tree():
		return
		
	var current_time = Time.get_ticks_msec() # Godot 4
	if current_time - last_yawn_time < YAWN_COOLDOWN:
		return # Cooldown is active, so we do nothing.

	if animation_state != "normal":
		return

	last_yawn_time = current_time
	animation_state = "idle"
	sprite.texture = sleepy_texture
	await get_tree().create_timer(0.5).timeout
	
	# Check if we were pooled or interrupted
	if not is_inside_tree() or not _is_active or animation_state != "idle":
		return
		
	sprite.texture = yawn_texture
	if typeof(AudioManager) != TYPE_NIL:
		AudioManager.play_sound("yawn")
	
	var original_pos = self.position
	var original_shadow_scale = shadow.scale
	var original_shadow_opacity = shadow.modulate.a
	
	# Stop looping animations
	if is_instance_valid(pulse_tween): 
		pulse_tween.kill()
	if is_instance_valid(float_tween): 
		float_tween.kill()
		
	var tween = create_tracked_tween() # <-- FIX: Use node-bound tween
	if not is_instance_valid(tween): return
	
	# Lift and inflate over 2 seconds
	tween.parallel().tween_property(self, "position", original_pos + Vector2(0, -15), 2.0).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(sprite, "scale", (PULSE_SCALE_MIN * 1.5) * scale_multiplier, 2.0).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(shadow, "scale", original_shadow_scale * 2.5, 2.0).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(shadow, "modulate:a", 0.0, 2.0).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	await tween.finished

	# Check again after await
	if not is_inside_tree() or not _is_active or animation_state != "idle":
		return

	var down_tween = create_tracked_tween() # <-- FIX: Use node-bound tween
	if not is_instance_valid(down_tween): return
	
	down_tween.parallel().tween_property(self, "position", original_pos, 1.0)
	down_tween.parallel().tween_property(sprite, "scale", PULSE_SCALE_MIN * scale_multiplier, 1.0)
	down_tween.parallel().tween_property(shadow, "scale", original_shadow_scale, 1.0)
	down_tween.parallel().tween_property(shadow, "modulate:a", original_shadow_opacity, 1.0)
	await down_tween.finished
	
	# Final check
	if not is_inside_tree() or not _is_active:
		return
		
	set_normal_texture()
	# Restart looping animations
	start_pulsing()
	start_floating() 


func start_surprised_jitter(jitter_time: float = 0.6, jitter_px: float = 4.0) -> void:
	if not is_inside_tree():
		return
		
	if animation_state == "surprised":
		return
	animation_state = "surprised"
	if typeof(AudioManager) != TYPE_NIL:
		AudioManager.play_sound("surprised")
	var original_pos := self.position
	var end_time: int = int(Time.get_ticks_msec() + int(jitter_time * 1000.0)) # Godot 4
	
	# Run a looping async jitter until time is up
	while Time.get_ticks_msec() < end_time and is_inside_tree() and _is_active:
		var dx := randf_range(-jitter_px, jitter_px)
		var dy := randf_range(-jitter_px, jitter_px)
		var t := create_tracked_tween() # <-- FIX: Use node-bound tween
		if not is_instance_valid(t): break # Exit loop if tween creation fails
		
		t.tween_property(self, "position", original_pos + Vector2(dx, dy), 0.06).set_trans(Tween.TRANS_SINE)
		await t.finished
		
		if not is_inside_tree() or not _is_active: return # Check after await
		
		var t2 := create_tracked_tween() # <-- FIX: Use node-bound tween
		if not is_instance_valid(t2): break # Exit loop
		
		t2.tween_property(self, "position", original_pos + Vector2(dx * 0.25, dy * 0.25), 0.12).set_trans(Tween.TRANS_SINE)
		await t2.finished
		
		if not is_inside_tree() or not _is_active: return # Check after await
		
	if not _is_active: return # Final check
	
	# Snap back to original position and remain surprised (eyes closed)
	self.position = original_pos
	# Keep surprised texture up; caller will control when to open eyes / reset
	if sprite and surprised_texture:
		sprite.texture = surprised_texture

func forced_blink(duration: float = 2.0) -> void:
	if not is_inside_tree():
		return
		
	# Stop any ongoing blink timer to avoid interference.
	if blink_timer != null and blink_timer.timeout.is_connected(_on_blink_timer_timeout):
		blink_timer.stop()
	
	var end_time: int = int(Time.get_ticks_msec() + int(duration * 1000.0)) # Godot 4
	
	# Use a simple loop to show blink texture for brief moments over the duration
	while Time.get_ticks_msec() < end_time and is_inside_tree() and _is_active:
		# Close eyes briefly
		sprite.texture = blink_texture
		await get_tree().create_timer(0.12).timeout
		
		if not is_inside_tree() or not _is_active: return # Check after await
		
		# Open again unless we reached final moment
		if Time.get_ticks_msec() + 150 < end_time:
			sprite.texture = surprised_texture if animation_state == "surprised" else normal_texture
			await get_tree().create_timer(0.28).timeout
			
			if not is_inside_tree() or not _is_active: return # Check after await
			
	if not _is_active: return # Final check
	
	# Final open eyes
	set_normal_texture()
	
	# restart blink timer normally
	if blink_timer != null and is_inside_tree():
		blink_timer.start(randf_range(4.0, 12.0))
