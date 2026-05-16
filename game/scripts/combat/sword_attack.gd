extends Node2D
class_name SwordAttack

signal attack_started
signal attack_finished
signal hit_enemy(enemy: EnemyBase, damage: int)
signal hit_pause_requested(duration: float)

@export var damage := 5
@export var attacks_per_second := 2.0
@export var active_time := 0.12
@export var reach := 38.0
@export var hitbox_size := Vector2(52.0, 34.0)
@export var knockback_force := 160.0
@export var hit_pause_seconds := 0.05

@onready var hitbox: Area2D = $Hitbox
@onready var collision_shape: CollisionShape2D = $Hitbox/CollisionShape2D

var attack_owner: Node = null
var active_remaining := 0.0
var cooldown_remaining := 0.0
var current_facing := Vector2.RIGHT
var hit_targets: Array[Node] = []

func _ready() -> void:
	attack_owner = get_parent()
	hitbox.monitoring = false
	hitbox.body_entered.connect(_on_body_entered)
	if collision_shape.shape is RectangleShape2D:
		collision_shape.shape.size = hitbox_size
	collision_shape.position = Vector2(reach, 0.0)
	collision_shape.disabled = true

func _physics_process(delta: float) -> void:
	cooldown_remaining = maxf(0.0, cooldown_remaining - delta)
	if active_remaining <= 0.0:
		return
	active_remaining = maxf(0.0, active_remaining - delta)
	_sample_overlaps()
	if active_remaining <= 0.0:
		_finish_attack()

func try_attack(facing: Vector2 = Vector2.RIGHT, source: Node = null) -> bool:
	if cooldown_remaining > 0.0 or active_remaining > 0.0:
		return false
	attack_owner = source if source != null else get_parent()
	current_facing = facing.normalized()
	if current_facing == Vector2.ZERO:
		current_facing = Vector2.RIGHT
	rotation = current_facing.angle()
	hit_targets.clear()
	active_remaining = active_time
	cooldown_remaining = 1.0 / maxf(attacks_per_second, 0.01)
	hitbox.monitoring = true
	collision_shape.disabled = false
	attack_started.emit()
	call_deferred("_sample_overlaps")
	return true

func is_attacking() -> bool:
	return active_remaining > 0.0

func get_cooldown_remaining() -> float:
	return cooldown_remaining

func _finish_attack() -> void:
	hitbox.monitoring = false
	collision_shape.disabled = true
	attack_finished.emit()

func _sample_overlaps() -> void:
	if active_remaining <= 0.0:
		return
	for body in hitbox.get_overlapping_bodies():
		_try_hit_body(body)

func _on_body_entered(body: Node) -> void:
	_try_hit_body(body)

func _try_hit_body(body: Node) -> void:
	if active_remaining <= 0.0:
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
	if body.has_method("apply_knockback"):
		body.apply_knockback(current_facing, knockback_force)
	hit_enemy.emit(body, damage)
	hit_pause_requested.emit(hit_pause_seconds)
