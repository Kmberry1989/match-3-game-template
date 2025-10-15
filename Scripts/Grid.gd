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
    preload("res://Scenes/Dots/gray_dot.tscn")
]
@onready var match_particles = preload("res://Scenes/MatchParticles.tscn")
@onready var match_label_scene = preload("res://Scenes/MatchLabel.tscn")
@onready var xp_orb_texture = preload("res://Assets/Visuals/bright_flash.png")
var xp_orb_colors = {
    "red": Color(1.0, 0.25, 0.25),
    "orange": Color(1.0, 0.6, 0.2),
    "yellow": Color(1.0, 0.94, 0.3),
    "green": Color(0.3, 1.0, 0.5),
    "blue": Color(0.3, 0.6, 1.0),
    "purple": Color(0.7, 0.4, 1.0),
    "pink": Color(1.0, 0.5, 0.8),
    "brown": Color(0.6, 0.4, 0.3),
    "gray": Color(0.7, 0.7, 0.7)
}

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
var combo_counter = 1

var possible_colors = []

func _ready():
    state = move
    setup_timers()
    randomize()
    
    for dot_scene in possible_dots:
        var dot_instance = dot_scene.instantiate()
        possible_colors.append(dot_instance.color)
        dot_instance.queue_free()
    
    all_dots = make_2d_array()
    spawn_dots()
    
    await get_tree().process_frame
    update_score_display()
    game_ui.set_player_name(PlayerManager.get_player_name())
    AudioManager.play_music("game")

    PlayerManager.level_up.connect(_on_level_up)

    await ensure_moves_available()
    idle_timer.start()

func update_score_display():
    game_ui.update_xp_label()

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
                var rand = floor(randf_range(0, possible_colors.size()))
                var color = possible_colors[rand]
                var loops = 0
                while (match_at(i, j, color) && loops < 100):
                    rand = floor(randf_range(0, possible_colors.size()))
                    color = possible_colors[rand]
                    loops += 1
                
                var dot_scene_to_use
                for dot_scene in possible_dots:
                    var dot_instance = dot_scene.instantiate()
                    if dot_instance.color == color:
                        dot_scene_to_use = dot_scene
                        dot_instance.queue_free()
                        break
                    dot_instance.queue_free()

                var dot = dot_scene_to_use.instantiate()
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
                dragged_dot.z_index = 100 # Bring to front
                drag_start_position = event.position
                is_dragging = true
                dragged_dot.play_drag_sad_animation()
        else: # released
            if is_dragging and dragged_dot != null:
                is_dragging = false
                
                var start_grid_pos = pixel_to_grid(drag_start_position.x, drag_start_position.y)
                dragged_dot.z_index = height - start_grid_pos.y # Restore z-index
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
    combo_counter = 1
    
func _process(_delta):
    if is_dragging and dragged_dot != null:
        dragged_dot.global_position = get_global_mouse_position()
    
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

    # Trigger surprised animation for all non-matching dots
    for i in range(width):
        for j in range(height):
            var current_dot = all_dots[i][j]
            if current_dot != null and not current_dot.matched:
                current_dot.play_surprised_for_a_second()

func destroy_matches():
    var was_matched = false
    var points_earned = 0
    var match_center = Vector2.ZERO
    var match_count = 0
    for i in range(width):
        for j in range(height):
            if all_dots[i][j] != null and all_dots[i][j].matched:
                was_matched = true
                points_earned += 10 * combo_counter
                match_center += all_dots[i][j].position
                match_count += 1
                
                # Instantiate original particles
                var particles = match_particles.instantiate()
                particles.position = all_dots[i][j].position
                add_child(particles)
                _spawn_xp_orb(all_dots[i][j].global_position, all_dots[i][j].color)
                if all_dots[i][j].float_tween:
                    all_dots[i][j].float_tween.kill()
                if all_dots[i][j].pulse_tween:
                    all_dots[i][j].pulse_tween.kill()
                all_dots[i][j].queue_free()
                all_dots[i][j] = null
    
    if points_earned > 0:
        if match_count >= 5:
            AudioManager.play_sound("match_fanfare")
        elif match_count == 4:
            AudioManager.play_sound("match_chime")
        else:
            AudioManager.play_sound("match_pop")
        score += points_earned
        PlayerManager.add_xp(points_earned)
        PlayerManager.add_lines_cleared(match_count)
        PlayerManager.update_best_combo(combo_counter)
        combo_counter += 1
        update_score_display()
        
        # Instantiate new effects at the center of the match
        if match_count > 0:
            match_center /= match_count

            var match_label = match_label_scene.instantiate()
            match_label.text = "+" + str(points_earned)
            get_parent().get_node("CanvasLayer").add_child(match_label)
            match_label.global_position = match_center - Vector2(0, 20)
    
    move_checked = true
    if was_matched:
        collapse_timer.start()
    else:
        swap_back()

