extends SceneTree

const MAIN_SCENE := "res://game/scenes/main/Main.tscn"

var _failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var run_state := root.get_node_or_null("RunState")
	var unfold_manager := root.get_node_or_null("UnfoldManager")
	var balance := root.get_node_or_null("Balance")
	if run_state == null or unfold_manager == null or balance == null:
		_fail("Failed to find required autoloads.")
		_finish()
		return

	run_state.reset_run()
	unfold_manager.set_gameplay_blocked(false)

	var packed := load(MAIN_SCENE) as PackedScene
	if packed == null:
		_fail("Failed to load main scene: %s" % MAIN_SCENE)
		_finish()
		return

	var main := packed.instantiate()
	root.add_child(main)
	await process_frame

	var overlay := main.get_node_or_null("UnfoldTransitionLayer/UnfoldTransitionOverlay")
	_assert(overlay != null, "Unfold transition overlay is present.")
	if overlay == null:
		_finish()
		return

	run_state.add_heat(balance.HEAT_TRIGGER_THRESHOLD)
	var started: bool = unfold_manager.start_unfold()
	_assert(started, "Unfold enter transition starts.")
	await process_frame
	_assert(bool(overlay.call("is_transition_visible")), "Enter overlay is visible after transition start.")
	_assert(String(overlay.call("get_transition_kind")) == "enter", "Enter overlay records transition kind.")

	OS.delay_msec(int((balance.UNFOLD_TRANSITION_IN + 0.08) * 1000.0))
	await process_frame
	_assert(unfold_manager.is_unfolded(), "Unfold manager enters unfolded mode after transition.")
	_assert(String(overlay.call("get_transition_kind")) == "enter", "Enter overlay receives entered settle phase.")

	OS.delay_msec(220)
	await process_frame
	_assert(not bool(overlay.call("is_transition_visible")), "Enter overlay hides after settle.")

	unfold_manager.end_unfold("collapse")
	await process_frame
	_assert(bool(overlay.call("is_transition_visible")), "Collapse overlay is visible after collapse start.")
	_assert(String(overlay.call("get_transition_kind")) == "collapse", "Collapse overlay records transition kind.")

	OS.delay_msec(int((balance.UNFOLD_COLLAPSE_TIME + 0.08) * 1000.0))
	await process_frame
	_assert(unfold_manager.is_cooldown(), "Unfold manager reaches cooldown after collapse.")

	OS.delay_msec(180)
	await process_frame
	_assert(not bool(overlay.call("is_transition_visible")), "Collapse overlay hides after fade.")

	root.remove_child(main)
	main.queue_free()
	await process_frame
	_finish()

func _assert(condition: bool, message: String) -> void:
	if not condition:
		_fail(message)

func _fail(message: String) -> void:
	_failures.append(message)
	printerr(message)

func _finish() -> void:
	Engine.time_scale = 1.0
	if not _failures.is_empty():
		printerr("Unfold transition smoke failed with %d failure(s)." % _failures.size())
		quit(1)
		return
	print("Unfold transition smoke passed.")
	quit(0)
