extends Node

@onready var trophy_notification = $CanvasLayer/TrophyNotification

func _ready():
	print("[Game.gd] _ready: Starting.")
	PlayerManager.trophy_unlocked.connect(_on_trophy_unlocked)
	# Autoload singletons are available as globals; no Engine.has_singleton check needed
	if AudioManager != null:
		print("[Game.gd] _ready: Playing in-game music.")
		AudioManager.play_music("ingame")
	print("[Game.gd] _ready: Finished.")

func _on_trophy_unlocked(trophy_resource):
	print("[Game.gd] _on_trophy_unlocked: A trophy was unlocked.")
	trophy_notification.show_notification(trophy_resource)