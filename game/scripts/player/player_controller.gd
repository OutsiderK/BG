extends CharacterBody2D

signal damaged(amount: int)
signal died

@export var max_hp := 10
@export var vertical_speed := 220.0
@export var jump_velocity := -420.0
@export var gravity := 1200.0
@export var unfolded_speed := 260.0
@export var dash_speed := 620.0
@export var dash_duration := 0.12
@export var dash_cooldown := 0.8
@export var max_dash_charges := 2

var hp := 10
var facing := Vector2.RIGHT
var hit_invulnerable_remaining := 0.0
var dash_invulnerable_remaining := 0.0
var dash_remaining := 0.0
var dash_cooldown_remaining := 0.0
var dash_charges := 2
var dash_direction := Vector2.RIGHT
var dead := false
@onready var sword_attack: Node = get_node_or_null("SwordAttack")

func _ready() -> void:
	add_to_group("player")
	UnfoldManager.set_player(self)
	hp = max_hp
	dash_charges = max_dash_charges
	RunState.set_health(hp, max_hp)
	UnfoldManager.unfold_started.connect(_on_unfold_started)
	UnfoldManager.unfold_ended.connect(_on_unfold_ended)

func _physics_process(delta: float) -> void:
	_tick_timers(delta)
	if Input.is_action_just_pressed("unfold"):
		if UnfoldManager.is_unfolded():
			UnfoldManager.end_unfold("early")
		else:
			UnfoldManager.start_unfold()
	if Input.is_action_just_pressed("dash"):
		_try_start_dash()
	if Input.is_action_just_pressed("attack"):
		_try_attack()
	if UnfoldManager.is_unfolded():
		_process_unfolded(delta)
	else:
		_process_vertical(delta)
	_process_dash()
	move_and_slide()

func _process_vertical(delta: float) -> void:
	motion_mode = MOTION_MODE_GROUNDED
	var direction := Input.get_axis("move_left", "move_right")
	velocity.x = direction * vertical_speed
	if direction != 0.0:
		facing = Vector2(signf(direction), 0.0)
	if not is_on_floor():
		velocity.y += gravity * delta
	if Input.is_action_just_pressed("move_up") and is_on_floor():
		velocity.y = jump_velocity

func _process_unfolded(_delta: float) -> void:
	motion_mode = MOTION_MODE_FLOATING
	var input_vector := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if input_vector.length() > 0.0:
		facing = input_vector.normalized()
	velocity = input_vector * unfolded_speed

func _process_dash() -> void:
	if dash_remaining <= 0.0:
		return
	velocity = dash_direction * dash_speed

func _tick_timers(delta: float) -> void:
	hit_invulnerable_remaining = maxf(0.0, hit_invulnerable_remaining - delta)
	dash_invulnerable_remaining = maxf(0.0, dash_invulnerable_remaining - delta)
	dash_remaining = maxf(0.0, dash_remaining - delta)
	if dash_cooldown_remaining > 0.0:
		dash_cooldown_remaining = maxf(0.0, dash_cooldown_remaining - delta)
		if dash_cooldown_remaining <= 0.0:
			dash_charges = max_dash_charges

func _try_start_dash() -> void:
	if dash_remaining > 0.0 or dash_charges <= 0:
		return
	dash_direction = _get_dash_direction()
	dash_remaining = dash_duration
	dash_invulnerable_remaining = Balance.PLAYER_DASH_INVULN
	dash_charges -= 1
	if dash_charges <= 0:
		dash_cooldown_remaining = dash_cooldown

func _try_attack() -> void:
	if sword_attack == null or not sword_attack.has_method("try_attack"):
		return
	sword_attack.call("try_attack", facing, self)

func _get_dash_direction() -> Vector2:
	if UnfoldManager.is_unfolded():
		var input_vector := Input.get_vector("move_left", "move_right", "move_up", "move_down")
		if input_vector.length() > 0.0:
			return input_vector.normalized()
		return facing.normalized()
	var direction := Input.get_axis("move_left", "move_right")
	if direction != 0.0:
		return Vector2(signf(direction), 0.0)
	if facing.x != 0.0:
		return Vector2(signf(facing.x), 0.0)
	return Vector2.RIGHT

func is_invulnerable() -> bool:
	return hit_invulnerable_remaining > 0.0 or dash_invulnerable_remaining > 0.0

func _on_unfold_started() -> void:
	motion_mode = MOTION_MODE_FLOATING
	velocity = Vector2.ZERO

func _on_unfold_ended(_reason: String) -> void:
	motion_mode = MOTION_MODE_GROUNDED
	velocity = Vector2.ZERO

func apply_damage(amount: int) -> void:
	if dead or amount <= 0 or is_invulnerable():
		return
	hp = maxi(0, hp - amount)
	RunState.set_health(hp, max_hp)
	hit_invulnerable_remaining = Balance.PLAYER_HIT_INVULN
	RunState.add_heat(Balance.HEAT_DAMAGED)
	damaged.emit(amount)
	if UnfoldManager.is_unfolded():
		UnfoldManager.end_unfold("collapse")
	if hp <= 0:
		dead = true
		died.emit()

func take_damage(amount: int) -> void:
	apply_damage(amount)
