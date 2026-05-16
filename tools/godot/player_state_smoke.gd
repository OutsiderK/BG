extends SceneTree

const PLAYER_SCENE := "res://game/scenes/player/Player.tscn"

var _failures: Array[String] = []
var _damaged_count := 0
var _died_count := 0

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

	var packed := load(PLAYER_SCENE) as PackedScene
	if packed == null:
		_fail("Failed to load player scene: %s" % PLAYER_SCENE)
		_finish()
		return

	var player := packed.instantiate()
	root.add_child(player)
	await physics_frame

	var visual := player.get_node_or_null("ColorRect") as ColorRect
	_assert(visual != null, "Player visual ColorRect is present.")
	var base_color := visual.color if visual != null else Color.WHITE

	player.damaged.connect(func(_amount: int) -> void:
		_damaged_count += 1
	)
	player.died.connect(func() -> void:
		_died_count += 1
	)

	player.facing = Vector2.RIGHT
	player.velocity = Vector2(120.0, 0.0)
	var did_damage: bool = player.apply_damage(1)
	_assert(did_damage, "First damage is applied.")
	_assert(player.hp == player.max_hp - 1, "Damage reduces player HP.")
	_assert(player.hit_invulnerable_remaining > 0.0, "Damage starts hit invulnerability.")
	_assert(_damaged_count == 1, "Damage signal is emitted once.")
	_assert(player.velocity.x < 0.0, "Damage interrupts velocity with knockback.")
	if visual != null:
		_assert(visual.color != base_color, "Hit invulnerability changes the player visual.")

	var hp_after_first_hit: int = player.hp
	var ignored_during_invulnerability: bool = player.apply_damage(1)
	_assert(not ignored_during_invulnerability, "Hit invulnerability rejects repeated damage.")
	_assert(player.hp == hp_after_first_hit, "Ignored damage does not reduce HP.")

	player.hit_invulnerable_remaining = 0.0
	var did_kill: bool = player.apply_damage(player.max_hp)
	_assert(did_kill, "Lethal damage is applied.")
	_assert(player.dead, "Lethal damage marks player dead.")
	_assert(player.hp == 0, "Lethal damage clamps HP to zero.")
	_assert(_died_count == 1, "Death signal is emitted once.")
	_assert(player.velocity == Vector2.ZERO, "Death clears velocity.")
	if visual != null:
		_assert(visual.color == player.death_tint, "Death applies the death tint.")

	run_state.add_heat(balance.HEAT_TRIGGER_THRESHOLD)
	var unfold_started_after_death: bool = unfold_manager.request_toggle_unfold()
	_assert(not unfold_started_after_death, "Death blocks unfold requests.")

	Input.action_press("move_right")
	Input.action_press("move_up")
	Input.action_press("dash")
	Input.action_press("attack")
	Input.action_press("unfold")
	await physics_frame
	Input.action_release("move_right")
	Input.action_release("move_up")
	Input.action_release("dash")
	Input.action_release("attack")
	Input.action_release("unfold")

	var sword_attack := player.get_node_or_null("SwordAttack")
	_assert(player.velocity == Vector2.ZERO, "Death locks movement and jump input.")
	_assert(player.dash_remaining == 0.0, "Death locks dash input.")
	_assert(sword_attack == null or not sword_attack.is_attacking(), "Death locks attack input.")
	_assert(not unfold_manager.is_unfolded() and not unfold_manager.is_transition(), "Death locks unfold input.")

	root.remove_child(player)
	player.queue_free()
	await process_frame
	unfold_manager.set_gameplay_blocked(false)
	_finish()

func _assert(condition: bool, message: String) -> void:
	if not condition:
		_fail(message)

func _fail(message: String) -> void:
	_failures.append(message)
	printerr(message)

func _finish() -> void:
	if not _failures.is_empty():
		printerr("Player state smoke failed with %d failure(s)." % _failures.size())
		quit(1)
		return
	print("Player state smoke passed.")
	quit(0)
