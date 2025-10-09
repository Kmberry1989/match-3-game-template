extends Node2D

enum {wait, move}
var state

@export var width: int
@export var height: int
@export var offset: int
@export var y_offset: int

@onready var x_start = ((get_window().size.x / 2.0) - ((width/2.0) * offset ) + (offset / 2.0))
@onready var y_start = ((get_window().size.y / 2.0) + ((height/2.0) * offset ) - (offset / 2.0))
@onready var game_ui = get_node("../GameUI")

@export var empty_spaces: PackedVector2Array

# Preload scenes for dots and new visual effects
@onready var possible_dots = [
	preload("res://Scenes/Dots/blue_dot.tscn"),
	preload("res://Scenes/Dots/green_dot.tscn"),
	preload("res://Scenes/Dots/pink_dot.tscn"),
	preload("res://Scenes/Dots/red_dot.tscn"),
	preload("res://Scenes/Dots/yellow_dot.tscn"),
	preload("res://Scenes/Dots/purple_dot.tscn"),
	preload("res://Scenes/Dots/orange_dot.tscn"),
	preload("res://Scenes/Dots/brown_dot.tscn"),
]
@onready var match_particles = preload("res://Scenes/MatchParticles.tscn")
@onready var match_label_scene = preload("res://Scenes/MatchLabel.tscn")

var destroy_timer = Timer.new()
var collapse_timer = Timer.new()
var refill_timer = Timer.new()
var idle_timer = Timer.new()

var all_dots = []

var dot_one = null
var dot_two = null
var last_place = Vector2(0,0)
var last_direction = Vector2(0,0)
var move_checked = false

# Dragging variables
var is_dragging = false
var dragged_dot = null
var drag_start_position = Vector2.ZERO

# Score variables
var score = 0
var opponent_score = 0

var is_multiplayer = false
var start_time = 0

func _ready():
	start_time = Time.get_unix_time_from_system()
	is_multiplayer = (NetworkManager.peer != null and NetworkManager.peer.get_ready_state() == WebSocketPeer.STATE_OPEN)

	state = move
	setup_timers()
	randomize()
	all_dots = make_2d_array()
	spawn_dots()
	
	await get_tree().process_frame
	update_score_display()
	_on_opponent_score_updated(0)
	game_ui.set_player_name(PlayerManager.get_player_name())
	game_ui.set_opponent_name("Opponent")

	while find_potential_match() == null:
		for i in range(width):
			for j in range(height):
				if all_dots[i][j] != null:
					all_dots[i][j].queue_free()
		all_dots = make_2d_array()
		spawn_dots()

	idle_timer.start()

	# Connect to network signals if in a multiplayer game
	if is_multiplayer:
		NetworkManager.opponent_score_updated.connect(_on_opponent_score_updated)
		NetworkManager.server_disconnected.connect(_on_server_disconnected)

func update_score_display():
	game_ui.set_score(score)
	# If in a multiplayer game, send score update to opponent
	if is_multiplayer:
		NetworkManager.send_score_update(score)

func _on_opponent_score_updated(new_score):
	opponent_score = new_score
	game_ui.set_opponent_score(opponent_score)

func _on_server_disconnected():
	var elapsed_time = Time.get_unix_time_from_system() - start_time
	PlayerManager.add_time_played(elapsed_time)

	if score > opponent_score:
		PlayerManager.increment_pvp_wins()
	else:
		PlayerManager.increment_pvp_losses()
	
	PlayerManager.check_objectives()
	PlayerManager.save_player_data()

	print("Opponent disconnected. Returning to menu.")
	get_tree().change_scene_to_file("res://Scenes/Menu.tscn")
	
func setup_timers():
	destroy_timer.connect("timeout", Callable(self, "destroy_matches"))
	destroy_timer.set_one_shot(true)
	destroy_timer.set_wait_time(1.5) # Increased for new animation
	add_child(destroy_timer)
	
	collapse_timer.connect("timeout", Callable(self, "collapse_columns"))
	collapse_timer.set_one_shot(true)
	collapse_timer.set_wait_time(0.2)
	add_child(collapse_timer)

	refill_timer.connect("timeout", Callable(self, "refill_columns"))
	refill_timer.set_one_shot(true)
	refill_timer.set_wait_time(0.2)
	add_child(refill_timer)
	
	idle_timer.connect("timeout", Callable(self, "_on_idle_timer_timeout"))
	idle_timer.set_one_shot(true)
	idle_timer.set_wait_time(5.0)
	add_child(idle_timer)

