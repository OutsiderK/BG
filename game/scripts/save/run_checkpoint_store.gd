extends RefCounted
class_name RunCheckpointStore

const CHECKPOINT_PATH := "user://run_checkpoint_v0.json"

static func save_run_checkpoint(snapshot: Dictionary) -> void:
	var file := FileAccess.open(CHECKPOINT_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("Run checkpoint placeholder could not open %s" % CHECKPOINT_PATH)
		return
	file.store_string(JSON.stringify(snapshot, "\t"))

static func load_run_checkpoint() -> Dictionary:
	if not FileAccess.file_exists(CHECKPOINT_PATH):
		return {}
	var file := FileAccess.open(CHECKPOINT_PATH, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	return parsed
