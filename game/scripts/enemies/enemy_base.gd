extends CharacterBody2D
class_name EnemyBase

signal died(enemy: EnemyBase)
signal damaged(enemy: EnemyBase, amount: int, current_hp: int, maximum_hp: int)
signal counter_unfold_requested(enemy: EnemyBase, target: Node)

@export var max_hp := 10
@export var contact_damage := 1
@export var move_speed := 80.0
@export var unfolded_move_speed := 110.0
@export var gravity := 1200.0
@export var detection_range := 560.0
@export var attack_range := 42.0
@export var attack_windup := 0.22
@export var attack_cooldown := 1.0
@export var acceleration := 900.0
@export var friction := 1200.0
@export_enum("normal", "elite", "boss") var enemy_rank := "normal"
@export var knockback_resistance := 0.0
@export var counter_unfold_enabled := false
@export var target_path: NodePath

var hp := 10
var unfolded_lane := 0
var is_dead := false
var knockback_velocity := Vector2.ZERO
var target: Node2D
var attack_cooldown_remaining := 0.0
var attack_windup_remaining := 0.0
var pending_attack_target: Node2D

func _ready() -> void:
	hp = max_hp
	add_to_group("enemies")
	UnfoldManager.register_enemy(self)
	tree_exiting.connect(_on_tree_exiting)

func _physics_process(delta: float) -> void:
	if is_dead:
		return
	_tick_timers(delta)
	var active_target := _resolve_target()
	if knockback_velocity.length_squared() > 1.0:
		_process_knockback(delta)
	elif active_target != null:
		_process_chase(delta, active_target)
	else:
		_process_idle(delta)
	move_and_slide()

func apply_damage(amount: int, _source: Node = null) -> bool:
	if is_dead or amount <= 0:
		return false
	hp = maxi(hp - amount, 0)
	RunState.add_heat(Balance.HEAT_HIT)
	damaged.emit(self, amount, hp, max_hp)
	if hp <= 0:
		_die()
	return true

func apply_knockback(direction: Vector2, force: float) -> void:
	if is_dead or force <= 0.0:
		return
	var push_direction := direction.normalized()
	if push_direction == Vector2.ZERO:
		return
	var resisted_force := force * clampf(1.0 - knockback_resistance, 0.0, 1.0)
	knockback_velocity = push_direction * resisted_force

func get_contact_damage() -> int:
	return contact_damage

func request_counter_unfold(target: Node) -> bool:
	if is_dead or not counter_unfold_enabled:
		return false
	counter_unfold_requested.emit(self, target)
	return true

func enter_unfolded(lane: int) -> void:
	unfolded_lane = lane

func exit_unfolded() -> void:
	pass

func _tick_timers(delta: float) -> void:
	attack_cooldown_remaining = maxf(0.0, attack_cooldown_remaining - delta)
	if attack_windup_remaining <= 0.0:
		return
	attack_windup_remaining = maxf(0.0, attack_windup_remaining - delta)
	if attack_windup_remaining <= 0.0:
		_commit_attack()

func _process_knockback(delta: float) -> void:
	if UnfoldManager.is_unfolded():
		motion_mode = MOTION_MODE_FLOATING
		velocity = knockback_velocity
	else:
		motion_mode = MOTION_MODE_GROUNDED
		velocity.x = knockback_velocity.x
		if not is_on_floor():
			velocity.y += gravity * delta
	knockback_velocity = knockback_velocity.move_toward(Vector2.ZERO, move_speed * 8.0 * delta)

func _process_chase(delta: float, active_target: Node2D) -> void:
	if attack_windup_remaining > 0.0:
		_process_attack_windup(delta)
		return
	if UnfoldManager.is_unfolded():
		_process_unfolded_chase(delta, active_target)
	else:
		_process_vertical_chase(delta, active_target)

