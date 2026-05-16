extends Node2D
class_name SwordAttack

signal attack_started
signal attack_finished
signal hit_enemy(enemy: Node, damage: int)
signal hit_pause_requested(duration: float)

@export var damage := 5
@export var attacks_per_second := 2.0
@export var active_time := 0.12
@export var reach := 38.0
@export var hitbox_size := Vector2(52.0, 34.0)
@export var knockback_force := 160.0
@export var hit_pause_seconds := 0.05
@export_range(0.01, 1.0) var hit_pause_time_scale := 0.08
@export var hit_feedback_scene: PackedScene
@export var event_driven_hitbox := false

@onready var hitbox: Area2D = $Hitbox
@onready var collision_shape: CollisionShape2D = $Hitbox/CollisionShape2D

var attack_owner: Node = null
var attack_in_progress := false
var active_remaining := 0.0
var hitbox_active := false
var cooldown_remaining := 0.0
var current_facing := Vector2.RIGHT
var hit_targets: Array[Node] = []
var hit_pause_active := false
var hit_pause_restore_scale := 1.0
var hit_pause_applied_scale := 1.0

func _ready() -> void:
	attack_owner = get_parent()
	hitbox.monitoring = false
	hitbox.body_entered.connect(_on_body_entered)
	if collision_shape.shape is RectangleShape2D:
		collision_shape.shape.size = hitbox_size
	collision_shape.position = Vector2(reach, 0.0)
	collision_shape.disabled = true

func _exit_tree() -> void:
	_finish_hit_pause()

func _physics_process(delta: float) -> void:
	cooldown_remaining = maxf(0.0, cooldown_remaining - delta)
	if event_driven_hitbox:
		if hitbox_active:
			_sample_overlaps()
		return
	if active_remaining <= 0.0:
		return
	active_remaining = maxf(0.0, active_remaining - delta)
	_sample_overlaps()
	if active_remaining <= 0.0:
		_finish_attack()

func try_attack(facing: Vector2 = Vector2.RIGHT, source: Node = null) -> bool:
	if cooldown_remaining > 0.0 or attack_in_progress or active_remaining > 0.0:
		return false
	attack_owner = source if source != null else get_parent()
	current_facing = facing.normalized()
	if current_facing == Vector2.ZERO:
		current_facing = Vector2.RIGHT
	rotation = current_facing.angle()
	hit_targets.clear()
	attack_in_progress = true
	cooldown_remaining = 1.0 / maxf(attacks_per_second, 0.01)
	if event_driven_hitbox:
		active_remaining = 0.0
		_set_hitbox_active(false)
	else:
		active_remaining = active_time
		_set_hitbox_active(true)
	attack_started.emit()
	if not event_driven_hitbox:
		call_deferred("_sample_overlaps")
	return true

func is_attacking() -> bool:
	return attack_in_progress or active_remaining > 0.0

func get_cooldown_remaining() -> float:
	return cooldown_remaining

func set_event_driven_hitbox(enabled: bool) -> void:
	event_driven_hitbox = enabled
	if enabled and not hitbox_active:
		active_remaining = 0.0
		_set_hitbox_active(false)

func begin_active_window(_payload: Dictionary = {}) -> void:
	if not attack_in_progress:
		return
	_set_hitbox_active(true)
	call_deferred("_sample_overlaps")

func end_active_window(_payload: Dictionary = {}) -> void:
	_set_hitbox_active(false)

func _finish_attack() -> void:
	attack_in_progress = false
	active_remaining = 0.0
	_set_hitbox_active(false)
	attack_finished.emit()

func finish_attack(_animation_name: StringName = &"") -> void:
	if not attack_in_progress and active_remaining <= 0.0 and not hitbox_active:
		return
	_finish_attack()

func _set_hitbox_active(enabled: bool) -> void:
	hitbox_active = enabled
	hitbox.monitoring = enabled
	collision_shape.disabled = not enabled

func _sample_overlaps() -> void:
	if not hitbox_active:
		return
	for body in hitbox.get_overlapping_bodies():
		_try_hit_body(body)

func _on_body_entered(body: Node) -> void:
	_try_hit_body(body)

func _try_hit_body(body: Node) -> void:
	if not hitbox_active:
		return
	if body == null or body == attack_owner or hit_targets.has(body):
		return
	if not body.is_in_group("enemies"):
		return
	if not body.has_method("apply_damage"):
		return
	hit_targets.append(body)
	var did_damage: bool = body.apply_damage(damage, attack_owner)
	if not did_damage:
		return
	var knockback_direction := _get_knockback_direction(body)
	if body.has_method("apply_knockback"):
		body.apply_knockback(knockback_direction, knockback_force)
	_spawn_hit_feedback(body, damage, knockback_direction)
	hit_enemy.emit(body, damage)
	_request_hit_pause()

func _get_knockback_direction(body: Node) -> Vector2:
	if current_facing.length_squared() > 0.001:
		return current_facing.normalized()
	if attack_owner is Node2D and body is Node2D:
		var owner_node := attack_owner as Node2D
		var body_node := body as Node2D
		var offset := body_node.global_position - owner_node.global_position
		if offset.length_squared() > 0.001:
			return offset.normalized()
	return Vector2.RIGHT

func _spawn_hit_feedback(body: Node, amount: int, knockback_direction: Vector2) -> void:
	if hit_feedback_scene == null or not (body is Node2D):
		return
	var tree := get_tree()
	if tree == null:
		return
	var feedback_parent := tree.current_scene
	if feedback_parent == null:
		feedback_parent = body.get_parent()
	if feedback_parent == null:
		return
	var body_node := body as Node2D
	var impact_position := body_node.global_position + Vector2(0.0, -24.0) + knockback_direction * 8.0
	var feedback := hit_feedback_scene.instantiate()
	feedback_parent.add_child(feedback)
	if feedback is Node2D:
		(feedback as Node2D).global_position = impact_position
	if feedback.has_method("setup"):
		feedback.call("setup", amount, impact_position, knockback_direction)

func _request_hit_pause() -> void:
	hit_pause_requested.emit(hit_pause_seconds)
	if hit_pause_seconds <= 0.0 or hit_pause_active:
		return
	var tree := get_tree()
	if tree == null:
		return
	hit_pause_active = true
	hit_pause_restore_scale = Engine.time_scale
	hit_pause_applied_scale = minf(hit_pause_restore_scale, hit_pause_time_scale)
	Engine.time_scale = hit_pause_applied_scale
	var timer := tree.create_timer(hit_pause_seconds, true, false, true)
	timer.timeout.connect(_finish_hit_pause)

func _finish_hit_pause() -> void:
	if not hit_pause_active:
		return
	if is_equal_approx(Engine.time_scale, hit_pause_applied_scale):
		Engine.time_scale = hit_pause_restore_scale
	hit_pause_active = false
