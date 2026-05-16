extends Node2D
class_name DemoRoom

@export var lane_profile: Resource

@onready var player_spawn: Marker2D = %PlayerSpawn
@onready var unfold_floor_center: Marker2D = %UnfoldFloorCenter
@onready var enemy_spawns: Node2D = %EnemySpawns
@onready var collapse_relocation_points: Node2D = %CollapseRelocationPoints
@onready var next_room_entries: Node2D = %NextRoomEntries

func get_lane_profile() -> Resource:
	return lane_profile

func get_room_lane_profile() -> Resource:
	return lane_profile

func get_unfold_lanes() -> Array[float]:
	if lane_profile == null:
		return []
	return lane_profile.lane_offsets

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

func _collect_marker_positions(parent: Node) -> Array[Vector2]:
	var positions: Array[Vector2] = []
	for child in parent.get_children():
		if child is Marker2D:
			positions.append(child.global_position)
	return positions
