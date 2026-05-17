extends Node2D
class_name DemoRoom

const LANE_WEAK_ALPHA := 0.16
const LANE_STRONG_ALPHA := 0.78
const LANE_BASE_COLOR := Color(0.52, 0.86, 0.66, 1.0)
const LANE_TICK_COLOR := Color(0.86, 0.96, 0.72, 1.0)
const LANE_NOTCH_COLOR := Color(0.24, 0.52, 0.42, 1.0)
const PLAYER_LANDING_COLOR := Color(0.98, 0.84, 0.36, 0.92)
const ENEMY_LANDING_COLOR := Color(1.0, 0.36, 0.30, 0.9)
const PLAYER_SNAP_COLOR := Color(0.48, 0.91, 0.92, 0.92)
const ENEMY_SNAP_COLOR := Color(1.0, 0.58, 0.34, 0.9)
const LANDING_HINT_SIZE := 34.0
const SNAP_HINT_SIZE := 42.0
const HINT_THICKNESS := 4.0
const SNAP_HINT_DURATION := 0.7
const LANE_TICK_HEIGHT := 18.0

@export var lane_profile: Resource

@onready var player_spawn: Marker2D = %PlayerSpawn
@onready var unfold_floor_center: Marker2D = %UnfoldFloorCenter
@onready var enemy_spawns: Node2D = %EnemySpawns
@onready var collapse_relocation_points: Node2D = %CollapseRelocationPoints
@onready var next_room_entries: Node2D = %NextRoomEntries
@onready var lane_preview: Node2D = $LanePreview
@onready var lane_markers: Node2D = $UnfoldData/LaneMarkers
@onready var landing_hints: Node2D = %LandingHints
@onready var snap_hints: Node2D = %SnapHints

var _landing_hint_nodes := {}

func _ready() -> void:
	_setup_lane_preview_art()
	_connect_unfold_signals()
	UnfoldManager.set_room_adapter(self)
	_set_lane_preview_strength(false)
	_clear_landing_hints()

func get_lane_profile() -> Resource:
	return lane_profile

func get_room_lane_profile() -> Resource:
	return lane_profile

func get_unfold_lanes() -> Array[float]:
	return _get_lane_y_values()

func get_unfold_floor_center() -> Vector2:
	return unfold_floor_center.global_position

func get_player_spawn_position() -> Vector2:
	return player_spawn.global_position

func get_enemy_spawn_positions() -> Array[Vector2]:
	return _collect_marker_positions(enemy_spawns)

func get_collapse_relocation_positions() -> Array[Vector2]:
	return _collect_marker_positions(collapse_relocation_points)

func get_next_room_entry_positions() -> Array[Vector2]:
	return _collect_marker_positions(next_room_entries)

func map_player_to_unfolded(player: Node, vertical_position: Vector2) -> Vector2:
	var target := Vector2(_clamp_room_x(vertical_position.x), unfold_floor_center.global_position.y)
	_update_landing_hint(_landing_key("player", player), target, true)
	return target

func map_enemy_to_unfolded(enemy: Node, vertical_position: Vector2, lane_index: int) -> Vector2:
	var target := Vector2(_clamp_room_x(vertical_position.x), _get_lane_y(lane_index))
	_update_landing_hint(_landing_key("enemy", enemy), target, false)
	return target

func restore_player_to_vertical(player: Node, unfold_position: Vector2, reason: String) -> Vector2:
	var restored_position: Vector2
	if lane_profile != null and lane_profile.has_method("get_player_restore_position"):
		restored_position = lane_profile.call("get_player_restore_position", unfold_position)
	else:
		restored_position = Vector2(_clamp_room_x(unfold_position.x), player_spawn.global_position.y)
	if reason == "collapse":
		_show_snap_hint(_landing_key("player_snap", player), restored_position, true)
	return restored_position

func restore_enemy_to_vertical(enemy: Node, unfold_position: Vector2, reason: String) -> Vector2:
	var restored_position: Vector2
	if lane_profile != null and lane_profile.has_method("get_enemy_restore_position"):
		restored_position = lane_profile.call("get_enemy_restore_position", unfold_position)
	else:
		restored_position = _get_nearest_collapse_relocation(unfold_position)
	if reason == "collapse":
		_show_snap_hint(_landing_key("enemy_snap", enemy), restored_position, false)
	return restored_position

func pick_enemy_unfold_lane(_enemy: Node, enemy_index: int, player_unfold_position: Vector2, preferred_lane: int = -1) -> int:
	var lane_count := _get_lane_count()
	if lane_count <= 0:
		return 0
	if preferred_lane >= 0:
		return wrapi(preferred_lane, 0, lane_count)
	var lanes: Array[int] = []
	for lane_index in range(lane_count):
		lanes.append(lane_index)
	lanes.sort_custom(func(a: int, b: int) -> bool:
		var distance_a := absf(_get_lane_y(a) - player_unfold_position.y)
		var distance_b := absf(_get_lane_y(b) - player_unfold_position.y)
		if is_equal_approx(distance_a, distance_b):
			return a < b
		return distance_a > distance_b
	)
	return lanes[wrapi(enemy_index, 0, lanes.size())]

