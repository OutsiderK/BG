extends SceneTree

const ENEMY_SCENE := "res://game/scenes/enemies/DummyEnemy.tscn"

class ProbeTarget:
	extends CharacterBody2D

	var damage_taken := 0

	func apply_damage(amount: int) -> void:
		damage_taken += amount

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

	enemy.global_position = Vector2.ZERO
	target.global_position = Vector2(36.0, 0.0)
	enemy.target = target
	enemy.gravity = 0.0
	enemy.attack_range = 72.0
	enemy.attack_windup = 0.25
	enemy.attack_active_time = 0.2
	enemy.attack_cooldown = 0.35
	enemy.attack_interrupt_cooldown = 0.25

	for _frame in range(5):
		await physics_frame
		if enemy.attack_windup_remaining > 0.0:
			break

	var telegraph := enemy.get_node_or_null("AttackTelegraph") as CanvasItem
	if enemy.attack_windup_remaining <= 0.0:
		_fail("Enemy did not enter attack windup.")
		return
	if telegraph == null or not telegraph.visible:
		_fail("Attack telegraph was not visible during windup.")
		return
	if target.damage_taken != 0:
		_fail("Enemy dealt damage before windup completed.")
		return

	enemy.apply_damage(1, target)
	var cooldown := enemy.get_node_or_null("CooldownPip") as CanvasItem
	if enemy.attack_windup_remaining > 0.0:
		_fail("Enemy windup was not interrupted by damage.")
		return
	if enemy.pending_attack_target != null:
		_fail("Interrupted attack kept a pending target.")
		return
	if enemy.attack_cooldown_remaining <= 0.0:
		_fail("Interrupted attack did not enter cooldown.")
		return
	if cooldown == null or not cooldown.visible:
		_fail("Cooldown indicator was not visible after interrupt.")
		return

	var attack_window := enemy.get_node_or_null("AttackWindow") as CanvasItem
	for _frame in range(90):
		await physics_frame
		if target.damage_taken > 0:
			if attack_window == null or not attack_window.visible:
				_fail("Attack window was not visible when damage landed.")
				return
			print("Enemy attack smoke passed.")
			quit(0)
			return

	_fail("Enemy did not attack after interrupt cooldown expired.")

func _fail(message: String) -> void:
	printerr(message)
	quit(1)
