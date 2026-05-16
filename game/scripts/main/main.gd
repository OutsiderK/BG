extends Node2D

@onready var player: Node = %Player

func _ready() -> void:
	if player.has_signal("died"):
		player.died.connect(_on_player_died)

func _on_player_died() -> void:
	var permadeath := RunState.roll_permadeath()
	print("Player died. Permadeath: %s" % permadeath)