func restricted_fill(place):
	if is_in_array(empty_spaces, place):
		return true
	return false
	
func is_in_array(array, item):
	for i in range(array.size()):
		if array[i] == item:
			return true
	return false

func make_2d_array():
	var array = []
	for i in range(width):
		array.append([])
		for j in range(height):
			array[i].append(null)
	return array

func spawn_dots():
	for i in range(width):
		for j in range(height):
			if !restricted_fill(Vector2(i, j)):
				var rand = floor(randf_range(0, possible_dots.size()))
				var dot = possible_dots[rand].instantiate()
				var loops = 0
				while (match_at(i, j, dot.color) && loops < 100):
					rand = floor(randf_range(0,possible_dots.size()))
					loops += 1
					dot = possible_dots[rand].instantiate()
				dot.z_index = height - j
				add_child(dot)
				dot.position = grid_to_pixel(i, j)
				all_dots[i][j] = dot
			
func match_at(i, j, color):
	if i > 1:
		if all_dots[i - 1][j] != null && all_dots[i - 2][j] != null:
			if all_dots[i - 1][j].color == color && all_dots[i - 2][j].color == color:
				return true
	if j > 1:
		if all_dots[i][j - 1] != null && all_dots[i][j - 2] != null:
			if all_dots[i][j - 1].color == color && all_dots[i][j - 2].color == color:
				return true
	return false

func grid_to_pixel(column, row):
	var new_x = x_start + offset * column
	var new_y = y_start + -offset * row
	return Vector2(new_x, new_y)
	
func pixel_to_grid(pixel_x,pixel_y):
	var new_x = round((pixel_x - x_start) / offset)
	var new_y = round((pixel_y - y_start) / -offset)
	return Vector2(new_x, new_y)

func is_in_grid(grid_position):
	if grid_position.x >= 0 and grid_position.x < width:
		if grid_position.y >= 0 and grid_position.y < height:
			return true
	return false

func _input(event):
	if state != move:
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.is_pressed():
			var grid_pos = pixel_to_grid(event.position.x, event.position.y)
			if is_in_grid(grid_pos) and all_dots[grid_pos.x][grid_pos.y] != null:
				dragged_dot = all_dots[grid_pos.x][grid_pos.y]
				drag_start_position = event.position
				is_dragging = true
				dragged_dot.play_drag_sad_animation()
		else: # released
			if is_dragging and dragged_dot != null:
				is_dragging = false
				
				var start_grid_pos = pixel_to_grid(drag_start_position.x, drag_start_position.y)
				var end_grid_pos = pixel_to_grid(event.position.x, event.position.y)
				
				var difference = end_grid_pos - start_grid_pos
				
				if difference.length() > 0.5: # Threshold for a swipe
					idle_timer.start()
					var direction = Vector2.ZERO
					if abs(difference.x) > abs(difference.y):
						if difference.x > 0:
							direction = Vector2.RIGHT
						else:
							direction = Vector2.LEFT
					else:
						if difference.y > 0:
							direction = Vector2.DOWN
						else:
							direction = Vector2.UP
					swap_dots(start_grid_pos.x, start_grid_pos.y, direction)
				else:
					dragged_dot.move(grid_to_pixel(start_grid_pos.x, start_grid_pos.y))

				dragged_dot.set_normal_texture()
				dragged_dot = null
				
func swap_dots(column, row, direction):
	var first_dot = all_dots[column][row]
	var other_dot = all_dots[column + direction.x][row + direction.y]
	if first_dot != null && other_dot != null:
		# Reset dots to normal state before swapping
		first_dot.reset_to_normal_state()
		other_dot.reset_to_normal_state()
		
		var temp_z = first_dot.z_index
		first_dot.z_index = other_dot.z_index
		other_dot.z_index = temp_z
		store_info(first_dot, other_dot, Vector2(column, row), direction)
		state = wait
		all_dots[column][row] = other_dot
		all_dots[column + direction.x][row + direction.y] = first_dot
		first_dot.move(grid_to_pixel(column + direction.x, row + direction.y))
		other_dot.move(grid_to_pixel(column, row))
		
		await get_tree().create_timer(0.2).timeout
		
		if !move_checked:
			find_matches()
		
