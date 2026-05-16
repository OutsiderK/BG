extends SceneTree

const MAIN_SCENE := "res://game/scenes/main/Main.tscn"
const EPSILON := 0.5

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
	unfold_manager.set_unfold_blocked(false)
	unfold_manager.set_gameplay_blocked(false)

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
	var landing_hints := main.get_node_or_null("DemoRoom/RoomReadability/LandingHints")
	var snap_hints := main.get_node_or_null("DemoRoom/RoomReadability/SnapHints")
	var lane_preview := main.get_node_or_null("DemoRoom/LanePreview")
	if room == null or player == null or landing_hints == null or snap_hints == null or lane_preview == null:
		_fail("Failed to find lane mapping smoke nodes.")
		_finish()
		return

	var lane_before := _first_lane_alpha(lane_preview)
	_assert(lane_before <= 0.25, "Lane preview starts weak.")

	run_state.add_heat(balance.HEAT_TRIGGER_THRESHOLD)
	var did_start: bool = unfold_manager.start_unfold()
	_assert(did_start, "Unfold starts for lane smoke.")
	await _wait_until(func() -> bool: return unfold_manager.is_unfolded(), 90)
	_assert(unfold_manager.is_unfolded(), "Unfold reaches unfolded mode.")

	var lanes: Array[float] = room.call("get_unfold_lanes")
	_assert(lanes.size() >= 3, "Room exposes lane preview values.")
	_assert(landing_hints.get_child_count() >= 3, "Landing hints are generated for player and enemies.")
	_assert(_enemy_landing_hints_on_lanes(landing_hints, lanes, 2), "Enemy landing hints are placed on room lanes.")
	_assert(_first_lane_alpha(lane_preview) >= 0.6, "Lane preview strengthens while unfolded.")

	unfold_manager.end_unfold("collapse")
	await _wait_until(func() -> bool: return unfold_manager.is_cooldown(), 90)
	_assert(unfold_manager.is_cooldown(), "Collapse reaches cooldown mode.")
	_assert(snap_hints.get_child_count() >= 3, "Collapse creates snap point hints.")
	_assert(landing_hints.get_child_count() == 0, "Landing hints clear after collapse.")
	_assert(_first_lane_alpha(lane_preview) <= 0.25, "Lane preview returns to weak after collapse.")

	root.remove_child(main)
	main.queue_free()
	unfold_manager.set_gameplay_blocked(false)
	_finish()

func _wait_until(predicate: Callable, max_frames: int) -> void:
	for _frame in range(max_frames):
		if predicate.call():
			return
		await process_frame

func _first_lane_alpha(lane_preview: Node) -> float:
	for child in lane_preview.get_children():
		var lane_rect := child as ColorRect
		if lane_rect != null:
			return lane_rect.color.a
	return 0.0

func _approximately_has(values: Array[float], target: float) -> bool:
	for value in values:
		if absf(value - target) <= EPSILON:
			return true
	return false

func _enemy_landing_hints_on_lanes(landing_hints: Node, lanes: Array[float], expected_count: int) -> bool:
	var lane_hint_count := 0
	for child in landing_hints.get_children():
		var hint := child as Node2D
		if hint == null or not hint.name.begins_with("enemy_"):
			continue
		if not _approximately_has(lanes, hint.global_position.y):
			return false
		lane_hint_count += 1
	return lane_hint_count >= expected_count

func _assert(condition: bool, message: String) -> void:
	if not condition:
		_fail(message)

func _fail(message: String) -> void:
	_failures.append(message)
	printerr(message)

func _finish() -> void:
	if not _failures.is_empty():
		printerr("Lane mapping smoke failed with %d failure(s)." % _failures.size())
		quit(1)
		return
	print("Lane mapping smoke passed.")
	quit(0)