func _process_vertical_chase(delta: float, active_target: Node2D) -> void:
	motion_mode = MOTION_MODE_GROUNDED
	var offset := active_target.global_position - global_position
	var distance_x := absf(offset.x)
	if offset.length() <= attack_range:
		_begin_attack(active_target)
		velocity.x = move_toward(velocity.x, 0.0, friction * delta)
	elif offset.length() <= detection_range:
		var direction := signf(offset.x)
		velocity.x = move_toward(velocity.x, direction * move_speed, acceleration * delta)
	elif distance_x > attack_range:
		velocity.x = move_toward(velocity.x, 0.0, friction * delta)
	if not is_on_floor():
		velocity.y += gravity * delta
	else:
		velocity.y = minf(velocity.y, 0.0)

func _process_unfolded_chase(delta: float, active_target: Node2D) -> void:
	motion_mode = MOTION_MODE_FLOATING
	var offset := active_target.global_position - global_position
	if offset.length() <= attack_range:
		_begin_attack(active_target)
		velocity = velocity.move_toward(Vector2.ZERO, friction * delta)
	elif offset.length() <= detection_range:
		velocity = velocity.move_toward(offset.normalized() * unfolded_move_speed, acceleration * delta)
	else:
		velocity = velocity.move_toward(Vector2.ZERO, friction * delta)

func _process_attack_windup(delta: float) -> void:
	if UnfoldManager.is_unfolded():
		motion_mode = MOTION_MODE_FLOATING
		velocity = velocity.move_toward(Vector2.ZERO, friction * delta)
	else:
		motion_mode = MOTION_MODE_GROUNDED
		velocity.x = move_toward(velocity.x, 0.0, friction * delta)
		if not is_on_floor():
			velocity.y += gravity * delta

func _process_idle(delta: float) -> void:
	if UnfoldManager.is_unfolded():
		motion_mode = MOTION_MODE_FLOATING
		velocity = velocity.move_toward(Vector2.ZERO, friction * delta)
	else:
		motion_mode = MOTION_MODE_GROUNDED
		velocity.x = move_toward(velocity.x, 0.0, friction * delta)
		if not is_on_floor():
			velocity.y += gravity * delta
		else:
			velocity.y = minf(velocity.y, 0.0)

func _begin_attack(active_target: Node2D) -> void:
	if attack_cooldown_remaining > 0.0:
		return
	pending_attack_target = active_target
	attack_windup_remaining = attack_windup
	attack_cooldown_remaining = attack_cooldown

func _commit_attack() -> void:
	if pending_attack_target == null or not is_instance_valid(pending_attack_target):
		pending_attack_target = null
		return
	if global_position.distance_to(pending_attack_target.global_position) <= attack_range * 1.25:
		if pending_attack_target.has_method("apply_damage"):
			pending_attack_target.call("apply_damage", contact_damage)
		elif pending_attack_target.has_method("take_damage"):
			pending_attack_target.call("take_damage", contact_damage)
	pending_attack_target = null

func _resolve_target() -> Node2D:
	if target != null and is_instance_valid(target) and not target.is_queued_for_deletion():
		return target
	if target_path != NodePath(""):
		target = get_node_or_null(target_path) as Node2D
		if target != null:
			return target
	var players := get_tree().get_nodes_in_group("player")
	if not players.is_empty():
		target = players[0] as Node2D
		if target != null:
			return target
	var current_scene := get_tree().current_scene
	if current_scene != null:
		target = current_scene.find_child("Player", true, false) as Node2D
	return target

func _on_tree_exiting() -> void:
	if is_instance_valid(UnfoldManager):
		UnfoldManager.unregister_enemy(self)

func _die() -> void:
	if is_dead:
		return
	is_dead = true
	match enemy_rank:
		"elite":
			RunState.add_heat(Balance.HEAT_KILL_ELITE)
		"boss":
			RunState.add_heat(Balance.HEAT_KILL_BOSS)
		_:
			RunState.add_heat(Balance.HEAT_KILL_NORMAL)
	died.emit(self)
	queue_free()
