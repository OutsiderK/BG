extends Node2D

const DEMO_ROOM_BOUNDS := Rect2(Vector2.ZERO, Vector2(1280, 720))

@onready var player: Node = %Player
@onready var follow_camera: Node = %FollowCamera

func _ready() -> void:
	follow_camera.call("set_follow_target", player as Node2D)
	follow_camera.call("set_room_bounds", DEMO_ROOM_BOUNDS)
	if player.has_signal("died"):
		player.died.connect(_on_player_died)

func shake_camera(strength := -1.0, duration := -1.0) -> void:
	follow_camera.call("shake", strength, duration)

func _on_player_died() -> void:
	var permadeath := RunState.roll_permadeath()
	print("Player died. Permadeath: %s" % permadeath)
