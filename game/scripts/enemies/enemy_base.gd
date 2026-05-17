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
@export var attack_active_time := 0.12
@export var attack_cooldown := 1.0
@export var attack_interrupt_cooldown := 0.45
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
var attack_active_remaining := 0.0
var attack_interrupt_flash_remaining := 0.0
var pending_attack_target: Node2D
var attack_direction := Vector2.RIGHT
var _last_visual_state: StringName = &""
@onready var body_visual: CanvasItem = get_node_or_null("ColorRect") as CanvasItem
@onready var visual_actor: Node = get_node_or_null("EnemyVisualActor")
@onready var attack_telegraph_visual: CanvasItem = get_node_or_null("AttackTelegraph") as CanvasItem
@onready var attack_window_visual: CanvasItem = get_node_or_null("AttackWindow") as CanvasItem
@onready var attack_cooldown_visual: CanvasItem = get_node_or_null("CooldownPip") as CanvasItem

func _ready() -> void:
	hp = max_hp
	add_to_group("enemies")
	UnfoldManager.register_enemy(self)
	tree_exiting.connect(_on_tree_exiting)
	_play_visual_state(&"idle")
	_update_attack_visuals()

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
	_update_attack_visuals()

func apply_damage(amount: int, _source: Node = null) -> bool:
	if is_dead or amount <= 0:
		return false
	hp = maxi(hp - amount, 0)
	RunState.add_heat(Balance.HEAT_HIT)
	damaged.emit(self, amount, hp, max_hp)
	if visual_actor != null and visual_actor.has_method("flash_hurt"):
		visual_actor.call("flash_hurt")
		_last_visual_state = &"hurt"
	if attack_windup_remaining > 0.0:
		_interrupt_attack_windup()
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
	attack_active_remaining = maxf(0.0, attack_active_remaining - delta)
	attack_interrupt_flash_remaining = maxf(0.0, attack_interrupt_flash_remaining - delta)
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
	if attack_windup_remaining > 0.0 or attack_active_remaining > 0.0:
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
	if attack_cooldown_remaining > 0.0 or attack_windup_remaining > 0.0 or attack_active_remaining > 0.0:
		return
	pending_attack_target = active_target
	_set_attack_direction(active_target.global_position - global_position)
	if attack_windup <= 0.0:
		_commit_attack()
		return
	attack_windup_remaining = attack_windup
	_update_attack_visuals()

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
	attack_active_remaining = attack_active_time
	attack_cooldown_remaining = attack_cooldown
	_update_attack_visuals()

func _interrupt_attack_windup() -> void:
	pending_attack_target = null
	attack_windup_remaining = 0.0
	attack_interrupt_flash_remaining = 0.18
	attack_cooldown_remaining = maxf(attack_cooldown_remaining, attack_interrupt_cooldown)
	_update_attack_visuals()

func _set_attack_direction(offset: Vector2) -> void:
	if offset.length_squared() > 0.01:
		attack_direction = offset.normalized()
	elif attack_direction == Vector2.ZERO:
		attack_direction = Vector2.RIGHT

func _update_attack_visuals() -> void:
	var is_winding_up := attack_windup_remaining > 0.0
	var is_active := attack_active_remaining > 0.0
	var is_cooling_down := attack_cooldown_remaining > 0.0 and not is_winding_up and not is_active
	_set_visual_visible(attack_telegraph_visual, is_winding_up)
	_set_visual_visible(attack_window_visual, is_active)
	_set_visual_visible(attack_cooldown_visual, is_cooling_down)

	if attack_telegraph_visual != null:
		var windup_progress := 1.0 - (attack_windup_remaining / maxf(attack_windup, 0.001))
		_place_directional_visual(attack_telegraph_visual, clampf(windup_progress, 0.0, 1.0))
	if attack_window_visual != null:
		_place_directional_visual(attack_window_visual, 1.0)
	if attack_cooldown_visual != null:
		var cooldown_progress := attack_cooldown_remaining / maxf(attack_cooldown, 0.001)
		_set_visual_scale(attack_cooldown_visual, Vector2(maxf(cooldown_progress, 0.08), 1.0))

	_update_visual_actor(is_winding_up, is_active)

	if body_visual == null:
		return
	if attack_interrupt_flash_remaining > 0.0:
		body_visual.modulate = Color(1.0, 1.0, 1.0, 1.0)
	elif is_active:
		body_visual.modulate = Color(1.3, 0.35, 0.25, 1.0)
	elif is_winding_up:
		body_visual.modulate = Color(1.2, 0.95, 0.35, 1.0)
	elif is_cooling_down:
		body_visual.modulate = Color(0.7, 0.9, 1.0, 1.0)
	else:
		body_visual.modulate = Color.WHITE

func _update_visual_actor(is_winding_up: bool, is_active: bool) -> void:
	if visual_actor == null:
		return
	_update_visual_facing()
	if is_dead:
		_play_visual_state(&"death")
	elif attack_interrupt_flash_remaining > 0.0:
		_play_visual_state(&"hurt")
	elif is_active:
		_play_visual_state(&"attack")
	elif is_winding_up:
		_play_visual_state(&"telegraph")
	elif velocity.length_squared() > 64.0:
		_play_visual_state(&"move")
	else:
		_play_visual_state(&"idle")

func _update_visual_facing() -> void:
	if visual_actor == null or not visual_actor.has_method("set_facing_direction"):
		return
	var facing_direction := attack_direction
	if attack_windup_remaining <= 0.0 and attack_active_remaining <= 0.0:
		if absf(velocity.x) > 1.0:
			facing_direction = Vector2(signf(velocity.x), 0.0)
		elif target != null and is_instance_valid(target):
			facing_direction = target.global_position - global_position
	visual_actor.call("set_facing_direction", facing_direction)

func _play_visual_state(state_name: StringName) -> void:
	if visual_actor == null or not visual_actor.has_method("play_state"):
		return
	if _last_visual_state == state_name:
		return
	_last_visual_state = state_name
	visual_actor.call("play_state", state_name)

func _set_visual_visible(visual: CanvasItem, is_visible: bool) -> void:
	if visual != null:
		visual.visible = is_visible

func _place_directional_visual(visual: CanvasItem, progress: float) -> void:
	var direction := attack_direction
	if direction == Vector2.ZERO:
		direction = Vector2.RIGHT
	var scale := Vector2(0.35 + 0.65 * progress, 1.0)
	if visual is Node2D:
		var node := visual as Node2D
		node.rotation = direction.angle()
		node.scale = scale
	elif visual is Control:
		var control := visual as Control
		control.rotation = direction.angle()
		control.scale = scale

func _set_visual_scale(visual: CanvasItem, scale: Vector2) -> void:
	if visual is Node2D:
		(visual as Node2D).scale = scale
	elif visual is Control:
		(visual as Control).scale = scale

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
	_play_visual_state(&"death")
	queue_free()
