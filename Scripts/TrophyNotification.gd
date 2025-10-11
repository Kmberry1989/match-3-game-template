extends PanelContainer

@onready var icon = $HBoxContainer/Icon
@onready var trophy_name = $HBoxContainer/VBoxContainer/TrophyName

func _ready():
	hide()

func show_notification(trophy_resource):
	icon.texture = trophy_resource.unlocked_icon
	trophy_name.text = trophy_resource.trophy_name

	show()
	var tween = create_tween()
	tween.set_parallel(false)
	tween.tween_property(self, "position:x", 0, 0.5).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	tween.tween_interval(3.0)
	tween.tween_property(self, "position:x", 250, 0.5).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_IN)
	tween.tween_callback(hide)
