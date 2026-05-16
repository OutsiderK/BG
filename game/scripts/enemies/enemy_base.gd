extends CharacterBody2D

signal died(enemy: EnemyBase)

@export var max_hp := 10
@export var contact_damage := 1
@export var move_speed := 80.0

var hp := 10
var unfolded_lane := 0

func _ready() -> void:
	hp = max_hp

func apply_damage(amount: int) -> void:
	hp -= amount
	RunState.add_heat(Balance.HEAT_HIT)
	if hp <= 0:
		RunState.add_heat(Balance.HEAT_KILL_NORMAL)
		died.emit(self)
		queue_free()

func enter_unfolded(lane: int) -> void:
	unfolded_lane = lane

func exit_unfolded() -> void:
	pass