func store_info(first_dot, other_dot, place, direciton):
	dot_one = first_dot
	dot_two = other_dot
	last_place = place
	last_direction = direciton
		
func swap_back():
	if dot_one != null && dot_two != null:
		var first_dot = all_dots[last_place.x][last_place.y]
		var other_dot = all_dots[last_place.x + last_direction.x][last_place.y + last_direction.y]
		
		# Reset dots to normal state before swapping back
		first_dot.reset_to_normal_state()
		other_dot.reset_to_normal_state()
		
		var temp_z = first_dot.z_index
		first_dot.z_index = other_dot.z_index
		other_dot.z_index = temp_z
		
		all_dots[last_place.x][last_place.y] = other_dot
		all_dots[last_place.x + last_direction.x][last_place.y + last_direction.y] = first_dot
		
		first_dot.move(grid_to_pixel(last_place.x + last_direction.x, last_place.y + last_direction.y))
		other_dot.move(grid_to_pixel(last_place.x, last_place.y))

	state = move
	move_checked = false
	
func _process(_delta):
	if is_dragging and dragged_dot != null:
		var mouse_pos = get_global_mouse_position()
		dragged_dot.position = lerp(dragged_dot.position, mouse_pos, 0.2)
	
func find_matches():
	var matched_dots = []
	for i in range(width):
		for j in range(height):
			if all_dots[i][j] != null:
				var current_color = all_dots[i][j].color
				# Horizontal match check
				if i > 0 && i < width -1 and all_dots[i-1][j] != null and all_dots[i+1][j] != null:
					if all_dots[i-1][j].color == current_color and all_dots[i+1][j].color == current_color:
						matched_dots.append_array([all_dots[i-1][j], all_dots[i][j], all_dots[i+1][j]])
				# Vertical match check
				if j > 0 && j < height -1 and all_dots[i][j-1] != null and all_dots[i][j+1] != null:
					if all_dots[i][j-1].color == current_color and all_dots[i][j+1].color == current_color:
						matched_dots.append_array([all_dots[i][j-1], all_dots[i][j], all_dots[i][j+1]])
	
	if matched_dots.size() > 0:
		process_match_animations(matched_dots)
		destroy_timer.start()
	else:
		swap_back()

func process_match_animations(dots_in_match):
	var unique_dots = []
	for dot in dots_in_match:
		if dot != null and not dot in unique_dots:
			unique_dots.append(dot)

	# Play sound based on match size
	if unique_dots.size() >= 5:
		AudioManager.play_sound("match_fanfare")
	elif unique_dots.size() == 4:
		AudioManager.play_sound("match_chime")
	else:
		AudioManager.play_sound("match_pop")

	# Sort dots for systematic animation
	unique_dots.sort_custom(func(a, b): return a.position.x < b.position.x or (a.position.x == b.position.x and a.position.y < b.position.y))

	var delay = 0.0
	var matched_color = ""
	for dot in unique_dots:
		if not dot.matched:
			dot.matched = true
			dot.play_match_animation(delay)
			delay += 0.05
			if matched_color == "":
				matched_color = dot.color

	# Trigger sad animation for other dots
	if matched_color != "":
		for i in range(width):
			for j in range(height):
				var current_dot = all_dots[i][j]
				if current_dot != null and not current_dot.matched and current_dot.color == matched_color:
					current_dot.play_sad_animation()

func destroy_matches():
	var was_matched = false
	var points_earned = 0
	var match_center = Vector2.ZERO
	var match_count = 0
	for i in range(width):
		for j in range(height):
			if all_dots[i][j] != null and all_dots[i][j].matched:
				was_matched = true
				points_earned += 10
				match_center += all_dots[i][j].position
				match_count += 1
				
				# Instantiate original particles
				var particles = match_particles.instantiate()
				particles.position = all_dots[i][j].position
				add_child(particles)
				particles.emitting = true
				
				all_dots[i][j].queue_free()
				all_dots[i][j] = null
	
	if points_earned > 0:
		score += points_earned
		update_score_display()
		
		# Instantiate new effects at the center of the match
		if match_count > 0:
			match_center /= match_count

			var match_label = match_label_scene.instantiate()
			match_label.text = "+" + str(points_earned)
			match_label.position = match_center - Vector2(0, 20)
			add_child(match_label)
	
	move_checked = true
	if was_matched:
		collapse_timer.start()
	else:
		swap_back()

