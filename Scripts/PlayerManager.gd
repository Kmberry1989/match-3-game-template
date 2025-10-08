extends Node

var player_uid = ""
var player_data = {
	"player_name": "",
	"time_played": 0,
	"pvp_wins": 0,
	"pvp_losses": 0,
	"current_frame": "default",
	"unlocks": {
		"trophies": [],
		"frames": ["default", "frame_2"],
		"aliases": []
	},
	"objectives": {
		"time_played_1hr": false,
		"first_win": false
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
	save_player_data()

func increment_pvp_wins():
	player_data["pvp_wins"] += 1
	check_objectives()
	save_player_data()

func increment_pvp_losses():
	player_data["pvp_losses"] += 1
	save_player_data()

func check_objectives():
	# Check for first win
	if player_data["pvp_wins"] >= 1 and not player_data["objectives"]["first_win"]:
		player_data["objectives"]["first_win"] = true
		unlock_trophy("first_win_trophy")

	# Check for time played
	if player_data["time_played"] >= 3600 and not player_data["objectives"]["time_played_1hr"]:
		player_data["objectives"]["time_played_1hr"] = true
		unlock_trophy("time_played_1hr_trophy")

func unlock_trophy(trophy_name):
	if not trophy_name in player_data["unlocks"]["trophies"]:
		player_data["unlocks"]["trophies"].append(trophy_name)

func set_current_frame(frame_name):
	player_data["current_frame"] = frame_name
	save_player_data()

func get_current_frame():
	return player_data["current_frame"]
