extends Node

@onready var trophy_notification = $CanvasLayer/TrophyNotification

func _ready():
    PlayerManager.trophy_unlocked.connect(_on_trophy_unlocked)

func _on_trophy_unlocked(trophy_resource):
    trophy_notification.show_notification(trophy_resource)

