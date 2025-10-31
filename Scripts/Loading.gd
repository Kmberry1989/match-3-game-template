extends Node

const GAME_SCENE_PATH := "res://Scenes/Game.tscn"

var _is_thread_load_active := false

func _ready():
	print("[Loading.gd] _ready: Intermediate loading scene is ready.")
	
	# Threading is unreliable on Web, especially iOS Safari.
	if OS.has_feature("web"):
		print("[Loading.gd] Web platform detected, using synchronous loading.")
		_load_scene_sync()
		return

	# Use threaded loading for native platforms
	var err := ResourceLoader.load_threaded_request(GAME_SCENE_PATH)
	if err != OK:
		push_warning("[Loading.gd] _ready: Threaded load request failed, falling back to synchronous load.")
		_load_scene_sync()
		return
	
	_is_thread_load_active = true
	set_process(true)

func _process(_delta):
	if !_is_thread_load_active:
		return
	
	var status := ResourceLoader.load_threaded_get_status(GAME_SCENE_PATH)
	match status:
		ResourceLoader.ThreadLoadStatus.THREAD_LOAD_IN_PROGRESS:
			# Here you could update a progress bar, for example.
			# var progress = ResourceLoader.load_threaded_get_progress(GAME_SCENE_PATH)
			# $ProgressBar.value = progress[0] / progress[1]
			return
		
		ResourceLoader.ThreadLoadStatus.THREAD_LOAD_LOADED:
			_is_thread_load_active = false
			set_process(false)
			var packed_scene := ResourceLoader.load_threaded_get(GAME_SCENE_PATH)
			if packed_scene is PackedScene:
				print("[Loading.gd] _process: Threaded load complete, switching to Game scene.")
				call_deferred("_change_to_loaded_scene", packed_scene)
			else:
				push_warning("[Loading.gd] _process: Loaded resource is invalid, retrying synchronously.")
				_load_scene_sync()
				
		ResourceLoader.ThreadLoadStatus.THREAD_LOAD_FAILED, ResourceLoader.ThreadLoadStatus.THREAD_LOAD_INVALID_RESOURCE:
			_is_thread_load_active = false
			set_process(false)
			push_warning("[Loading.gd] _process: Threaded load failed, falling back to synchronous load.")
			_load_scene_sync()

func _change_to_loaded_scene(packed_scene: PackedScene) -> void:
	var tree := get_tree()
	if tree == null:
		push_error("[Loading.gd] _change_to_loaded_scene: SceneTree not available.")
		return
	tree.change_scene_to_packed(packed_scene)

func _load_scene_sync() -> void:
	print("[Loading.gd] _load_scene_sync: Loading Game scene synchronously.")
	var packed_scene := ResourceLoader.load(GAME_SCENE_PATH)
	if packed_scene is PackedScene:
		call_deferred("_change_to_loaded_scene", packed_scene)
	else:
		push_error("[Loading.gd] _load_scene_sync: Failed to load Game scene.")
