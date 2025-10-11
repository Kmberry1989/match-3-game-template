extends Node

signal level_up(new_level)

var player_uid = ""
var player_data = {
	"player_name": "",
	"time_played": 0,
	"current_level": 1,
	"current_xp": 0,
	"best_combo": 0,
	"total_lines_cleared": 0,
	"current_frame": "default",
	"unlocks": {
		"trophies": [],
		"frames": ["default", "frame_2"],
		"aliases": []
	},
	"objectives": {
		"time_played_1hr": false
	}
}

func _ready():
	if not Engine.has_singleton("Firebase"):
		print("Firebase plugin not found. PlayerManager will not work.")
		return

	Firebase.Firestore.document_loaded.connect(Callable(self, "_on_document_loaded"))
	Firebase.Firestore.document_saved.connect(Callable(self, "_on_document_saved"))
	Firebase.Firestore.document_error.connect(Callable(self, "_on_document_error"))

func load_player_data(user_info):
	if not Engine.has_singleton("Firebase"):
		return

	player_uid = user_info.get("uid")
	if player_uid:
		Firebase.Firestore.get_document("players", player_uid)
	else:
		print("No UID found in user_info")


func _on_document_loaded(doc_data):
	if doc_data:
		print("Player data loaded from Firestore.")
		player_data = doc_data
	else:
		# New player, create default data and save it
		print("New player. Creating default data.")
		var user_info = Firebase.Auth.get_user()
		player_data["player_name"] = user_info.get("displayName", "Player")
		save_player_data()

func save_player_data():
	if not Engine.has_singleton("Firebase") or player_uid == "":
		return

	Firebase.Firestore.set_document("players", player_uid, player_data)

func _on_document_saved():
	print("Player data saved to Firestore.")

func _on_document_error(error_message):
	print("Firestore error: " + error_message)


func get_player_name():
	return player_data["player_name"]

func add_time_played(seconds):
	player_data["time_played"] += seconds
	check_objectives()
	save_player_data()

func get_xp_for_next_level():
	return 100 * player_data["current_level"]

func add_xp(amount):
	player_data["current_xp"] += amount
	while player_data["current_xp"] >= get_xp_for_next_level():
		player_data["current_xp"] -= get_xp_for_next_level()
		player_data["current_level"] += 1
		emit_signal("level_up", player_data["current_level"])
	save_player_data()

func update_best_combo(new_combo):
	if new_combo > player_data["best_combo"]:
		player_data["best_combo"] = new_combo
		save_player_data()

func add_lines_cleared(lines):
	player_data["total_lines_cleared"] += lines
	save_player_data()

func check_objectives():
	# Check for time played
	if player_data["time_played"] >= 3600 and not player_data["objectives"]["time_played_1hr"]:
		player_data["objectives"]["time_played_1hr"] = true
		unlock_trophy("time_played_1hr_trophy")

signal trophy_unlocked(trophy_resource)

func unlock_trophy(trophy_id):
	if not trophy_id in player_data["unlocks"]["trophies"]:
		player_data["unlocks"]["trophies"].append(trophy_id)
		var trophy_resource = load("res://Assets/Trophies/" + trophy_id + ".tres")
		emit_signal("trophy_unlocked", trophy_resource)

func set_current_frame(frame_name):
	player_data["current_frame"] = frame_name
	save_player_data()

func get_current_frame():
	return player_data["current_frame"]

func get_current_xp():
	return player_data["current_xp"]

func get_current_level():
	return player_data["current_level"]
