extends Node

@onready var firebase = get_node_or_null("/root/Firebase")

signal level_up(new_level)
signal frame_changed(new_frame)
signal coins_changed(new_amount)

var player_uid = ""
var last_user_info: Dictionary = {}
var player_data = {
	"player_name": "",
	"time_played": 0,
	"current_level": 1,
	"current_xp": 0,
	"coins": 0,
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
	if firebase == null:
		print("Firebase not available: running offline (cloud save disabled).")
		return

	firebase.Firestore.document_loaded.connect(Callable(self, "_on_document_loaded"))
	firebase.Firestore.document_saved.connect(Callable(self, "_on_document_saved"))
	firebase.Firestore.document_error.connect(Callable(self, "_on_document_error"))

func load_player_data(user_info):
	if firebase == null:
		return

	last_user_info = user_info if typeof(user_info) == TYPE_DICTIONARY else {}
	var uid = ""
	if last_user_info.has("uid"):
		uid = str(last_user_info.get("uid"))
	elif last_user_info.has("localid"):
		uid = str(last_user_info.get("localid"))
	elif last_user_info.has("userid"):
		uid = str(last_user_info.get("userid"))
	elif last_user_info.has("user_id"):
		uid = str(last_user_info.get("user_id"))
	player_uid = uid
	if player_uid:
		firebase.Firestore.get_document("players", player_uid)
	else:
		print("No UID found in user_info")


func _on_document_loaded(doc_data):
	if doc_data:
		print("Player data loaded from Firestore.")
		player_data = doc_data
	else:
		# New player, create default data and save it
		print("New player. Creating default data.")
		var display = ""
		if typeof(last_user_info) == TYPE_DICTIONARY:
			display = str(last_user_info.get("displayname", last_user_info.get("displayName", "")))
		if display == "":
			display = "Player"
		player_data["player_name"] = display
		save_player_data()

func save_player_data():
	if firebase == null or player_uid == "":
		return

	firebase.Firestore.set_document("players", player_uid, player_data)

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

const BASE_XP := 100
const XP_GROWTH := 1.25 # multiplicative growth per level
const COIN_CONVERSION_RATE := 50 # XP per 1 coin awarded at level-up

func get_xp_for_level(level: int) -> int:
	return int(round(BASE_XP * pow(XP_GROWTH, max(level - 1, 0))))

func get_xp_for_next_level() -> int:
	return get_xp_for_level(player_data["current_level"]) 

func add_xp(amount):
	player_data["current_xp"] += amount
	var _leveled: bool = false
	while player_data["current_xp"] >= get_xp_for_next_level():
		var threshold: int = get_xp_for_next_level()
		player_data["current_xp"] -= threshold
		player_data["current_level"] += 1
		# Convert part of the stage XP into coins at each level-up
		var coins_awarded: int = int(threshold / float(COIN_CONVERSION_RATE))
		if coins_awarded > 0:
			player_data["coins"] += coins_awarded
			emit_signal("coins_changed", player_data["coins"])
		_leveled = true
		emit_signal("level_up", player_data["current_level"])
	save_player_data()

func update_best_combo(new_combo):
	if new_combo > player_data["best_combo"]:
		player_data["best_combo"] = new_combo
		save_player_data()

func add_lines_cleared(lines):
	player_data["total_lines_cleared"] += lines
	save_player_data()

func get_coins():
	return player_data.get("coins", 0)

func can_spend(amount):
	return get_coins() >= amount

func spend_coins(amount):
	if not can_spend(amount):
		return false
	player_data["coins"] -= amount
	emit_signal("coins_changed", player_data["coins"])
	save_player_data()
	return true

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
	emit_signal("frame_changed", frame_name)
	save_player_data()

func unlock_frame(frame_name):
	if not player_data.has("unlocks"):
		player_data["unlocks"] = {"frames": [], "trophies": [], "aliases": []}
	if not player_data["unlocks"].has("frames"):
		player_data["unlocks"]["frames"] = []
	if not frame_name in player_data["unlocks"]["frames"]:
		player_data["unlocks"]["frames"].append(frame_name)
		save_player_data()

func get_current_frame():
	return player_data["current_frame"]

func get_current_xp():
	return player_data["current_xp"]

func get_current_level():
	return player_data["current_level"]
