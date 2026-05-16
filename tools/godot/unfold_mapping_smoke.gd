extends SceneTree

const RoomLaneProfileScript := preload("res://game/scripts/rooms/room_lane_profile.gd")
const TRANSITION_TIMEOUT := 2.0
const COOLDOWN_TIMEOUT := 2.5
const EPSILON := 0.01

class EnemyProbe:
	extends Node2D

	var entered_lane := -1
	var exited := false

	func enter_unfolded(lane: int) -> void:
		entered_lane = lane

	func exit_unfolded() -> void:
		exited = true

class RoomAdapterProbe:
	extends Node

	var profile: Resource

	func get_room_lane_profile() -> Resource:
		return profile

	func pick_enemy_unfold_lane(_enemy: Node, enemy_index: int, player_unfold_position: Vector2, preferred_lane: int) -> int:
		if enemy_index == 0:
			return 99
		return profile.pick_enemy_lane(player_unfold_position, enemy_index, preferred_lane)

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
	unfold_manager.set_unfold_blocked(false)
	unfold_manager.clear_enemies()
	Engine.time_scale = 1.0

	var profile := _make_profile()
	var adapter := RoomAdapterProbe.new()
	adapter.profile = profile
	root.add_child(adapter)
	unfold_manager.set_room_adapter(adapter)

	var player := Node2D.new()
	player.name = "PlayerProbe"
	player.global_position = Vector2(333.5, 480.0)
	root.add_child(player)
	unfold_manager.set_player(player)

	var enemy_a := EnemyProbe.new()
	enemy_a.name = "EnemyProbeA"
	enemy_a.global_position = Vector2(150.0, 480.0)
	root.add_child(enemy_a)
	unfold_manager.register_enemy(enemy_a)

	var enemy_b := EnemyProbe.new()
	enemy_b.name = "EnemyProbeB"
	enemy_b.global_position = Vector2(980.0, 480.0)
	root.add_child(enemy_b)
	unfold_manager.register_enemy(enemy_b)

	run_state.add_heat(balance.HEAT_TRIGGER_THRESHOLD)
	var player_start_x := player.global_position.x
	var started: bool = unfold_manager.start_unfold()
	_assert(started, "Unfold starts after heat is full.")
	_assert(unfold_manager.is_transition(), "Unfold enters transition mode.")
	_assert(unfold_manager.get_current_transition_kind() == "enter", "Enter transition kind is exposed.")
	_assert(not unfold_manager.is_collapse_transition(), "Enter transition is not reported as collapse.")
	_assert(unfold_manager.get_cooldown_remaining() <= EPSILON, "Cooldown query is zero before unfold ends.")
	_assert(_is_unit_range(unfold_manager.get_transition_progress()), "Transition progress query is clamped.")

	if not await _wait_for_unfolded(unfold_manager):
		_fail("Unfold did not finish entering before timeout.")
		_finish()
		return

	_assert(is_equal_approx(player.global_position.x, player_start_x), "Player X is preserved while mapping to unfolded.")
	_assert(profile.get_nearest_legal_unfold_point(player.global_position).is_equal_approx(player.global_position), "Player unfolded point is legal.")

	var expected_lane_a: int = profile.normalize_lane_index(99)
	var expected_lane_b: int = profile.pick_enemy_lane(player.global_position, 1)
	_assert(enemy_a.entered_lane == expected_lane_a, "Adapter enemy lane is normalized before entering unfolded.")
	_assert(enemy_b.entered_lane == expected_lane_b, "Enemy lane assignment follows the room profile.")
	_assert(is_equal_approx(enemy_a.global_position.y, profile.get_lane_z(expected_lane_a)), "Enemy A lands on its assigned lane.")
	_assert(is_equal_approx(enemy_b.global_position.y, profile.get_lane_z(expected_lane_b)), "Enemy B lands on its assigned lane.")

	player.global_position = Vector2(profile.get_x_max() + 80.0, profile.get_z_min() - 40.0)
	unfold_manager.end_unfold("early")
	_assert(unfold_manager.is_cooldown(), "Active unfold end starts cooldown.")
	_assert(unfold_manager.get_cooldown_remaining() > 0.0, "Cooldown query reports active cooldown.")
	_assert(_is_legal_vertical_player_point(player.global_position, profile), "Active end restores player to a legal ground point.")
	_assert(enemy_a.exited and enemy_b.exited, "Enemies are notified when active unfold ends.")

	if not await _wait_for_vertical(unfold_manager):
		_fail("Cooldown did not return to vertical mode before timeout.")
		_finish()
		return

	enemy_a.exited = false
	enemy_b.exited = false
	run_state.add_heat(balance.HEAT_TRIGGER_THRESHOLD)
	started = unfold_manager.start_unfold()
	_assert(started, "Second unfold starts after cooldown and heat refill.")
	if not await _wait_for_unfolded(unfold_manager):
		_fail("Second unfold did not finish entering before timeout.")
		_finish()
		return

	unfold_manager.collapse()
	_assert(unfold_manager.is_transition(), "Collapse enters transition mode.")
	_assert(unfold_manager.is_collapse_transition(), "Collapse transition query is true during collapse.")
	_assert(unfold_manager.get_current_transition_kind() == "collapse", "Collapse transition kind is exposed.")
	_assert(_is_unit_range(unfold_manager.get_transition_progress()), "Collapse progress query is clamped.")

	if not await _wait_for_cooldown(unfold_manager):
		_fail("Collapse did not reach cooldown before timeout.")
		_finish()
		return

	unfold_manager.clear_enemies()
	root.remove_child(player)
	player.queue_free()
	root.remove_child(enemy_a)
	enemy_a.queue_free()
	root.remove_child(enemy_b)
	enemy_b.queue_free()
	root.remove_child(adapter)
	adapter.queue_free()
	Engine.time_scale = 1.0
	_finish()

