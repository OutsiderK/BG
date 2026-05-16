extends SceneTree

const PLAYER_SCENE := "res://game/scenes/player/Player.tscn"
const FX_NODE_NAME := "SwordArcFx"

var _failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var run_state := root.get_node_or_null("RunState")
	var unfold_manager := root.get_node_or_null("UnfoldManager")
	if run_state != null:
		run_state.reset_run()
	if unfold_manager != null:
		unfold_manager.set_gameplay_blocked(false)

	var packed := load(PLAYER_SCENE) as PackedScene
	if packed == null:
		_fail("Failed to load player scene: %s" % PLAYER_SCENE)
		_finish()
		return

	var player := packed.instantiate()
	root.add_child(player)
	player.global_position = Vector2.ZERO
	await physics_frame

	var actor := player.get_node_or_null("AnimatedActor")
	_assert(actor != null, "Player has AnimatedActor.")

	var initial_fx_count := _count_fx_nodes(root)
	_assert(initial_fx_count == 0, "No SwordArcFx exists before attack.")

	player.facing = Vector2.RIGHT
	player.call("_try_attack")
	await physics_frame

	actor.sprite.frame = 2
	await physics_frame
	await process_frame

	var fx_count_after_event := _count_fx_nodes(root)
	_assert(fx_count_after_event >= 1, "spawn_fx event creates a SwordArcFx node.")

	# Let the FX age out (lifetime is 0.10-0.18 seconds; wait beyond 0.3s).
	var elapsed := 0.0
	while elapsed < 0.4:
		await process_frame
		elapsed += root.get_process_delta_time()

	var fx_count_after_lifetime := _count_fx_nodes(root)
	_assert(fx_count_after_lifetime == 0, "SwordArcFx is freed after its lifetime (no orphans).")

	# Trigger again to confirm repeated attacks don't leak nodes.
	if actor.has_method("play_attack"):
		actor.call("play_attack", &"sword-attack-1")
	await physics_frame
	actor.sprite.frame = 2
	await physics_frame
	await process_frame
	var fx_count_second := _count_fx_nodes(root)
	_assert(fx_count_second >= 1, "Second attack also spawns a SwordArcFx.")

	elapsed = 0.0
	while elapsed < 0.4:
		await process_frame
		elapsed += root.get_process_delta_time()
	_assert(_count_fx_nodes(root) == 0, "Repeated attacks do not leak SwordArcFx nodes.")

	root.remove_child(player)
	player.queue_free()
	await process_frame
	if unfold_manager != null:
		unfold_manager.set_gameplay_blocked(false)
	_finish()

func _count_fx_nodes(node: Node) -> int:
	var count := 0
	for child in node.get_children():
		var script: Script = child.get_script() as Script
		if script != null and String(script.resource_path).ends_with("sword_arc_fx.gd"):
			count += 1
		count += _count_fx_nodes(child)
	return count

func _assert(condition: bool, message: String) -> void:
	if not condition:
		_fail(message)

func _fail(message: String) -> void:
	_failures.append(message)
	printerr(message)

func _finish() -> void:
	if not _failures.is_empty():
		printerr("Sword FX smoke failed with %d failure(s)." % _failures.size())
		quit(1)
		return
	print("Sword FX smoke passed.")
	quit(0)
