extends SceneTree

const PLAYER_SCENE := "res://game/scenes/player/Player.tscn"

class ProbeEnemy:
	extends CharacterBody2D

	var damage_taken := 0

	func _init() -> void:
		add_to_group("enemies")
		var shape := CollisionShape2D.new()
		var rectangle := RectangleShape2D.new()
		rectangle.size = Vector2(18.0, 34.0)
		shape.shape = rectangle
		add_child(shape)

	func apply_damage(amount: int, _source: Node = null) -> bool:
		damage_taken += amount
		return true

	func apply_knockback(_direction: Vector2, _force: float) -> void:
		pass

var _failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var run_state := root.get_node_or_null("RunState")
	var unfold_manager := root.get_node_or_null("UnfoldManager")
	if run_state != null:
		run_state.reset_run()
	if unfold_manager != null:
		unfold_manager.set_gameplay_blocked(false)

	var packed := load(PLAYER_SCENE) as PackedScene
	if packed == null:
		_fail("Failed to load player scene: %s" % PLAYER_SCENE)
		_finish()
		return

	var player := packed.instantiate()
	var enemy := ProbeEnemy.new()
	root.add_child(player)
	root.add_child(enemy)
	player.global_position = Vector2.ZERO
	enemy.global_position = Vector2(38.0, 0.0)
	await physics_frame

	var actor := player.get_node_or_null("AnimatedActor")
	var sword := player.get_node_or_null("SwordAttack")
	_assert(actor != null, "Player has AnimatedActor.")
	_assert(sword != null, "Player has SwordAttack.")
	_assert(sword.event_driven_hitbox, "SwordAttack is switched to event-driven hitbox.")

	player.facing = Vector2.RIGHT
	player.call("_try_attack")
	await physics_frame
	_assert(sword.is_attacking(), "Sword attack is pending after input.")
	_assert(enemy.damage_taken == 0, "Sword does not damage before animation hit_start.")

	actor.sprite.frame = 2
	await physics_frame
	_assert(enemy.damage_taken == sword.damage, "Sword damages when animation reaches hit_start frame.")

	actor.sprite.frame = 4
	await physics_frame
	_assert(not sword.hitbox_active, "Sword hitbox closes on hit_end frame.")

	actor.sprite.frame = 5
	actor.sprite.animation_finished.emit()
	await physics_frame
	_assert(not sword.is_attacking(), "Sword attack finishes when animation finishes.")

	root.remove_child(player)
	root.remove_child(enemy)
	player.queue_free()
	enemy.queue_free()
	await process_frame
	if unfold_manager != null:
		unfold_manager.set_gameplay_blocked(false)
	_finish()

func _assert(condition: bool, message: String) -> void:
	if not condition:
		_fail(message)

func _fail(message: String) -> void:
	_failures.append(message)
	printerr(message)

func _finish() -> void:
	if not _failures.is_empty():
		printerr("Sword event smoke failed with %d failure(s)." % _failures.size())
		quit(1)
		return
	print("Sword event smoke passed.")
	quit(0)