func _make_profile() -> Resource:
	var profile := RoomLaneProfileScript.new()
	profile.x_min = 120.0
	profile.x_max = 1080.0
	profile.z_min = 100.0
	profile.z_max = 620.0
	profile.lane_z_values = [140.0, 360.0, 580.0]
	profile.lane_offsets = []
	profile.vertical_platform_y_values = [318.0, 480.0]
	profile.enemy_ground_y_values = [480.0]
	profile.fallback_vertical_y = 480.0
	profile.fallback_enemy_relocation = Vector2(640.0, 480.0)
	return profile

func _wait_for_unfolded(unfold_manager: Node) -> bool:
	var started_msec := Time.get_ticks_msec()
	while Time.get_ticks_msec() - started_msec <= int(TRANSITION_TIMEOUT * 1000.0):
		if unfold_manager.is_unfolded():
			return true
		await process_frame
	return false

func _wait_for_cooldown(unfold_manager: Node) -> bool:
	var started_msec := Time.get_ticks_msec()
	while Time.get_ticks_msec() - started_msec <= int(TRANSITION_TIMEOUT * 1000.0):
		if unfold_manager.is_cooldown():
			return true
		await process_frame
	return false

func _wait_for_vertical(unfold_manager: Node) -> bool:
	var started_msec := Time.get_ticks_msec()
	while Time.get_ticks_msec() - started_msec <= int(COOLDOWN_TIMEOUT * 1000.0):
		if unfold_manager.is_vertical():
			return true
		await process_frame
	return false

func _is_legal_vertical_player_point(point: Vector2, profile: Resource) -> bool:
	if point.x < profile.get_x_min() - EPSILON or point.x > profile.get_x_max() + EPSILON:
		return false
	for platform_y in profile.vertical_platform_y_values:
		if is_equal_approx(point.y, platform_y):
			return true
	return false

func _is_unit_range(value: float) -> bool:
	return value >= 0.0 and value <= 1.0

func _assert(condition: bool, message: String) -> void:
	if not condition:
		_fail(message)

func _fail(message: String) -> void:
	_failures.append(message)
	printerr(message)

func _finish() -> void:
	Engine.time_scale = 1.0
	if not _failures.is_empty():
		printerr("Unfold mapping smoke failed with %d failure(s)." % _failures.size())
		quit(1)
		return
	print("Unfold mapping smoke passed.")
	quit(0)
