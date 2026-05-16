extends SceneTree

const HUD_SCENE := "res://game/scenes/ui/HUD.tscn"

var _failures: Array[String] = []

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
	unfold_manager.set_unfold_blocked(false)

	var packed := load(HUD_SCENE) as PackedScene
	if packed == null:
		_fail("Failed to load HUD scene: %s" % HUD_SCENE)
		_finish()
		return

	var hud := packed.instantiate()
	root.add_child(hud)
	await process_frame

	var mode_label := hud.get_node_or_null("%UnfoldModeLabel") as Label
	var detail_label := hud.get_node_or_null("%UnfoldDetailLabel") as Label
	var heat_hint_label := hud.get_node_or_null("%HeatHintLabel") as Label
	var risk_label := hud.get_node_or_null("%RiskLabel") as Label
	var corruption_hint_label := hud.get_node_or_null("%CorruptionHintLabel") as Label
	_assert(mode_label != null, "HUD exposes unfold mode label.")
	_assert(detail_label != null, "HUD exposes unfold detail label.")
	_assert(heat_hint_label != null, "HUD exposes heat hint label.")
	_assert(risk_label != null, "HUD exposes anchor/risk label.")
	_assert(corruption_hint_label != null, "HUD exposes corruption hint label.")
	if mode_label == null or detail_label == null or heat_hint_label == null or risk_label == null or corruption_hint_label == null:
		_cleanup(hud)
		_finish()
		return

	_assert(mode_label.text.contains("纵平面"), "HUD starts in vertical mode.")
	_assert(risk_label.text.contains("锚率"), "HUD shows anchor rate.")

	run_state.add_heat(balance.HEAT_TRIGGER_THRESHOLD)
	await process_frame
	_assert(heat_hint_label.text.contains("按 1 展开"), "Full heat shows unfold prompt.")
	_assert(detail_label.text.contains("就绪"), "Full heat marks the unfold resource ready.")

	var started: bool = unfold_manager.start_unfold()
	_assert(started, "Unfold starts from HUD smoke setup.")
	await create_timer(balance.UNFOLD_TRANSITION_IN + 0.1, true, false, true).timeout
	_assert(mode_label.text.contains("展开中"), "HUD shows unfolded mode after transition.")
	_assert(heat_hint_label.text.contains("倒计"), "Unfolded heat hint uses countdown copy.")

	unfold_manager.end_unfold("early")
	await process_frame
	_assert(mode_label.text.contains("冷却"), "HUD shows cooldown after ending unfold.")
	_assert(heat_hint_label.text.contains("禁展冷却"), "Cooldown shows remaining locked time.")

	run_state.add_corruption(balance.CORRUPTION_COLLAPSE)
	await process_frame
	_assert(corruption_hint_label.text.contains("侵蚀"), "Corruption changes show a risk hint.")

	_cleanup(hud)
	_finish()

func _cleanup(hud: Node) -> void:
	if hud != null:
		root.remove_child(hud)
		hud.queue_free()
	Engine.time_scale = 1.0

func _assert(condition: bool, message: String) -> void:
	if not condition:
		_fail(message)

func _fail(message: String) -> void:
	_failures.append(message)
	printerr(message)

func _finish() -> void:
	if not _failures.is_empty():
		printerr("HUD unfold smoke failed with %d failure(s)." % _failures.size())
		quit(1)
		return
	print("HUD unfold smoke passed.")
	quit(0)
