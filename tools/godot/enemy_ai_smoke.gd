extends SceneTree

const MAIN_SCENE := "res://game/scenes/main/Main.tscn"
const MIN_EXPECTED_TRAVEL := 16.0
const MAX_EXPECTED_DISTANCE_TO_PLAYER := 90.0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var packed := load(MAIN_SCENE) as PackedScene
	if packed == null:
		printerr("Failed to load main scene: %s" % MAIN_SCENE)
		quit(1)
		return

	var main := packed.instantiate()
	root.add_child(main)
	await physics_frame

	var enemy := main.get_node_or_null("DemoRoom/Enemies/DummyEnemyA") as Node2D
	if enemy == null:
		printerr("Failed to find DummyEnemyA in main scene.")
		quit(1)
		return
	var player := main.get_node_or_null("Player") as Node2D
	if player == null:
		printerr("Failed to find Player in main scene.")
		quit(1)
		return

	var start_position := enemy.global_position
	var closest_distance := enemy.global_position.distance_to(player.global_position)
	for _frame in range(300):
		await physics_frame
		if is_instance_valid(enemy) and is_instance_valid(player):
			closest_distance = minf(closest_distance, enemy.global_position.distance_to(player.global_position))

	var travel := enemy.global_position.distance_to(start_position)
	if travel < MIN_EXPECTED_TRAVEL:
		printerr("Enemy did not move enough. Travel: %.2f" % travel)
		quit(1)
		return
	if closest_distance > MAX_EXPECTED_DISTANCE_TO_PLAYER:
		printerr("Enemy could not reach the player. Closest distance: %.2f" % closest_distance)
		quit(1)
		return

	print("Enemy AI smoke passed. Travel: %.2f, closest distance: %.2f" % [travel, closest_distance])
	quit(0)
