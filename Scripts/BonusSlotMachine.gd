extends Control
class_name BonusSlotMachine

signal finished

const SYMBOL_SIZE: Vector2i = Vector2i(320, 320)
const SYMBOL_DIR: String = "res://Assets/BonusSlot"
var _symbol_size: Vector2i = SYMBOL_SIZE

enum SymbolId { COIN, XP, WILDCARD, ROW_CLEAR, COL_CLEAR, MULT2X, MULT3X, FREE_SPIN }

var _symbols: Array = []
var _result_label: Label = null
var _spin_button: BaseButton = null
var _reels: Array[Control] = []
var _stops: Array[int] = []
var _spinning: bool = false
var _glows: Array[TextureRect] = []
var _attempts: int = 0
var _finished: bool = false
var _success_done: bool = false

func _ready() -> void:
	_layout_for_viewport()
	_symbols = [
		{"id": SymbolId.COIN, "name": "COIN", "color": Color(1.0, 0.85, 0.2)},
		{"id": SymbolId.XP, "name": "XP", "color": Color(0.3, 0.7, 1.0)},
		{"id": SymbolId.WILDCARD, "name": "WILD", "color": Color(0.9, 0.4, 1.0)},
		{"id": SymbolId.ROW_CLEAR, "name": "ROW", "color": Color(0.9, 0.3, 0.3)},
		{"id": SymbolId.COL_CLEAR, "name": "COL", "color": Color(0.3, 0.9, 0.4)},
		{"id": SymbolId.MULT2X, "name": "2x", "color": Color(1.0, 0.6, 0.2)},
		{"id": SymbolId.MULT3X, "name": "3x", "color": Color(1.0, 0.3, 0.2)},
		{"id": SymbolId.FREE_SPIN, "name": "FREE", "color": Color(0.8, 0.8, 0.8)}
	]
	_result_label = $Panel/VBox/ResultLabel as Label
	_spin_button = $Panel/VBox/HBox/SpinButton as BaseButton
	_reels = [
		$Panel/VBox/Reels/Reel1 as Control,
		$Panel/VBox/Reels/Reel2 as Control,
		$Panel/VBox/Reels/Reel3 as Control
	]
	_glows = [
		$Panel/VBox/Reels/Reel1/Glow as TextureRect,
		$Panel/VBox/Reels/Reel2/Glow as TextureRect,
		$Panel/VBox/Reels/Reel3/Glow as TextureRect
	]
	# Load any provided symbol_* textures before building reels so tiles use your art
	_load_symbol_textures()
	for r in _reels:
		_build_reel(r)
	_apply_assets()

func _notification(what):
	if what == NOTIFICATION_RESIZED:
		if not is_inside_tree():
			return
		_layout_for_viewport()

func _build_reel(reel: Control) -> void:
	reel.clip_contents = true
	reel.custom_minimum_size = Vector2(_symbol_size)
	var track: VBoxContainer = VBoxContainer.new()
	track.name = "Track"
	track.position = Vector2.ZERO
	track.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	track.size_flags_vertical = Control.SIZE_FILL
	for _i in range(3):
		for s_idx in range(_symbols.size()):
			var tile: Control = _make_symbol_tile(_symbols[s_idx])
			track.add_child(tile)
	track.add_child(_make_symbol_tile(_symbols[0]))
	reel.add_child(track)

