extends Resource
class_name RoomLaneProfile

@export var lane_offsets: Array[float] = [-160.0, 0.0, 160.0]
@export var fallback_vertical_y := 480.0

func get_lane_offset(index: int) -> float:
	if lane_offsets.is_empty():
		return 0.0
	return lane_offsets[wrapi(index, 0, lane_offsets.size())]

