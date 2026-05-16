extends SceneTree

const ACTOR_SCRIPT := preload("res://game/scripts/actors/animated_actor.gd")

var _failures: Array[String] = []
var _hit_start_count := 0
var _hit_end_count := 0
var _spawn_fx_count := 0
var _recoverable_count := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var actor := ACTOR_SCRIPT.new()
	root.add_child(actor)
	await process_frame

	_assert(actor.sprite != null, "AnimatedActor creates or finds an AnimatedSprite2D.")
	_assert(actor.sprite.sprite_frames != null, "AnimatedActor builds player SpriteFrames.")
	_assert(actor.sprite.sprite_frames.has_animation(&"idle"), "SpriteFrames contains idle.")
	_assert(actor.sprite.sprite_frames.has_animation(&"sword-attack-1"), "SpriteFrames contains sword attack.")

	actor.hit_start.connect(func(_payload: Dictionary) -> void:
		_hit_start_count += 1
	)
	actor.hit_end.connect(func(_payload: Dictionary) -> void:
		_hit_end_count += 1
	)
	actor.spawn_fx.connect(func(_name: StringName, _position: Vector2) -> void:
		_spawn_fx_count += 1
	)
	actor.recoverable.connect(func() -> void:
		_recoverable_count += 1
	)

	actor.set_facing(-1)
	_assert(actor.facing_direction == -1, "set_facing stores left facing.")
	_assert(actor.scale.x < 0.0, "set_facing mirrors the actor root.")

	actor.play_state(&"run")
	await process_frame
	_assert(actor.sprite.animation == &"run-left", "play_state(run) resolves left-facing run.")

	actor.set_facing(1)
	actor.play_state(&"run")
	await process_frame
	_assert(actor.sprite.animation == &"run-right", "play_state(run) resolves right-facing run.")

	actor.play_attack(&"sword-attack-1")
	await process_frame
	actor.sprite.frame = 2
	await process_frame
	_assert(_hit_start_count == 1, "Attack frame 2 emits hit_start.")
	_assert(_spawn_fx_count == 1, "Attack frame 2 emits spawn_fx.")

	actor.sprite.frame = 4
	await process_frame
	_assert(_hit_end_count == 1, "Attack frame 4 emits hit_end.")
	_assert(_recoverable_count == 1, "Attack frame 4 emits recoverable.")
	_assert(actor.is_in_recovery_window(), "Recoverable event opens recovery window.")

	root.remove_child(actor)
	actor.queue_free()
	await process_frame
	_finish()

func _assert(condition: bool, message: String) -> void:
	if not condition:
		_fail(message)

func _fail(message: String) -> void:
	_failures.append(message)
	printerr(message)

func _finish() -> void:
	if not _failures.is_empty():
		printerr("AnimatedActor smoke failed with %d failure(s)." % _failures.size())
		quit(1)
		return
	print("AnimatedActor smoke passed.")
	quit(0)