func collapse_columns():
	for i in range(width):
		for j in range(height):
			if all_dots[i][j] == null and not restricted_fill(Vector2(i,j)):
				for k in range(j + 1, height):
					if all_dots[i][k] != null:
						all_dots[i][k].z_index = height - j
						all_dots[i][k].move(grid_to_pixel(i, j))
						all_dots[i][j] = all_dots[i][k]
						all_dots[i][k] = null
						break
	refill_timer.start()

func refill_columns():
	for i in range(width):
		for j in range(height):
			if all_dots[i][j] == null and not restricted_fill(Vector2(i,j)):
				var rand = floor(randf_range(0, possible_dots.size()))
				var dot = possible_dots[rand].instantiate()
				var loops = 0
				while (match_at(i, j, dot.color) && loops < 100):
					rand = floor(randf_range(0,possible_dots.size()))
					loops += 1
					dot = possible_dots[rand].instantiate()
				dot.z_index = height - j
				add_child(dot)
				dot.position = grid_to_pixel(i, j - y_offset)
				var move_tween = dot.move(grid_to_pixel(i,j))
				all_dots[i][j] = dot
				
				await move_tween.finished
				AudioManager.play_sound("dot_land")
	after_refill()
				
func after_refill():
	state = wait
	await get_tree().create_timer(0.5).timeout
	
	var needs_another_pass = false
	for i in range(width):
		for j in range(height):
			if all_dots[i][j] != null:
				if match_at_refill(i, j, all_dots[i][j].color):
					needs_another_pass = true
					break
			if needs_another_pass:
				break
			
	if needs_another_pass:
		find_matches_after_refill()
	else:
		state = move
		move_checked = false

func find_matches_after_refill():
	var matched_dots = []
	for i in range(width):
		for j in range(height):
			if all_dots[i][j] != null:
				var current_color = all_dots[i][j].color
				if i > 0 && i < width -1 and all_dots[i-1][j] != null and all_dots[i+1][j] != null:
					if all_dots[i-1][j].color == current_color and all_dots[i+1][j].color == current_color:
						matched_dots.append_array([all_dots[i-1][j], all_dots[i][j], all_dots[i+1][j]])
				if j > 0 && j < height -1 and all_dots[i][j-1] != null and all_dots[i][j+1] != null:
					if all_dots[i][j-1].color == current_color and all_dots[i][j+1].color == current_color:
						matched_dots.append_array([all_dots[i][j-1], all_dots[i][j], all_dots[i][j+1]])
	if matched_dots.size() > 0:
		process_match_animations(matched_dots)
		destroy_timer.start()

func match_at_refill(i, j, color):
	if i > 1 and all_dots[i-1][j] != null and all_dots[i-2][j] != null:
		if all_dots[i-1][j].color == color and all_dots[i-2][j].color == color:
			return true
	if j > 1 and all_dots[i][j-1] != null and all_dots[i][j-2] != null:
		if all_dots[i][j-1].color == color and all_dots[i][j-2].color == color:
			return true
	return false

func _on_idle_timer_timeout():
	var hint_dot = find_potential_match()
	if hint_dot != null:
		hint_dot.play_idle_animation()
	idle_timer.start()

func find_potential_match():
	for i in range(width):
		for j in range(height):
			if all_dots[i][j] == null: continue
			
			# Test swap right
			if i < width - 1 and all_dots[i+1][j] != null:
				if can_move_create_match(i, j, Vector2.RIGHT):
					return all_dots[i][j]

			# Test swap down
			if j < height - 1 and all_dots[i][j+1] != null:
				if can_move_create_match(i, j, Vector2.DOWN):
					return all_dots[i][j]
	return null

func can_move_create_match(i, j, direction):
	var other_i = i + direction.x
	var other_j = j + direction.y
	
	var original_color = all_dots[i][j].color
	var other_color = all_dots[other_i][other_j].color
	
	all_dots[i][j].color = other_color
	all_dots[other_i][other_j].color = original_color
	
	var is_match = match_at_refill(i,j,all_dots[i][j].color) or match_at_refill(other_i, other_j, all_dots[other_i][other_j].color)

	# Swap back
	all_dots[i][j].color = original_color
	all_dots[other_i][other_j].color = other_color
	
	return is_match