func _collect_marker_positions(parent: Node) -> Array[Vector2]:
	var positions: Array[Vector2] = []
	for child in parent.get_children():
		if child is Marker2D:
			positions.append(child.global_position)
	return positions

func _connect_unfold_signals() -> void:
	if not UnfoldManager.unfold_transition_started.is_connected(_on_unfold_transition_started):
		UnfoldManager.unfold_transition_started.connect(_on_unfold_transition_started)
	if not UnfoldManager.unfold_entered.is_connected(_on_unfold_entered):
		UnfoldManager.unfold_entered.connect(_on_unfold_entered)
	if not UnfoldManager.unfold_ended.is_connected(_on_unfold_ended):
		UnfoldManager.unfold_ended.connect(_on_unfold_ended)
	if not UnfoldManager.mapping_applied.is_connected(_on_mapping_applied):
		UnfoldManager.mapping_applied.connect(_on_mapping_applied)

func _on_unfold_transition_started(kind: String) -> void:
	if kind == "collapse":
		_set_lane_preview_strength(false)

func _on_mapping_applied() -> void:
	_set_lane_preview_strength(true)

func _on_unfold_entered() -> void:
	_set_lane_preview_strength(true)

func _on_unfold_ended(_reason: String) -> void:
	_set_lane_preview_strength(false)
	_clear_landing_hints()

func _set_lane_preview_strength(strong: bool) -> void:
	var alpha := LANE_STRONG_ALPHA if strong else LANE_WEAK_ALPHA
	for child in lane_preview.get_children():
		var lane_rect := child as ColorRect
		if lane_rect == null:
			continue
		var color := LANE_BASE_COLOR
		color.a = alpha
		lane_rect.color = color
		_apply_lane_child_alpha(lane_rect, alpha)

func _setup_lane_preview_art() -> void:
	for child in lane_preview.get_children():
		var lane_rect := child as ColorRect
		if lane_rect == null:
			continue
		lane_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if lane_rect.has_node("CoordinateTicks"):
			continue
		var width := lane_rect.size.x
		if width <= 0.0:
			width = 1120.0
		_add_lane_bar(lane_rect, "UpperCut", Vector2(width, 1.0), Vector2(0, -5), LANE_NOTCH_COLOR, 0.72)
		_add_lane_bar(lane_rect, "LowerCut", Vector2(width, 1.0), Vector2(0, 8), LANE_NOTCH_COLOR, 0.62)
		var ticks := Node2D.new()
		ticks.name = "CoordinateTicks"
		lane_rect.add_child(ticks)
		for x in range(0, int(width) + 1, 140):
			var height := LANE_TICK_HEIGHT if x % 280 == 0 else LANE_TICK_HEIGHT * 0.62
			_add_lane_bar(ticks, "Tick%03d" % x, Vector2(2, height), Vector2(x - 1, -height * 0.5 + 2), LANE_TICK_COLOR, 0.86)
		for x in range(70, int(width), 280):
			_add_lane_bar(ticks, "Fragment%03d" % x, Vector2(46, 2), Vector2(x, -1), LANE_TICK_COLOR, 0.55)

func _add_lane_bar(parent: Node, bar_name: String, size: Vector2, position: Vector2, color: Color, alpha_scale: float) -> ColorRect:
	var bar := ColorRect.new()
	bar.name = bar_name
	bar.size = size
	bar.position = position
	bar.color = color
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.set_meta("base_color", color)
	bar.set_meta("alpha_scale", alpha_scale)
	parent.add_child(bar)
	return bar

func _apply_lane_child_alpha(parent: Node, alpha: float) -> void:
	for child in parent.get_children():
		var rect := child as ColorRect
		if rect != null:
			var base_color := rect.color
			var meta_color = rect.get_meta("base_color", null)
			if meta_color is Color:
				base_color = meta_color
			base_color.a = clampf(alpha * float(rect.get_meta("alpha_scale", 1.0)), 0.0, 1.0)
			rect.color = base_color
		_apply_lane_child_alpha(child, alpha)

func _update_landing_hint(key: String, global_point: Vector2, is_player_hint: bool) -> void:
	var color := PLAYER_LANDING_COLOR if is_player_hint else ENEMY_LANDING_COLOR
	var hint := _ensure_landing_hint(key, color)
	hint.global_position = global_point
	hint.visible = true
	hint.modulate = Color.WHITE
	hint.scale = Vector2(0.82, 0.82)
	var tween := create_tween()
	tween.tween_property(hint, "scale", Vector2.ONE, 0.14)

func _ensure_landing_hint(key: String, color: Color) -> Node2D:
	var hint = _landing_hint_nodes.get(key)
	if hint is Node2D and is_instance_valid(hint):
		_recolor_hint(hint, color)
		return hint
	var created := _create_cross_hint(key, color, LANDING_HINT_SIZE)
	landing_hints.add_child(created)
	_landing_hint_nodes[key] = created
	return created

