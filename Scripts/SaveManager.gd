extends Node

const SAVE_PATH := "user://player.json"

func has_player() -> bool:
	return FileAccess.file_exists(SAVE_PATH)

func load_player() -> Dictionary:
	if not has_player():
		return {}
	var text := FileAccess.get_file_as_string(SAVE_PATH)
	if typeof(text) == TYPE_STRING and text != "":
		var parsed = JSON.parse_string(text)
		if typeof(parsed) == TYPE_DICTIONARY:
			return parsed
	return {}

func save_player(data: Dictionary) -> bool:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(data))
	f.close()
	return true

# Optional lightweight localStorage helpers for Web
func web_save_json(key: String, data: Variant) -> void:
	if OS.has_feature("web") and OS.has_feature("JavaScript"):
		var s := JSON.stringify(data)
		JavaScriptBridge.eval("localStorage.setItem(" + JSON.stringify(key) + "," + JSON.stringify(s) + ")")

func web_load_json(key: String, default := {}) -> Variant:
	if OS.has_feature("web") and OS.has_feature("JavaScript"):
		var s = JavaScriptBridge.eval("localStorage.getItem(" + JSON.stringify(key) + ")")
		if s != null:
			var parsed = JSON.parse_string(str(s))
			return parsed if parsed != null else default
	return default
