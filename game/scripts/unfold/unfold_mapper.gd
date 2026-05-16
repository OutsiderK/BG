extends RefCounted
class_name UnfoldMapper

static func map_player_to_unfolded(vertical_position: Vector2, profile: RoomLaneProfile) -> Vector2:
	return profile.get_player_unfold_start(vertical_position)

static func map_enemy_to_unfolded(vertical_position: Vector2, profile: RoomLaneProfile, lane_index: int) -> Vector2:
	return profile.get_enemy_unfold_start(vertical_position, lane_index)

static func restore_player_to_vertical(unfold_position: Vector2, profile: RoomLaneProfile) -> Vector2:
	return profile.get_player_restore_position(unfold_position)

static func restore_enemy_to_vertical(unfold_position: Vector2, profile: RoomLaneProfile) -> Vector2:
	return profile.get_enemy_restore_position(unfold_position)
