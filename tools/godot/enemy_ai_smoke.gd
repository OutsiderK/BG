extends SceneTree

const MAIN_SCENE := "res://game/scenes/main/Main.tscn"
const MIN_EXPECTED_TRAVEL := 16.0

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

	var start_position := enemy.global_position
	for _frame in range(90):
		await physics_frame

	var travel := enemy.global_position.distance_to(start_position)
	if travel < MIN_EXPECTED_TRAVEL:
		printerr("Enemy did not move enough. Travel: %.2f" % travel)
		quit(1)
		return

	print("Enemy AI smoke passed. Travel: %.2f" % travel)
	quit(0)