func _spawn_xp_orb(from_global_pos: Vector2, color_name: String = ""):
    var layer = get_parent().get_node("CanvasLayer")
    var orb = Sprite2D.new()
    orb.texture = xp_orb_texture
    orb.scale = Vector2(0.35, 0.35)
    orb.global_position = from_global_pos
    var tint = xp_orb_colors.get(color_name, Color(1,1,1))
    orb.modulate = tint
    layer.add_child(orb)
    var target = game_ui.get_xp_anchor_pos()
    var t = get_tree().create_tween()
    t.tween_property(orb, "global_position", target, 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
    t.tween_property(orb, "modulate:a", 0.0, 0.1)
    t.finished.connect(Callable(orb, "queue_free"))

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
                    dot.queue_free()
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
    # Synchronize all dots' pulsing animation
    for i in range(width):
        for j in range(height):
            if all_dots[i][j] != null:
                all_dots[i][j].start_pulsing()

    state = wait
    await get_tree().create_timer(0.5).timeout
    
    var needs_another_pass = false
    for i in range(width):
        for j in range(height):
            if all_dots[i][j] != null:
                if match_at(i, j, all_dots[i][j].color):
                    needs_another_pass = true
                    break
            if needs_another_pass:
                break
            
    if needs_another_pass:
        find_matches_after_refill()
    else:
        state = move
        move_checked = false
        await ensure_moves_available()
        state = move

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

func _on_idle_timer_timeout():
    var hint_dot = find_potential_match()
    if hint_dot != null:
        hint_dot.play_idle_animation()

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

func ensure_moves_available(max_attempts := 10):
    var attempts = 0
    while find_potential_match() == null and attempts < max_attempts:
        attempts += 1
        var shuffled = await reshuffle_board()
        if not shuffled:
            break

    if find_potential_match() == null:
        push_warning("Unable to find a valid move after reshuffling.")

    if idle_timer != null:
        idle_timer.start()

func reshuffle_board() -> bool:
    var dots = []
    var occupied_cells = []
    for i in range(width):
        for j in range(height):
            if all_dots[i][j] != null:
                dots.append(all_dots[i][j])
                occupied_cells.append(Vector2i(i, j))

    if dots.size() <= 1:
        return false

    is_dragging = false
    dragged_dot = null

    state = wait
    if AudioManager != null:
        AudioManager.play_sound("shuffle")

    var target_cells = occupied_cells.duplicate()
    target_cells.shuffle()

    var new_matrix = make_2d_array()
    var tweens = []
    var offset_range = offset * 0.3
    for idx in range(dots.size()):
        var dot = dots[idx]
        var target_cell = target_cells[idx]
        new_matrix[target_cell.x][target_cell.y] = dot
        dot.matched = false
        dot.z_index = height - target_cell.y

        var start_pos = dot.position
        var target_pos = grid_to_pixel(target_cell.x, target_cell.y)

        var tween = get_tree().create_tween()
        var random_offset = Vector2(randf_range(-offset_range, offset_range), randf_range(-offset_range, offset_range))
        tween.tween_property(dot, "position", start_pos + random_offset, 0.12).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
        tween.tween_property(dot, "position", target_pos, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
        tweens.append(tween)

    all_dots = new_matrix
    move_checked = false

    if tweens.size() > 0:
        await tweens.back().finished

    state = move
    return true

func can_move_create_match(i, j, direction):
    var other_i = i + direction.x
    var other_j = j + direction.y
    
    var original_color = all_dots[i][j].color
    var other_color = all_dots[other_i][other_j].color
    
    var temp_all_dots = []
    for x in range(width):
        temp_all_dots.append([])
        for y in range(height):
            if all_dots[x][y] != null:
                temp_all_dots[x].append(all_dots[x][y].color)
            else:
                temp_all_dots[x].append(null)
    
    temp_all_dots[i][j] = other_color
    temp_all_dots[other_i][other_j] = original_color
    
    var is_match = false
    # Check for horizontal match
    if other_i > 0 and other_i < width - 1:
        if temp_all_dots[other_i - 1][other_j] == other_color and temp_all_dots[other_i + 1][other_j] == other_color:
            is_match = true
    # Check for vertical match
    if not is_match and other_j > 0 and other_j < height - 1:
        if temp_all_dots[other_i][other_j - 1] == other_color and temp_all_dots[other_i][other_j + 1] == other_color:
            is_match = true

    # Check for horizontal match for the original dot
    if not is_match and i > 0 and i < width - 1:
        if temp_all_dots[i - 1][j] == original_color and temp_all_dots[i + 1][j] == original_color:
            is_match = true
    # Check for vertical match for the original dot
    if not is_match and j > 0 and j < height - 1:
        if temp_all_dots[i][j - 1] == original_color and temp_all_dots[i][j + 1] == original_color:
            is_match = true

    return is_match

func _on_level_up(new_level):
    print("Level up to: " + str(new_level))
    await celebrate_stage_transition(new_level)
    # Clear and respawn for next stage
    for i in range(width):
        for j in range(height):
            if all_dots[i][j] != null:
                all_dots[i][j].queue_free()
    all_dots = make_2d_array()
    spawn_dots()
    await ensure_moves_available()
    state = move

func celebrate_stage_transition(new_level):
    state = wait
    await play_wave_animation()
    await play_dance_animation()
    await show_stage_banner(new_level)
    state = move

func play_wave_animation():
    var row_delay = 0.0
    for j in range(height):
        var col_delay = 0.0
        for i in range(width):
            var dot = all_dots[i][j]
            if dot == null:
                continue
            var tween = get_tree().create_tween()
            tween.tween_interval(row_delay + col_delay)
            var up_pos = dot.position + Vector2(0, -14)
            tween.tween_property(dot, "position", up_pos, 0.12).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
            tween.tween_property(dot, "position", dot.position, 0.12).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
            col_delay += 0.05
        row_delay += 0.12
    # Allow final tweens to finish
    await get_tree().create_timer(0.6 + row_delay).timeout

func play_dance_animation():
    # Small wiggle/scale for a short duration
    var max_duration = 0.6
    for i in range(width):
        for j in range(height):
            var dot = all_dots[i][j]
            if dot == null:
                continue
            var tween = get_tree().create_tween()
            tween.tween_property(dot, "rotation_degrees", 8, 0.15)
            tween.parallel().tween_property(dot, "scale", dot.scale * 1.08, 0.15)
            tween.tween_property(dot, "rotation_degrees", -8, 0.15)
            tween.parallel().tween_property(dot, "scale", dot.scale, 0.15)
    await get_tree().create_timer(max_duration).timeout

func show_stage_banner(new_level):
    var layer = get_parent().get_node("CanvasLayer")
    var label = Label.new()
    label.text = "Stage " + str(new_level)
    label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    label.add_theme_font_size_override("font_size", 48)
    label.modulate.a = 0.0
    label.scale = Vector2(0.5, 0.5)
    layer.add_child(label)
    label.set_anchors_preset(Control.PRESET_CENTER)
    # Animate flash and zoom
    var t = get_tree().create_tween()
    t.tween_property(label, "modulate:a", 1.0, 0.2)
    t.parallel().tween_property(label, "scale", Vector2(1.2, 1.2), 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
    await t.finished
    await get_tree().create_timer(0.6).timeout
    var t2 = get_tree().create_tween()
    t2.tween_property(label, "modulate:a", 0.0, 0.3)
    await t2.finished
    label.queue_free()

