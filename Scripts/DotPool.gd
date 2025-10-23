extends Node

var pools = {}
var dot_scenes = {}

func _ready():
	# To reduce startup cost on low-end devices, do not instantiate each dot scene just to read a color.
	# Instead derive the color key from the filename (e.g. "blue_dot.tscn" -> "blue") and store the PackedScene.
	var possible_paths = [
		"res://Scenes/Dots/blue_dot.tscn",
		"res://Scenes/Dots/green_dot.tscn",
		"res://Scenes/Dots/pink_dot.tscn",
		"res://Scenes/Dots/red_dot.tscn",
		"res://Scenes/Dots/yellow_dot.tscn",
		"res://Scenes/Dots/purple_dot.tscn",
		"res://Scenes/Dots/orange_dot.tscn",
		"res://Scenes/Dots/brown_dot.tscn",
		"res://Scenes/Dots/gray_dot.tscn"
	]
	for path in possible_paths:
		var scene_res: PackedScene = load(path)
		
		# Derive color from filename: take prefix before '_' in the file name
		var fname: String = path.get_file()
		var base := fname
		var dot_idx := base.rfind('.')
		if dot_idx != -1:
			base = base.substr(0, dot_idx)
		var parts := base.split("_")
		var color_key := parts[0] if parts.size() > 0 else base
		dot_scenes[color_key] = scene_res
		pools[color_key] = []

func get_dot(color):
	if pools.has(color) and not pools[color].is_empty():
		var dot = pools[color].pop_front()
		dot.visible = true
		# IMPORTANT: The node that calls get_dot() (e.g., Grid.gd) MUST
		# call dot.activate_animations() *after* adding it to the scene tree.
		return dot
	else:
		if dot_scenes.has(color):
			var new_dot = dot_scenes[color].instantiate()
			# Caller must add_child(new_dot)
			# new_dot.activate_animations() is called inside Dot.gd's _ready()
			return new_dot
		else:
			return null

func return_dot(dot):
	if dot == null or not is_instance_valid(dot):
		return
		
	dot.visible = false
	
	# Stop all animations and reset state by calling the Dot's reset method
	if dot.has_method("reset"):
		dot.reset()
	else:
		# --- THIS LINE WAS CORRECTED ---
		push_error("Dot being returned to pool has no reset() method!")
		# -----------------------------
	
	dot.position = Vector2(-1000, -1000) # Move off-screen
	
	# Ensure dot has no parent before pooling
	if is_instance_valid(dot) and dot.get_parent() != null:
		var p = dot.get_parent()
		p.remove_child(dot)
		
	# Add to the correct pool if valid
	if is_instance_valid(dot) and "color" in dot and pools.has(dot.color):
		pools[dot.color].push_back(dot)
	else:
		# If it's not a dot we can pool, just free it
		if is_instance_valid(dot):
			dot.queue_free()
