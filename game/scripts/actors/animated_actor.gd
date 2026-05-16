extends Node2D
class_name AnimatedActor

signal hit_start(payload: Dictionary)
signal hit_end(payload: Dictionary)
signal spawn_fx(name: StringName, position: Vector2)
signal footstep()
signal recoverable()
signal anim_finished(name: StringName)

const DEFAULT_ATTACK_EVENTS := {
	&"sword-attack-1": {
		2: [&"hit_start", &"spawn_fx"],
		4: [&"hit_end", &"recoverable"],
	},
	&"sword-attack-2": {
		2: [&"hit_start", &"spawn_fx"],
		4: [&"hit_end", &"recoverable"],
	},
}

@export var sprite_frames: SpriteFrames
@export_file("*.png") var atlas_path := "res://game/art/sprites/player_saint/spritesheet.png"
@export_file("*.json") var manifest_path := "res://game/art/sprites/player_saint/manifest.json"
@export var default_state := &"idle"
@export var action_prefixes: Array[StringName] = [&"sword-attack"]
@export var weapon_socket_offset := Vector2(28.0, -28.0)

@onready var sprite: AnimatedSprite2D = get_node_or_null("Sprite") as AnimatedSprite2D

var facing_direction := 1
var current_action := &""
var recovery_window := false

func _ready() -> void:
	_ensure_sprite()
	if sprite_frames == null:
		sprite_frames = _build_sprite_frames_from_manifest()
	if sprite_frames != null:
		sprite.sprite_frames = sprite_frames
	if sprite.sprite_frames != null and sprite.sprite_frames.has_animation(default_state):
		sprite.play(default_state)
	else:
		_ensure_fallback_visual()
	sprite.frame_changed.connect(_on_frame_changed)
	sprite.animation_finished.connect(_on_animation_finished)

func play_state(state_name: StringName) -> void:
	_ensure_sprite()
	if is_action_playing():
		return
	var resolved := _resolve_state(state_name)
	if not _can_play(resolved):
		return
	if sprite.animation == resolved and sprite.is_playing():
		return
	current_action = &""
	recovery_window = false
	sprite.play(resolved)

func play_attack(attack_name: StringName) -> void:
	_ensure_sprite()
	var resolved := _resolve_state(attack_name)
	if not _can_play(resolved):
		return
	current_action = resolved
	recovery_window = false
	sprite.play(resolved)
	_on_frame_changed()

func set_facing(direction: int) -> void:
	if direction == 0:
		return
	facing_direction = 1 if direction > 0 else -1
	scale.x = absf(scale.x) * float(facing_direction)

func get_weapon_socket_global() -> Vector2:
	var local_socket := Vector2(weapon_socket_offset.x * float(facing_direction), weapon_socket_offset.y)
	return to_global(local_socket)

func is_in_recovery_window() -> bool:
	return recovery_window

func is_action_playing() -> bool:
	return current_action != &"" and sprite != null and sprite.is_playing()

func _ensure_sprite() -> void:
	if sprite != null:
		return
	sprite = AnimatedSprite2D.new()
	sprite.name = "Sprite"
	sprite.centered = true
	add_child(sprite)

func _ensure_fallback_visual() -> void:
	if get_node_or_null("FallbackVisual") != null:
		return
	var fallback := ColorRect.new()
	fallback.name = "FallbackVisual"
	fallback.offset_left = -14.0
	fallback.offset_top = -44.0
	fallback.offset_right = 14.0
	fallback.offset_bottom = 0.0
	fallback.color = Color(0.85, 0.92, 1.0, 1.0)
	add_child(fallback)

func _build_sprite_frames_from_manifest() -> SpriteFrames:
	if not FileAccess.file_exists(atlas_path) or not FileAccess.file_exists(manifest_path):
		return null
	var image := Image.load_from_file(atlas_path)
	if image == null or image.is_empty():
		return null
	var atlas_texture := ImageTexture.create_from_image(image)
	var manifest_text := FileAccess.get_file_as_string(manifest_path)
	var manifest = JSON.parse_string(manifest_text)
	if not (manifest is Dictionary):
		return null
	var frames := SpriteFrames.new()
	if frames.has_animation(&"default"):
		frames.remove_animation(&"default")
	var cell_size: Array = manifest.get("cell_size", [128, 128])
	var cell_w := int(cell_size[0])
	var cell_h := int(cell_size[1])
	var base_fps := float(manifest.get("frame_rate", 12))
	for row in manifest.get("rows", []):
		if not (row is Dictionary):
			continue
		var animation_name := StringName(row.get("name", ""))
		if String(animation_name).is_empty():
			continue
		frames.add_animation(animation_name)
		var row_fps := 24.0 if animation_name in [&"dash", &"sword-attack-1", &"sword-attack-2"] else base_fps
		frames.set_animation_speed(animation_name, row_fps)
		frames.set_animation_loop(animation_name, animation_name in [&"idle", &"run-right", &"run-left", &"fall", &"unfold-loop"])
		var atlas_row := int(row.get("atlas_row", 0))
		var frame_count := int(row.get("frame_count", 0))
		for col in range(frame_count):
			var frame_texture := AtlasTexture.new()
			frame_texture.atlas = atlas_texture
			frame_texture.region = Rect2(col * cell_w, atlas_row * cell_h, cell_w, cell_h)
			frames.add_frame(animation_name, frame_texture)
	return frames

func _resolve_state(state_name: StringName) -> StringName:
	if state_name == &"run":
		return &"run-right" if facing_direction >= 0 else &"run-left"
	return state_name

func _can_play(animation_name: StringName) -> bool:
	return sprite != null and sprite.sprite_frames != null and sprite.sprite_frames.has_animation(animation_name)

func _on_frame_changed() -> void:
	if sprite == null or current_action == &"":
		return
	var action_events: Dictionary = DEFAULT_ATTACK_EVENTS.get(current_action, {})
	var events: Array = action_events.get(sprite.frame, [])
	for event_name in events:
		_emit_event(event_name)

func _emit_event(event_name: StringName) -> void:
	var payload := {
		"animation": current_action,
		"frame": sprite.frame,
		"facing": facing_direction,
	}
	match event_name:
		&"hit_start":
			hit_start.emit(payload)
		&"hit_end":
			hit_end.emit(payload)
		&"spawn_fx":
			spawn_fx.emit(&"sword_arc", get_weapon_socket_global())
		&"footstep":
			footstep.emit()
		&"recoverable":
			recovery_window = true
			recoverable.emit()

func _on_animation_finished() -> void:
	var finished := current_action if current_action != &"" else sprite.animation
	current_action = &""
	recovery_window = false
	anim_finished.emit(finished)
	if _can_play(default_state):
		sprite.play(default_state)
