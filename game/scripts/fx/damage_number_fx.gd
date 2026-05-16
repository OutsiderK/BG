extends Node2D
class_name DamageNumberFx

@export var lifetime := 0.45
@export var rise_distance := 34.0
@export var side_drift := 16.0
@export var pop_scale := 1.25

@onready var number_label: Label = $NumberLabel
@onready var slash: Line2D = $Slash

var age := 0.0
var start_position := Vector2.ZERO
var drift := Vector2.ZERO
var base_scale := Vector2.ONE

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	z_index = 80
	start_position = global_position
	base_scale = scale

func setup(amount: int, world_position: Vector2, impact_direction: Vector2 = Vector2.RIGHT) -> void:
	var direction := impact_direction.normalized()
	if direction == Vector2.ZERO:
		direction = Vector2.RIGHT
	global_position = world_position
	start_position = world_position
	drift = Vector2(direction.x * side_drift, -rise_distance)
	number_label.text = str(amount)
	slash.rotation = direction.angle()

func _process(delta: float) -> void:
	age += delta
	var progress := clampf(age / maxf(lifetime, 0.01), 0.0, 1.0)
	var pop_progress := clampf(progress * 5.0, 0.0, 1.0)
	global_position = start_position + drift * progress
	scale = base_scale * lerpf(pop_scale, 1.0, pop_progress)
	modulate.a = 1.0 - smoothstep(0.55, 1.0, progress)
	if progress >= 1.0:
		queue_free()