func _make_symbol_tile(sym: Dictionary) -> Control:
	var tile: Panel = Panel.new()
	tile.custom_minimum_size = Vector2(_symbol_size)
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = Color(sym.get("color", Color(0.5,0.5,0.5)))
	sb.border_width_left = 2
	sb.border_width_right = 2
	sb.border_width_top = 2
	sb.border_width_bottom = 2
	sb.border_color = Color(0,0,0,0.6)
	sb.corner_radius_top_left = 16
	sb.corner_radius_top_right = 16
	sb.corner_radius_bottom_left = 16
	sb.corner_radius_bottom_right = 16
	tile.add_theme_stylebox_override("panel", sb)
	var tex: Texture2D = sym.get("tex", null)
	if tex != null:
		# Use your provided art; make tile background transparent so color doesn't cover it
		sb.bg_color = Color(0,0,0,0)
		var tr: TextureRect = TextureRect.new()
		tr.texture = tex
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tr.size_flags_vertical = Control.SIZE_EXPAND_FILL
		tile.add_child(tr)
	else:
		var lbl: Label = Label.new()
		lbl.text = String(sym.get("name", "?"))
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lbl.add_theme_font_size_override("font_size", 64)
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lbl.size_flags_vertical = Control.SIZE_EXPAND_FILL
		tile.add_child(lbl)
	return tile

func _on_SpinButton_pressed() -> void:
	if _spinning or _finished:
		return
	# Allow up to 3 spin attempts total
	if _attempts >= 3:
		_finish_after_delay()
		return
	_attempts += 1
	_spinning = true
	_result_label.text = ""
	_spin_button.disabled = true
	if AudioManager != null:
		AudioManager.play_sound("slot_spin")
	_stops.clear()
	for _i in range(3):
		_stops.append(_pick_symbol_index())
	for idx in range(_reels.size()):
		_spin_reel(_reels[idx], _stops[idx], 1.2 + 0.15 * float(idx))

func _pick_symbol_index() -> int:
	var weights: Array[int] = [25, 20, 10, 8, 8, 12, 5, 12]
	var total: int = 0
	for w in weights:
		total += w
	var r: float = randf() * float(total)
	var acc: float = 0.0
	for i in range(weights.size()):
		acc += float(weights[i])
		if r <= acc:
			return i
	return 0

