extends SceneTree

const ENEMY_SCENE := "res://game/scenes/enemies/DummyEnemy.tscn"
const STATES := [
	&"idle",
	&"move",
	&"telegraph",
	&"attack",
	&"hurt",
	&"death",
]

class ProbeTarget:
	extends CharacterBody2D

	func apply_damage(_amount: int) -> void:
		pass

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var packed := load(ENEMY_SCENE) as PackedScene
	if packed == null:
		_fail("Failed to load enemy scene: %s" % ENEMY_SCENE)
		return

	var enemy := packed.instantiate()
	var target := ProbeTarget.new()
	root.add_child(enemy)
	root.add_child(target)
	enemy.set_physics_process(false)
	await process_frame

	var visual := enemy.get_node_or_null("EnemyVisualActor")
	var visual_item := visual as CanvasItem
	if visual == null:
		_fail("EnemyVisualActor is missing.")
		return
	if visual is CollisionObject2D:
		_fail("Enemy visual actor must not participate in collision.")
		return
	if not visual.has_method("play_state") or not visual.has_method("flash_hurt"):
		_fail("Enemy visual actor is missing stable visual methods.")
		return
	if visual_item == null:
		_fail("Enemy visual actor must be a CanvasItem.")
		return

	for state in STATES:
		visual.call("play_state", state)
		await process_frame
		var observed := StringName(str(visual.get("current_state")))
		if observed != state:
			_fail("Enemy visual actor did not accept state: %s, observed: %s" % [state, observed])
			return

	var fallback := enemy.get_node_or_null("ColorRect") as CanvasItem
	if fallback == null:
		_fail("Enemy body fallback ColorRect is missing.")
		return
	if fallback.visible:
		_fail("Enemy body fallback should remain hidden while the actor is present.")
		return

	enemy.global_position = Vector2.ZERO
	target.global_position = Vector2(36.0, 0.0)
	enemy.target = target
	enemy.gravity = 0.0
	enemy.attack_range = 72.0
	enemy.attack_windup = 0.25
	enemy.set_physics_process(true)

	for _frame in range(8):
		await physics_frame
		if enemy.attack_windup_remaining > 0.0:
			break

	var telegraph := enemy.get_node_or_null("AttackTelegraph") as CanvasItem
	if telegraph == null or not telegraph.visible:
		_fail("Enemy attack telegraph is not visible during windup.")
		return
	if telegraph.z_index <= visual_item.z_index:
		_fail("Enemy attack telegraph should render above the body visual.")
		return
	if StringName(str(visual.get("current_state"))) != &"telegraph":
		_fail("Enemy visual actor did not enter telegraph state during windup.")
		return

	print("Enemy visual smoke passed.")
	quit(0)

func _fail(message: String) -> void:
	printerr(message)
	quit(1)