func _show_snap_hint(key: String, global_point: Vector2, is_player_hint: bool) -> void:
	var color := PLAYER_SNAP_COLOR if is_player_hint else ENEMY_SNAP_COLOR
	var hint := _create_cross_hint(key, color, SNAP_HINT_SIZE)
	snap_hints.add_child(hint)
	hint.global_position = global_point
	hint.scale = Vector2(0.72, 0.72)
	var tween := create_tween()
	tween.tween_property(hint, "scale", Vector2(1.28, 1.28), SNAP_HINT_DURATION)
	tween.parallel().tween_property(hint, "modulate:a", 0.0, SNAP_HINT_DURATION)
	tween.tween_callback(Callable(hint, "queue_free"))

func _create_cross_hint(hint_name: String, color: Color, size: float) -> Node2D:
	var hint := Node2D.new()
	hint.name = hint_name
	hint.z_index = 1
	var half := size * 0.5
	var corner := size * 0.28
	var center := _create_hint_bar("Center", color, Vector2(HINT_THICKNESS * 1.35, HINT_THICKNESS * 1.35), Vector2(-HINT_THICKNESS * 0.675, -HINT_THICKNESS * 0.675))
	var upper_left_h := _create_hint_bar("UpperLeftH", color, Vector2(corner, HINT_THICKNESS), Vector2(-half, -half))
	var upper_left_v := _create_hint_bar("UpperLeftV", color, Vector2(HINT_THICKNESS, corner), Vector2(-half, -half))
	var upper_right_h := _create_hint_bar("UpperRightH", color, Vector2(corner, HINT_THICKNESS), Vector2(half - corner, -half))
	var upper_right_v := _create_hint_bar("UpperRightV", color, Vector2(HINT_THICKNESS, corner), Vector2(half - HINT_THICKNESS, -half))
	var lower_left_h := _create_hint_bar("LowerLeftH", color, Vector2(corner, HINT_THICKNESS), Vector2(-half, half - HINT_THICKNESS))
	var lower_left_v := _create_hint_bar("LowerLeftV", color, Vector2(HINT_THICKNESS, corner), Vector2(-half, half - corner))
	var lower_right_h := _create_hint_bar("LowerRightH", color, Vector2(corner, HINT_THICKNESS), Vector2(half - corner, half - HINT_THICKNESS))
	var lower_right_v := _create_hint_bar("LowerRightV", color, Vector2(HINT_THICKNESS, corner), Vector2(half - HINT_THICKNESS, half - corner))
	for bar in [upper_left_h, upper_left_v, upper_right_h, upper_right_v, lower_left_h, lower_left_v, lower_right_h, lower_right_v, center]:
		hint.add_child(bar)
	return hint

func _create_hint_bar(bar_name: String, color: Color, size: Vector2, position: Vector2) -> ColorRect:
	var bar := ColorRect.new()
	bar.name = bar_name
	bar.color = color
	bar.size = size
	bar.position = position
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return bar

func _recolor_hint(hint: Node, color: Color) -> void:
	for child in hint.get_children():
		var bar := child as ColorRect
		if bar != null:
			bar.color = color

func _clear_landing_hints() -> void:
	for child in landing_hints.get_children():
		child.queue_free()
	_landing_hint_nodes.clear()

func _landing_key(prefix: String, node: Node) -> String:
	if node != null and is_instance_valid(node):
		return "%s_%s" % [prefix, node.get_instance_id()]
	return "%s_unknown" % prefix

func _get_lane_y_values() -> Array[float]:
	var values: Array[float] = []
	for child in lane_markers.get_children():
		var marker := child as Marker2D
		if marker != null:
			values.append(marker.global_position.y)
	if not values.is_empty():
		return values
	if lane_profile != null and lane_profile.has_method("get_lane_count") and lane_profile.has_method("get_lane_z"):
		for lane_index in range(int(lane_profile.call("get_lane_count"))):
			values.append(float(lane_profile.call("get_lane_z", lane_index)))
	if values.is_empty():
		values.append(unfold_floor_center.global_position.y)
	return values

func _get_lane_count() -> int:
	return _get_lane_y_values().size()

func _get_lane_y(lane_index: int) -> float:
	var lane_values := _get_lane_y_values()
	if lane_values.is_empty():
		return unfold_floor_center.global_position.y
	return lane_values[wrapi(lane_index, 0, lane_values.size())]

func _clamp_room_x(x: float) -> float:
	if lane_profile != null:
		var x_min = lane_profile.get("x_min")
		var x_max = lane_profile.get("x_max")
		if x_min is float and x_max is float:
			return clampf(x, x_min, x_max)
	return x

func _get_nearest_collapse_relocation(point: Vector2) -> Vector2:
	var positions := get_collapse_relocation_positions()
	if positions.is_empty():
		return Vector2(point.x, player_spawn.global_position.y)
	var nearest_position := positions[0]
	var nearest_distance := point.distance_to(nearest_position)
	for position in positions:
		var distance := point.distance_to(position)
		if distance < nearest_distance:
			nearest_position = position
			nearest_distance = distance
	return nearest_position
