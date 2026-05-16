extends CharacterBody2D

signal damaged(amount: int)
signal died

@export var max_hp := 10
@export var vertical_speed := 220.0
@export var jump_velocity := -420.0
@export var gravity := 1200.0
@export var unfolded_speed := 260.0
@export var dash_speed := 620.0

var hp := 10
var facing := Vector2.RIGHT
var invulnerable_remaining := 0.0

func _ready() -> void:
	hp = max_hp

func _physics_process(delta: float) -> void:
	invulnerable_remaining = maxf(0.0, invulnerable_remaining - delta)
	if Input.is_action_just_pressed("unfold"):
		if UnfoldManager.is_unfolded():
			UnfoldManager.end_unfold("early")
		else:
			UnfoldManager.start_unfold()
	if UnfoldManager.is_unfolded():
		_process_unfolded(delta)
	else:
		_process_vertical(delta)
	move_and_slide()

func _process_vertical(delta: float) -> void:
	var direction := Input.get_axis("move_left", "move_right")
	velocity.x = direction * vertical_speed
	if direction != 0.0:
		facing = Vector2(signf(direction), 0.0)
	if not is_on_floor():
		velocity.y += gravity * delta
	if Input.is_action_just_pressed("move_up") and is_on_floor():
		velocity.y = jump_velocity

func _process_unfolded(_delta: float) -> void:
	var input_vector := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if input_vector.length() > 0.0:
		facing = input_vector.normalized()
	velocity = input_vector * unfolded_speed

func apply_damage(amount: int) -> void:
	if invulnerable_remaining > 0.0:
		return
	hp -= amount
	invulnerable_remaining = Balance.PLAYER_HIT_INVULN
	RunState.add_heat(Balance.HEAT_DAMAGED)
	damaged.emit(amount)
	if UnfoldManager.is_unfolded():
		UnfoldManager.end_unfold("collapse")
	if hp <= 0:
		died.emit()

