extends SceneTree

const HUD_SCENE := "res://game/scenes/ui/HUD.tscn"

var _failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var run_state := root.get_node_or_null("RunState")
	var balance := root.get_node_or_null("Balance")
	if run_state == null or balance == null:
		_fail("Failed to find required autoloads.")
		_finish()
		return

	run_state.reset_run()

	var packed := load(HUD_SCENE) as PackedScene
	if packed == null:
		_fail("Failed to load HUD scene: %s" % HUD_SCENE)
		_finish()
		return

	var hud := packed.instantiate()
	root.add_child(hud)
	await process_frame

	var heat_label := hud.get_node_or_null("%HeatLabel") as Label
	var heat_hint_label := hud.get_node_or_null("%HeatHintLabel") as Label
	var risk_label := hud.get_node_or_null("%RiskLabel") as Label
	var weapon_label := hud.get_node_or_null("%WeaponLabel") as Label
	var weapon_icon := hud.get_node_or_null("%WeaponIcon") as TextureRect
	var cooldown_bar := hud.get_node_or_null("%WeaponCooldownBar") as ProgressBar
	var cooldown_label := hud.get_node_or_null("%WeaponCooldownLabel") as Label

	_assert(heat_label != null, "HUD exposes heat label.")
	_assert(heat_hint_label != null, "HUD exposes heat hint label.")
	_assert(risk_label != null, "HUD exposes anchor/risk label.")
	_assert(weapon_label != null, "HUD exposes weapon label.")
	_assert(weapon_icon != null, "HUD exposes weapon icon.")
	_assert(cooldown_bar != null, "HUD exposes weapon cooldown bar.")
	_assert(cooldown_label != null, "HUD exposes weapon cooldown label.")
	if heat_label == null or heat_hint_label == null or risk_label == null or weapon_label == null or weapon_icon == null or cooldown_bar == null or cooldown_label == null:
		_cleanup(hud)
		_finish()
		return

	_assert(weapon_icon.texture != null, "Weapon icon has a texture.")
	_assert(weapon_label.text.contains("剑"), "Weapon label names the sword.")
	_assert(cooldown_label.text.contains("就绪"), "Weapon cooldown starts ready.")

	run_state.add_heat(balance.HEAT_TRIGGER_THRESHOLD)
	await process_frame
	_assert(heat_label.text.contains("100"), "Heat label refreshes to full heat.")
	_assert(heat_hint_label.text.contains("[1] 展开"), "Full heat shows clear unfold prompt.")

	var previous_risk := risk_label.text
	run_state.add_risk_delta(0.08)
	await process_frame
	_assert(risk_label.text != previous_risk and risk_label.text.contains("锚率"), "Anchor/risk label refreshes after risk changes.")

	hud.call("trigger_weapon_cooldown_feedback")
	await process_frame
	_assert(cooldown_bar.value < cooldown_bar.max_value, "Weapon cooldown bar drops during cooldown.")
	_assert(cooldown_label.text.contains("冷却"), "Weapon cooldown label reports cooling down.")
	await create_timer(0.7, true, false, true).timeout
	_assert(cooldown_label.text.contains("就绪"), "Weapon cooldown returns to ready.")

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
		printerr("HUD weapon smoke failed with %d failure(s)." % _failures.size())
		quit(1)
		return
	print("HUD weapon smoke passed.")
	quit(0)
