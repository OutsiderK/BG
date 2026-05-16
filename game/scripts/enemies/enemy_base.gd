extends CharacterBody2D
class_name EnemyBase

signal died(enemy: EnemyBase)
signal damaged(enemy: EnemyBase, amount: int, current_hp: int, maximum_hp: int)
signal counter_unfold_requested(enemy: EnemyBase, target: Node)

@export var max_hp := 10
@export var contact_damage := 1
@export var move_speed := 80.0
@export_enum("normal", "elite", "boss") var enemy_rank := "normal"
@export var knockback_resistance := 0.0
@export var counter_unfold_enabled := false

var hp := 10
var unfolded_lane := 0
var is_dead := false
var knockback_velocity := Vector2.ZERO

func _ready() -> void:
	hp = max_hp
	add_to_group("enemies")

func _physics_process(delta: float) -> void:
	if knockback_velocity.length_squared() <= 1.0:
		knockback_velocity = Vector2.ZERO
		return
	velocity = knockback_velocity
	move_and_slide()
	knockback_velocity = knockback_velocity.move_toward(Vector2.ZERO, move_speed * 8.0 * delta)

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
