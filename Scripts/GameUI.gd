extends Control

@onready var score_label = $MarginContainer/HBoxContainer/PlayerInfo/HBox/AvatarFrame/VBox/ScoreContainer/PlayerScoreLabel
@onready var opponent_score_label = $MarginContainer/HBoxContainer/OpponentInfo/HBox/VBox/ScoreContainer/OpponentScoreLabel
@onready var player_name_label = $MarginContainer/HBoxContainer/PlayerInfo/HBox/AvatarFrame/VBox/PlayerNameLabel
@onready var opponent_name_label = $MarginContainer/HBoxContainer/OpponentInfo/HBox/VBox/OpponentNameLabel

func _ready():
	set_player_name(PlayerManager.get_player_name())
	# Opponent name can be set when a match is found
	set_opponent_name("Opponent")

func set_score(score):
	score_label.text = "Score: " + str(score)

func set_opponent_score(score):
	opponent_score_label.text = "Score: " + str(score)

func set_player_name(p_name):
	player_name_label.text = p_name

func set_opponent_name(p_name):
	opponent_name_label.text = p_name