func _spin_reel(reel: Control, stop_index: int, duration: float) -> void:
	var track: VBoxContainer = reel.get_node("Track") as VBoxContainer
	var tile_h: float = float(_symbol_size.y)
	var per_loop: int = _symbols.size()
	var loops: int = 2
	var final_index: int = per_loop * loops + stop_index
	var final_y: float = -tile_h * float(final_index)
	track.position = Vector2(0, 0)
	var tick: Timer = Timer.new()
	tick.one_shot = false
	tick.wait_time = 0.08
	add_child(tick)
	tick.timeout.connect(func():
		if AudioManager != null:
			AudioManager.play_sound("slot_tick")
	)
	tick.start()
	var t: Tween = create_tween()
	t.tween_property(track, "position:y", final_y, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await t.finished
	track.position = Vector2(0, -tile_h * float(stop_index))
	if tick != null:
		tick.stop()
		tick.queue_free()
	if AudioManager != null:
		AudioManager.play_sound("slot_stop")
	var last_reel: bool = (reel == _reels[_reels.size() - 1])
	if last_reel:
		_evaluate_result()

func _evaluate_result() -> void:
	_spinning = false
	_spin_button.disabled = false
	var ids: Array[int] = []
	for i in range(3):
		var idx: int = int(_stops[i])
		ids.append(int(_symbols[idx]["id"]))
	var msg: String = ""
	var success: bool = false
	var free_spin: bool = false
	if ids[0] == ids[1] and ids[1] == ids[2]:
		msg = _apply_payout_3(ids[0])
		_show_reel_glows([true, true, true])
		if AudioManager != null:
			AudioManager.play_sound("slot_win")
		_confetti_burst_from([true, true, true], 1.0)
		# Special case: 3x FREE_SPIN grants an immediate extra spin and should not count against attempts
		if ids[0] == SymbolId.FREE_SPIN:
			free_spin = true
			success = false
		else:
			success = true
	elif ids[0] == ids[1] or ids[1] == ids[2] or ids[0] == ids[2]:
		var sym2: int = _majority_symbol(ids)
		msg = _apply_payout_2(sym2)
		var mask: Array[bool] = [false, false, false]
		for i in range(3):
			if ids[i] == sym2:
				mask[i] = true
		_show_reel_glows(mask)
		if AudioManager != null:
			AudioManager.play_sound("slot_win")
		_confetti_burst_from(mask, 0.6)
		success = true
	else:
		msg = _apply_payout_mixed()
		_show_reel_glows([false, false, false])
		if AudioManager != null:
			AudioManager.play_sound("slot_fail")
	_result_label.text = msg
	# Handle free spin: do not count this attempt; auto-spin again after a short delay
	if free_spin:
		if _attempts > 0:
			_attempts -= 1
		await get_tree().create_timer(0.6).timeout
		_on_SpinButton_pressed()
		return

	# Finish conditions: any success immediately, or after 3 total attempts
	if success and not _success_done:
		_success_done = true
		_finish_after_delay()
	elif _attempts >= 3:
		_finish_after_delay()

func _majority_symbol(ids: Array[int]) -> int:
	if ids[0] == ids[1]:
		return ids[0]
	if ids[1] == ids[2]:
		return ids[1]
	return ids[0]

func _apply_payout_3(sym_id: int) -> String:
	match sym_id:
		SymbolId.COIN:
			PlayerManager.player_data["coins"] = PlayerManager.get_coins() + 100
			PlayerManager.emit_signal("coins_changed", PlayerManager.get_coins())
			PlayerManager.save_player_data()
			return "+100 Coins!"
		SymbolId.XP:
			PlayerManager.add_xp(600)
			return "+600 XP!"
		SymbolId.WILDCARD:
			_set_pending_bonus({"wildcards": 3})
			return "Next stage: 3 wildcards!"
		SymbolId.ROW_CLEAR:
			_set_pending_bonus({"clear_rows": 2})
			return "Next stage: clear 2 rows!"
		SymbolId.COL_CLEAR:
			_set_pending_bonus({"clear_cols": 2})
			return "Next stage: clear 2 cols!"
		SymbolId.MULT2X:
			_set_pending_bonus({"xp_multiplier": {"mult": 2, "matches": 3}})
			return "Next 3 matches: 2x XP!"
		SymbolId.MULT3X:
			_set_pending_bonus({"xp_multiplier": {"mult": 3, "matches": 1}})
			return "Next match: 3x XP!"
		SymbolId.FREE_SPIN:
			return "Free spin!"
		_:
			return ""

func _apply_payout_2(sym_id: int) -> String:
	match sym_id:
		SymbolId.COIN:
			PlayerManager.player_data["coins"] = PlayerManager.get_coins() + 20
			PlayerManager.emit_signal("coins_changed", PlayerManager.get_coins())
			PlayerManager.save_player_data()
			return "+20 Coins"
		SymbolId.XP:
			PlayerManager.add_xp(120)
			return "+120 XP"
		SymbolId.WILDCARD:
			_set_pending_bonus({"wildcards": 1})
			return "Next stage: 1 wildcard"
		SymbolId.ROW_CLEAR:
			_set_pending_bonus({"clear_rows": 1})
			return "Next stage: clear 1 row"
		SymbolId.COL_CLEAR:
			_set_pending_bonus({"clear_cols": 1})
			return "Next stage: clear 1 col"
		SymbolId.MULT2X:
			_set_pending_bonus({"xp_multiplier": {"mult": 2, "matches": 1}})
			return "Next match: 2x XP"
		SymbolId.MULT3X:
			_set_pending_bonus({"xp_multiplier": {"mult": 3, "matches": 1}})
			return "Next match: 3x XP"
		SymbolId.FREE_SPIN:
			return "Free spin chance"
		_:
			return ""

func _apply_payout_mixed() -> String:
	PlayerManager.player_data["coins"] = PlayerManager.get_coins() + 10
	PlayerManager.emit_signal("coins_changed", PlayerManager.get_coins())
	PlayerManager.save_player_data()
	return "+10 Coins"

func _set_pending_bonus(payload: Dictionary) -> void:
	var pending: Dictionary = {}
	if typeof(PlayerManager.player_data) == TYPE_DICTIONARY:
		pending = PlayerManager.player_data.get("pending_bonus", {})
		for k in payload.keys():
			pending[k] = payload[k]
		PlayerManager.player_data["pending_bonus"] = pending
		PlayerManager.save_player_data()

func _on_CloseButton_pressed() -> void:
	emit_signal("finished")
	queue_free()

func _apply_assets() -> void:
	var bg_path: String = "res://Assets/BonusSlot/slot_bg.png"
	var frame_path: String = "res://Assets/BonusSlot/slot_frame.png"
	var glow_path: String = "res://Assets/BonusSlot/slot_light.png"
	var btn_path: String = "res://Assets/BonusSlot/slot_button_spin.png"
	if FileAccess.file_exists(bg_path):
		var bg_tex: Texture2D = load(bg_path) as Texture2D
		var bg: TextureRect = get_node_or_null("Background") as TextureRect
		if bg != null and bg_tex != null:
			bg.texture = bg_tex
			bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	if FileAccess.file_exists(frame_path):
		var fr_tex: Texture2D = load(frame_path) as Texture2D
		var frame: TextureRect = get_node_or_null("Frame") as TextureRect
		if frame != null and fr_tex != null:
			frame.texture = fr_tex
			frame.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	if FileAccess.file_exists(btn_path):
		var btex: Texture2D = load(btn_path) as Texture2D
		if _spin_button != null and btex != null:
			var tb: TextureButton = _spin_button as TextureButton
			if tb != null:
				var b_hover_path: String = "res://Assets/BonusSlot/slot_button_spin_hover.png"
				var b_press_path: String = "res://Assets/BonusSlot/slot_button_spin_pressed.png"
				tb.texture_normal = btex
				if FileAccess.file_exists(b_hover_path):
					var bhov: Texture2D = load(b_hover_path) as Texture2D
					tb.texture_hover = bhov
				else:
					tb.texture_hover = btex
				if FileAccess.file_exists(b_press_path):
					var bprs: Texture2D = load(b_press_path) as Texture2D
					tb.texture_pressed = bprs
				else:
					tb.texture_pressed = btex
				tb.custom_minimum_size = btex.get_size()
			else:
				var btn: Button = _spin_button as Button
				if btn != null:
					btn.icon = btex
					btn.text = "SPIN"
					btn.expand_icon = true
					btn.icon_alignment = HorizontalAlignment.HORIZONTAL_ALIGNMENT_CENTER
					btn.custom_minimum_size = btex.get_size()
	if FileAccess.file_exists(glow_path):
		var gtex: Texture2D = load(glow_path) as Texture2D
		for g in _glows:
			if g == null:
				continue
			g.texture = gtex
			g.visible = false
			var mat: CanvasItemMaterial = CanvasItemMaterial.new()
			mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
			g.material = mat
			g.modulate = Color(1,1,1,0.0)

func _load_symbol_textures() -> void:
	# Try exact filenames first; then fall back to a directory index with multiple naming variants
	var exact: Dictionary = {
		SymbolId.COIN: "res://Assets/BonusSlot/symbol_coin.png",
		SymbolId.XP: "res://Assets/BonusSlot/symbol_xp.png",
		SymbolId.WILDCARD: "res://Assets/BonusSlot/symbol_wildcard.png",
		SymbolId.ROW_CLEAR: "res://Assets/BonusSlot/symbol_row_clear.png",
		SymbolId.COL_CLEAR: "res://Assets/BonusSlot/symbol_col_clear.png",
		# Match actual filenames with underscores
		SymbolId.MULT2X: "res://Assets/BonusSlot/symbol_multiplier_2x.png",
		SymbolId.MULT3X: "res://Assets/BonusSlot/symbol_multiplier_3x.png",
		SymbolId.FREE_SPIN: "res://Assets/BonusSlot/symbol_free_spin.png"
	}
	var index: Dictionary = _index_assets_in_dir(SYMBOL_DIR)
	for i in range(_symbols.size()):
		var sym: Dictionary = _symbols[i]
		var sid: int = int(sym.get("id", -1))
		var tex: Texture2D = null
		if exact.has(sid):
			var path: String = exact[sid]
			if FileAccess.file_exists(path):
				tex = load(path) as Texture2D
		if tex == null:
			var bases: Array[String] = []
			match sid:
				SymbolId.COIN:
					bases = ["symbol_coin", "coin"]
				SymbolId.XP:
					bases = ["symbol_xp", "xp"]
				SymbolId.WILDCARD:
					bases = ["symbol_wildcard", "wildcard", "wild"]
				SymbolId.ROW_CLEAR:
					bases = ["symbol_row_clear", "row_clear", "row"]
				SymbolId.COL_CLEAR:
					bases = ["symbol_col_clear", "col_clear", "column"]
				SymbolId.MULT2X:
					bases = ["symbol_multiplier2x", "symbol_multiplier_2x", "multiplier2x", "multiplier_2x", "2x"]
				SymbolId.MULT3X:
					bases = ["symbol_multiplier3x", "symbol_multiplier_3x", "multiplier3x", "multiplier_3x", "3x"]
				SymbolId.FREE_SPIN:
					bases = ["symbol_free_spin", "free_spin", "free"]
				_:
					bases = []
			tex = _load_first_match_tex(index, bases)
		if tex != null:
			_symbols[i]["tex"] = tex

func _index_assets_in_dir(dir_path: String) -> Dictionary:
	var result: Dictionary = {}
	var exts: Array[String] = [".png",".jpg",".jpeg"]
	var d: DirAccess = DirAccess.open(dir_path)
	if d == null:
		return result
	d.list_dir_begin()
	var fn: String = d.get_next()
	while fn != "":
		if not d.current_is_dir():
			var lower: String = fn.to_lower()
			for e in exts:
				if lower.ends_with(e):
					result[lower] = dir_path.path_join(fn)
					break
		fn = d.get_next()
	d.list_dir_end()
	return result

func _load_first_match_tex(index: Dictionary, bases: Array) -> Texture2D:
	var exts: Array[String] = [".png",".jpg",".jpeg"]
	for b in bases:
		var base_lower: String = String(b).to_lower()
		for e in exts:
			var key: String = base_lower + e
			if index.has(key):
				var tex: Texture2D = load(index[key]) as Texture2D
				if tex != null:
					return tex
	return null

func _show_reel_glows(mask: Array) -> void:
	for i in range(min(3, mask.size())):
		var g: TextureRect = _glows[i]
		if g == null:
			continue
		var target: float = 0.65 if mask[i] else 0.0
		g.visible = target > 0.0
		var t: Tween = create_tween()
		t.tween_property(g, "modulate:a", target, 0.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		if target > 0.0:
			g.scale = Vector2.ONE
			var p: Tween = create_tween()
			p.tween_property(g, "scale", Vector2(1.12, 1.12), 0.18).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
			p.tween_property(g, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)

func _reel_centers_local() -> Array:
	var centers: Array = []
	for r in _reels:
		if r != null:
			centers.append(_to_local_canvas((r as Control).get_global_rect().get_center()))
		else:
			centers.append(Vector2.ZERO)
	return centers

func _to_local_canvas(global_point: Vector2) -> Vector2:
	var inv: Transform2D = get_global_transform_with_canvas().affine_inverse()
	return inv * global_point

func _confetti_burst_from(mask: Array, intensity: float = 1.0) -> void:
	var centers: Array = _reel_centers_local()
	for i in range(min(mask.size(), centers.size())):
		if not mask[i]:
			continue
		var origin: Vector2 = centers[i]
		_spawn_confetti_at(origin, intensity)

func _spawn_confetti_at(origin: Vector2, intensity: float) -> void:
	var count: int = int(30.0 * clamp(intensity, 0.2, 2.0))
	var palette: Array = [
		Color(1.0, 0.3, 0.3),
		Color(1.0, 0.7, 0.2),
		Color(1.0, 1.0, 0.3),
		Color(0.3, 1.0, 0.5),
		Color(0.3, 0.6, 1.0),
		Color(0.7, 0.4, 1.0),
		Color(1.0, 0.5, 0.8),
		Color(1.0, 1.0, 1.0)
	]
	for j in range(count):
		var cr: ColorRect = ColorRect.new()
		cr.color = palette[randi() % palette.size()]
		var w: float = randf_range(6.0, 12.0)
		var h: float = randf_range(3.0, 8.0)
		cr.size = Vector2(w, h)
		cr.pivot_offset = cr.size * 0.5
		var jitter: Vector2 = Vector2(randf_range(-8.0, 8.0), randf_range(-8.0, 8.0))
		cr.position = origin + jitter - cr.pivot_offset
		cr.z_index = 20
		add_child(cr)
		var base_ang: float = -PI * 0.5
		var spread: float = PI * 0.7
		var ang: float = base_ang + randf_range(-spread * 0.5, spread * 0.5)
		var dist: float = randf_range(180.0, 420.0) * intensity
		var dir: Vector2 = Vector2(cos(ang), sin(ang))
		var rise: float = randf_range(80.0, 160.0)
		var fall: float = randf_range(160.0, 260.0)
		var peak: Vector2 = origin + dir * (dist * 0.55) + Vector2(0.0, -rise)
		var target: Vector2 = origin + dir * dist + Vector2(0.0, fall)
		var dur_up: float = randf_range(0.28, 0.38)
		var dur_down: float = randf_range(0.42, 0.58)
		var total_dur: float = dur_up + dur_down
		var rot: float = randf_range(-7.0, 7.0)
		var t_move: Tween = create_tween()
		t_move.tween_property(cr, "position", peak - cr.pivot_offset, dur_up).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		t_move.tween_property(cr, "position", target - cr.pivot_offset, dur_down).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		var t_rot: Tween = create_tween()
		t_rot.tween_property(cr, "rotation", rot, total_dur).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		var t_scale: Tween = create_tween()
		t_scale.tween_property(cr, "scale", Vector2(1.06, 1.06), dur_up * 0.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		t_scale.tween_property(cr, "scale", Vector2(1.0, 1.0), dur_down).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		var t_fade: Tween = create_tween()
		t_fade.tween_interval(total_dur * 0.75)
		t_fade.tween_property(cr, "modulate:a", 0.0, 0.28).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		t_fade.finished.connect(func():
			if is_instance_valid(cr):
				cr.queue_free()
		)

func _finish_after_delay() -> void:
	if _finished:
		return
	_finished = true
	_spin_button.disabled = true
	await get_tree().create_timer(0.6).timeout
	emit_signal("finished")
	queue_free()

func _layout_for_viewport() -> void:
	# Compute responsive panel size and reel window size for portrait/landscape
	var vp: Vector2 = get_viewport().get_visible_rect().size
	var is_portrait: bool = vp.y > vp.x
	var panel: Panel = get_node_or_null("Panel") as Panel
	if panel != null:
		# Fit panel within viewport with margins
		var margin_w: float = 40.0
		var margin_h: float = 80.0
		var panel_w: float = clamp(vp.x - margin_w, 360.0, 1280.0)
		var panel_h: float = clamp(vp.y - margin_h, 480.0, 1000.0)
		# Use more vertical space in portrait
		if is_portrait:
			panel_h = clamp(vp.y - margin_h, 640.0, 1200.0)
		panel.offset_left = -panel_w * 0.5
		panel.offset_right = panel_w * 0.5
		panel.offset_top = -panel_h * 0.5
		panel.offset_bottom = panel_h * 0.5
	# Compute reel window size so three reels fit horizontally with separation in portrait
	var sep: float = 24.0
	var usable_w: float = vp.x * 0.88 - 2.0 * sep
	var target: int = int(floor(usable_w / 3.0))
	# Clamp between 140 and base 320
	target = clamp(target, 140, 320)
	_symbol_size = Vector2i(target, target)
