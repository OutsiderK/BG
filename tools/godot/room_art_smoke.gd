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
	var lane_preview := main.get_node_or_null("DemoRoom/LanePreview")
	if room == null or lane_preview == null:
		_fail("Failed to find room art smoke nodes.")
		_finish()
		return

	_assert(_has_visual_art_nodes(room), "Thin forest art layers are present.")
	_assert(not _art_has_collision(room), "Thin forest art layers do not add collision.")
	_assert(_geometry_visuals_align(room), "Geometry visual top edges align with collision tops.")
	_assert(_lane_has_slice_art(lane_preview), "Lane preview has coordinate slice art.")

	var weak_alpha := _first_lane_alpha(lane_preview)
	var weak_tick_alpha := _first_tick_alpha(lane_preview)
	_assert(weak_alpha <= 0.25, "Lane art starts weak.")

	run_state.add_heat(balance.HEAT_TRIGGER_THRESHOLD)
	var started: bool = unfold_manager.start_unfold()
	_assert(started, "Unfold starts for room art smoke.")
	await _wait_until(func() -> bool: return unfold_manager.is_unfolded(), 90)
	_assert(unfold_manager.is_unfolded(), "Unfold reaches unfolded mode for room art smoke.")
	_assert(_first_lane_alpha(lane_preview) >= 0.6, "Lane art strengthens while unfolded.")
	_assert(_first_tick_alpha(lane_preview) > weak_tick_alpha, "Lane coordinate ticks strengthen with the lane.")

	root.remove_child(main)
	main.queue_free()
	unfold_manager.set_gameplay_blocked(false)
	_finish()

func _has_visual_art_nodes(room: Node) -> bool:
	return (
		room.get_node_or_null("Backdrop/ThinForestBackdropArt") != null
		and room.get_node_or_null("ThinForestMidgroundArt") != null
		and room.get_node_or_null("ThinForestForegroundArt") != null
	)

func _art_has_collision(room: Node) -> bool:
	for path in ["Backdrop/ThinForestBackdropArt", "ThinForestMidgroundArt", "ThinForestForegroundArt"]:
		var art_node := room.get_node_or_null(path)
		if art_node != null and _has_collision_descendant(art_node):
			return true
	return false

func _has_collision_descendant(node: Node) -> bool:
	for child in node.get_children():
		if child is CollisionObject2D or child is CollisionShape2D:
			return true
		if _has_collision_descendant(child):
			return true
	return false

func _geometry_visuals_align(room: Node) -> bool:
	for path in [
		"Geometry/Ground",
		"Geometry/LowBranchPlatform",
		"Geometry/HighBranchPlatform",
		"Geometry/ThinTreeTrunk",
		"Geometry/RootBulwark",
	]:
		var body := room.get_node_or_null(path)
		if body == null:
			return false
		var shape_node := body.get_node_or_null("CollisionShape2D") as CollisionShape2D
		var visual := body.get_node_or_null("Visual") as ColorRect
		if shape_node == null or visual == null:
			return false
		var rect_shape := shape_node.shape as RectangleShape2D
		if rect_shape == null:
			return false
		var collision_top := shape_node.global_position.y - rect_shape.size.y * 0.5
		if absf(visual.global_position.y - collision_top) > EPSILON:
			return false
	return true

func _lane_has_slice_art(lane_preview: Node) -> bool:
	for child in lane_preview.get_children():
		var lane_rect := child as ColorRect
		if lane_rect == null:
			continue
		if lane_rect.get_node_or_null("CoordinateTicks") != null:
			return true
	return false

func _first_lane_alpha(lane_preview: Node) -> float:
	for child in lane_preview.get_children():
		var lane_rect := child as ColorRect
		if lane_rect != null:
			return lane_rect.color.a
	return 0.0

func _first_tick_alpha(lane_preview: Node) -> float:
	for child in lane_preview.get_children():
		var lane_rect := child as ColorRect
		if lane_rect == null:
			continue
		var ticks := lane_rect.get_node_or_null("CoordinateTicks")
		if ticks == null:
			continue
		for tick in ticks.get_children():
			var tick_rect := tick as ColorRect
			if tick_rect != null:
				return tick_rect.color.a
	return 0.0

func _wait_until(predicate: Callable, max_frames: int) -> void:
	for _frame in range(max_frames):
		if predicate.call():
			return
		await process_frame

func _assert(condition: bool, message: String) -> void:
	if not condition:
		_fail(message)

func _fail(message: String) -> void:
	_failures.append(message)
	printerr(message)

func _finish() -> void:
	if not _failures.is_empty():
		printerr("Room art smoke failed with %d failure(s)." % _failures.size())
		quit(1)
		return
	print("Room art smoke passed.")
	quit(0)
