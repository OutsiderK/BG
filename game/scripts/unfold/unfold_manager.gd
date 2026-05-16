extends Node

const RoomLaneProfileScript := preload("res://game/scripts/rooms/room_lane_profile.gd")
const UnfoldMapperScript := preload("res://game/scripts/unfold/unfold_mapper.gd")

signal unfold_started
signal unfold_transition_started(kind: String)
signal unfold_mode_changed(mode: int, mode_name: String)
signal unfold_entered
signal unfold_ended(reason: String)
signal cooldown_started(duration: float)
signal mapping_applied

enum Mode {
	VERTICAL,
	TRANSITION,
	UNFOLDED,
	COOLDOWN,
}

enum TransitionKind {
	NONE,
	ENTER,
	COLLAPSE,
}

var mode := Mode.VERTICAL
var cooldown_remaining := 0.0
var transition_remaining := 0.0
var room_profile: Resource = RoomLaneProfileScript.new()
var room_adapter: Node
var player_node: Node
var enemy_nodes: Array[Node] = []
var anti_unfold_blocked := false
var gameplay_blocked := false

var _transition_kind := TransitionKind.NONE
var _transition_duration := 0.0
var _transition_started_msec := 0
var _pending_end_reason := ""
var _pending_cooldown := 0.0
var _previous_time_scale := 1.0
var _mapped_records := {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_set_mode(Mode.VERTICAL)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("unfold"):
		request_toggle_unfold()
		get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
	if mode == Mode.TRANSITION:
		_update_transition()
		return
	if mode == Mode.COOLDOWN:
		cooldown_remaining = maxf(0.0, cooldown_remaining - delta)
		if cooldown_remaining <= 0.0:
			_set_mode(Mode.VERTICAL)
	if mode == Mode.UNFOLDED:
		RunState.consume_heat(Balance.UNFOLD_CONSUME_RATE * delta)
		if RunState.heat <= 0.0:
			end_unfold("natural")

func request_toggle_unfold() -> bool:
	if mode == Mode.UNFOLDED:
		end_unfold("early")
		return true
	return start_unfold()

func can_unfold() -> bool:
	return (
		mode == Mode.VERTICAL
		and RunState.can_unfold()
		and not anti_unfold_blocked
		and not gameplay_blocked
	)

func start_unfold() -> bool:
	if not can_unfold():
		return false
	_resolve_scene_participants()
	_begin_transition(TransitionKind.ENTER, Balance.UNFOLD_TRANSITION_IN)
	return true

func end_unfold(reason: String) -> void:
	if mode == Mode.TRANSITION and reason == "collapse":
		_force_collapse_from_transition()
		return
	if mode != Mode.UNFOLDED:
		return
	match reason:
		"collapse":
			RunState.consume_heat(RunState.heat)
			RunState.add_unfold_risk(Balance.RISK_COLLAPSE)
			RunState.add_corruption(Balance.CORRUPTION_COLLAPSE)
			_pending_end_reason = "collapse"
			_pending_cooldown = Balance.UNFOLD_COOLDOWN_COLLAPSE
			_begin_transition(TransitionKind.COLLAPSE, Balance.UNFOLD_COLLAPSE_TIME)
		"early":
			RunState.add_unfold_risk(Balance.RISK_UNFOLD_EARLY)
			RunState.add_corruption(Balance.CORRUPTION_UNFOLD_EARLY)
			_finish_unfold("early", Balance.UNFOLD_COOLDOWN_NORMAL)
		_:
			RunState.consume_heat(RunState.heat)
			RunState.add_unfold_risk(Balance.RISK_UNFOLD_FULL)
			RunState.add_corruption(Balance.CORRUPTION_UNFOLD_FULL)
			_finish_unfold("natural", Balance.UNFOLD_COOLDOWN_NORMAL)

func is_unfolded() -> bool:
	return mode == Mode.UNFOLDED

func is_vertical() -> bool:
	return mode == Mode.VERTICAL

func is_transition() -> bool:
	return mode == Mode.TRANSITION

func is_cooldown() -> bool:
	return mode == Mode.COOLDOWN

func get_current_transition_kind() -> String:
	return _transition_kind_name(_transition_kind)

func get_transition_kind() -> int:
	return _transition_kind

func get_cooldown_remaining() -> float:
	return cooldown_remaining

func get_transition_progress() -> float:
	if mode != Mode.TRANSITION:
		return 0.0
	if _transition_duration <= 0.0:
		return 1.0
	return clampf(1.0 - (transition_remaining / _transition_duration), 0.0, 1.0)

func is_collapse_transition() -> bool:
	return mode == Mode.TRANSITION and _transition_kind == TransitionKind.COLLAPSE

func get_mode_name() -> String:
	return _mode_name(mode)

func set_room_profile(profile: Resource) -> void:
	if profile != null:
		room_profile = profile

func set_room_adapter(adapter: Node) -> void:
	room_adapter = adapter
	if room_adapter == null:
		return
	if room_adapter.has_method("get_room_lane_profile"):
		var profile_candidate = room_adapter.call("get_room_lane_profile")
		if profile_candidate is Resource:
			room_profile = profile_candidate
		return
	var property_candidate = room_adapter.get("room_lane_profile")
	if property_candidate is Resource:
		room_profile = property_candidate

func set_player(node: Node) -> void:
	player_node = node

func register_enemy(enemy: Node) -> void:
	if enemy != null and not enemy_nodes.has(enemy):
		enemy_nodes.append(enemy)

func unregister_enemy(enemy: Node) -> void:
	enemy_nodes.erase(enemy)

func clear_enemies() -> void:
	enemy_nodes.clear()

func set_unfold_blocked(blocked: bool) -> void:
	anti_unfold_blocked = blocked

func set_gameplay_blocked(blocked: bool) -> void:
	gameplay_blocked = blocked

func collapse() -> void:
	end_unfold("collapse")

func _start_cooldown(duration: float) -> void:
	cooldown_remaining = duration
	_set_mode(Mode.COOLDOWN)
	cooldown_started.emit(duration)

func _begin_transition(kind: int, duration: float) -> void:
	_transition_kind = kind
	_transition_duration = maxf(0.0, duration)
	transition_remaining = _transition_duration
	_transition_started_msec = Time.get_ticks_msec()
	_previous_time_scale = Engine.time_scale
	Engine.time_scale = 0.0
	_set_mode(Mode.TRANSITION)
	unfold_transition_started.emit(_transition_kind_name(kind))
	if _transition_duration <= 0.0:
		_finish_transition()

func _update_transition() -> void:
	var elapsed := float(Time.get_ticks_msec() - _transition_started_msec) / 1000.0
	transition_remaining = maxf(0.0, _transition_duration - elapsed)
	if elapsed >= _transition_duration:
		_finish_transition()

func _finish_transition() -> void:
	Engine.time_scale = _previous_time_scale
	match _transition_kind:
		TransitionKind.ENTER:
			_apply_unfold_mapping()
			_transition_kind = TransitionKind.NONE
			_set_mode(Mode.UNFOLDED)
			unfold_started.emit()
			unfold_entered.emit()
		TransitionKind.COLLAPSE:
			var reason := _pending_end_reason
			var cooldown := _pending_cooldown
			_transition_kind = TransitionKind.NONE
			_pending_end_reason = ""
			_pending_cooldown = 0.0
			_finish_unfold(reason, cooldown)
		_:
			_transition_kind = TransitionKind.NONE

func _finish_unfold(reason: String, cooldown: float) -> void:
	_restore_vertical_mapping(reason)
	_start_cooldown(cooldown)
	unfold_ended.emit(reason)

func _force_collapse_from_transition() -> void:
	Engine.time_scale = _previous_time_scale
	_transition_kind = TransitionKind.NONE
	RunState.consume_heat(RunState.heat)
	RunState.add_unfold_risk(Balance.RISK_COLLAPSE)
	RunState.add_corruption(Balance.CORRUPTION_COLLAPSE)
	_mapped_records.clear()
	_start_cooldown(Balance.UNFOLD_COOLDOWN_COLLAPSE)
	unfold_ended.emit("collapse")

func _apply_unfold_mapping() -> void:
	_mapped_records.clear()
	if player_node != null and is_instance_valid(player_node):
		var player_position := _get_node_position(player_node)
		var unfolded_player_position := _call_room_mapping(
			"map_player_to_unfolded",
			[player_node, player_position],
			UnfoldMapperScript.map_player_to_unfolded(player_position, room_profile)
		)
		_store_mapping_record(player_node, player_position, -1)
		_set_node_position(player_node, unfolded_player_position)
		var live_enemies := _get_live_enemies()
		for enemy_index in range(live_enemies.size()):
			var enemy := live_enemies[enemy_index]
			var enemy_position := _get_node_position(enemy)
			var lane := _get_enemy_lane(enemy, enemy_index, unfolded_player_position)
			var unfolded_enemy_position := _call_room_mapping(
				"map_enemy_to_unfolded",
				[enemy, enemy_position, lane],
				UnfoldMapperScript.map_enemy_to_unfolded(enemy_position, room_profile, lane)
			)
			_store_mapping_record(enemy, enemy_position, lane)
			_set_node_position(enemy, unfolded_enemy_position)
			if enemy.has_method("enter_unfolded"):
				enemy.call("enter_unfolded", lane)
	mapping_applied.emit()

func _restore_vertical_mapping(reason: String) -> void:
	if player_node != null and is_instance_valid(player_node) and _mapped_records.has(player_node.get_instance_id()):
		var player_unfold_position := _get_node_position(player_node)
		var restored_player_position := _call_room_mapping(
			"restore_player_to_vertical",
			[player_node, player_unfold_position, reason],
			UnfoldMapperScript.restore_player_to_vertical(player_unfold_position, room_profile)
		)
		_set_node_position(player_node, restored_player_position)
	for enemy in _get_live_enemies():
		if not _mapped_records.has(enemy.get_instance_id()):
			continue
		var enemy_unfold_position := _get_node_position(enemy)
		var restored_enemy_position := _call_room_mapping(
			"restore_enemy_to_vertical",
			[enemy, enemy_unfold_position, reason],
			UnfoldMapperScript.restore_enemy_to_vertical(enemy_unfold_position, room_profile)
		)
		_set_node_position(enemy, restored_enemy_position)
		if enemy.has_method("exit_unfolded"):
			enemy.call("exit_unfolded")
	_mapped_records.clear()

func _resolve_scene_participants() -> void:
	if room_profile == null:
		room_profile = RoomLaneProfileScript.new()
	var current_scene := get_tree().current_scene
	if current_scene == null:
		return
	if room_adapter == null:
		room_adapter = _find_first_node_with_room_profile(current_scene)
		if room_adapter != null:
			set_room_adapter(room_adapter)
	if player_node == null or not is_instance_valid(player_node):
		player_node = _find_first_node_named(current_scene, "Player")
	if enemy_nodes.is_empty():
		_collect_enemies(current_scene, enemy_nodes)

func _get_live_enemies() -> Array[Node]:
	var live_enemies: Array[Node] = []
	for enemy in enemy_nodes:
		if enemy != null and is_instance_valid(enemy) and not enemy.is_queued_for_deletion():
			live_enemies.append(enemy)
	return live_enemies

func _get_enemy_lane(enemy: Node, enemy_index: int, player_unfold_position: Vector2) -> int:
	var preferred_lane := _get_optional_int(enemy, "unfold_preferred_lane", -1)
	if enemy.has_method("get_unfold_lane"):
		preferred_lane = int(enemy.call("get_unfold_lane"))
	var lane := 0
	if room_adapter != null and room_adapter.has_method("pick_enemy_unfold_lane"):
		lane = int(room_adapter.call("pick_enemy_unfold_lane", enemy, enemy_index, player_unfold_position, preferred_lane))
	else:
		lane = room_profile.pick_enemy_lane(player_unfold_position, enemy_index, preferred_lane)
	return _normalize_lane(lane)

func _normalize_lane(lane: int) -> int:
	if room_profile != null and room_profile.has_method("normalize_lane_index"):
		return int(room_profile.call("normalize_lane_index", lane))
	return maxi(lane, 0)

func _store_mapping_record(node: Node, original_position: Vector2, lane: int) -> void:
	_mapped_records[node.get_instance_id()] = {
		"original_position": original_position,
		"lane": lane,
	}

func _call_room_mapping(method_name: String, arguments: Array, fallback: Vector2) -> Vector2:
	if room_adapter != null and room_adapter.has_method(method_name):
		var mapped = room_adapter.callv(method_name, arguments)
		if mapped is Vector2:
			return mapped
	return fallback

func _get_node_position(node: Node) -> Vector2:
	var node_2d := node as Node2D
	if node_2d == null:
		return Vector2.ZERO
	return node_2d.global_position

func _set_node_position(node: Node, position: Vector2) -> void:
	var node_2d := node as Node2D
	if node_2d != null:
		node_2d.global_position = position

func _get_optional_int(node: Node, property_name: String, fallback: int) -> int:
	var value = node.get(property_name)
	if value == null:
		return fallback
	if value is int:
		return value
	if value is float:
		return int(value)
	return fallback

func _find_first_node_named(root: Node, target_name: String) -> Node:
	if root.name == target_name:
		return root
	for child in root.get_children():
		var found := _find_first_node_named(child, target_name)
		if found != null:
			return found
	return null

func _find_first_node_with_room_profile(root: Node) -> Node:
	if root.has_method("get_room_lane_profile"):
		return root
	var property_candidate = root.get("room_lane_profile")
	if property_candidate is Resource:
		return root
	for child in root.get_children():
		var found := _find_first_node_with_room_profile(child)
		if found != null:
			return found
	return null

func _collect_enemies(root: Node, result: Array[Node]) -> void:
	if root != self and root != player_node and root.has_method("enter_unfolded") and root.has_method("exit_unfolded"):
		result.append(root)
	for child in root.get_children():
		_collect_enemies(child, result)

func _set_mode(next_mode: int) -> void:
	mode = next_mode
	unfold_mode_changed.emit(mode, _mode_name(mode))

func _mode_name(value: int) -> String:
	match value:
		Mode.VERTICAL:
			return "Vertical"
		Mode.TRANSITION:
			return "Transition"
		Mode.UNFOLDED:
			return "Unfolded"
		Mode.COOLDOWN:
			return "Cooldown"
		_:
			return "Unknown"

func _transition_kind_name(value: int) -> String:
	match value:
		TransitionKind.ENTER:
			return "enter"
		TransitionKind.COLLAPSE:
			return "collapse"
		_:
			return "none"
