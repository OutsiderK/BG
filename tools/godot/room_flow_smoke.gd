extends SceneTree

const MAIN_SCENE := "res://game/scenes/main/Main.tscn"

var _failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var run_state := root.get_node_or_null("RunState")
	var unfold_manager := root.get_node_or_null("UnfoldManager")
	if run_state == null or unfold_manager == null:
		_fail("Failed to find required autoloads.")
		_finish()
		return

	run_state.reset_run()
	unfold_manager.set_gameplay_blocked(false)
	unfold_manager.set_unfold_blocked(false)

	var packed := load(MAIN_SCENE) as PackedScene
	if packed == null:
		_fail("Failed to load main scene: %s" % MAIN_SCENE)
		_finish()
		return

	var main := packed.instantiate()
	root.add_child(main)
	await process_frame
	await physics_frame

	var room := main.get_node_or_null("DemoRoom")
	var player := main.get_node_or_null("Player") as Node2D
	var enemies := main.get_node_or_null("DemoRoom/Enemies")
	var prompt := main.get_node_or_null("DemoRoom/ExitPlaceholders/GroundDoorPlaceholder/ExtractPrompt") as Label
	if room == null or player == null or enemies == null or prompt == null:
		_fail("Failed to find room flow nodes.")
		_cleanup(main)
		_finish()
		return

	_assert(not run_state.current_room_cleared, "Room starts locked/uncleared.")
	_assert(not prompt.visible, "Extraction prompt is hidden before clear.")

	for enemy in enemies.get_children().duplicate():
		if enemy != null and enemy.has_method("apply_damage"):
			enemy.call("apply_damage", 999, player)
	await process_frame
	await physics_frame

	_assert(run_state.current_room_cleared, "Room is marked cleared after all enemies die.")
	_assert(int(run_state.current_room_kills) >= 2, "Room kill count is recorded.")
	_assert(prompt.visible, "Extraction prompt becomes visible after clear.")

	player.global_position = Vector2(1180.0, 480.0)
	var extracted := bool(room.call("try_extract_for_player", player))
	await process_frame
	_assert(extracted, "Player can extract at the opened rift.")
	_assert(not run_state.last_extraction_result.is_empty(), "Extraction result is recorded.")
	_assert(int(run_state.last_extraction_result.get("kills", 0)) >= 2, "Extraction result includes kills.")

	_cleanup(main)
	unfold_manager.set_gameplay_blocked(false)
	_finish()

func _cleanup(main: Node) -> void:
	if main != null:
		root.remove_child(main)
		main.queue_free()

func _assert(condition: bool, message: String) -> void:
	if not condition:
		_fail(message)

func _fail(message: String) -> void:
	_failures.append(message)
	printerr(message)

func _finish() -> void:
	if not _failures.is_empty():
		printerr("Room flow smoke failed with %d failure(s)." % _failures.size())
		quit(1)
		return
	print("Room flow smoke passed.")
	quit(0)
