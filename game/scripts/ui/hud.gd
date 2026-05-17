extends CanvasLayer

const RISK_UP_COLOR := Color(1.0, 0.25, 0.2)
const RISK_DOWN_COLOR := Color(0.35, 0.65, 1.0)
const HEAT_READY_COLOR := Color(1.0, 0.82, 0.25)
const HEAT_COUNTDOWN_COLOR := Color(0.45, 0.9, 1.0)
const HEAT_LOCKED_COLOR := Color(0.85, 0.28, 0.22)
const HEAT_IDLE_COLOR := Color.WHITE
const HUD_TEXT_COLOR := Color(0.92, 0.99, 1.0)
const WEAPON_READY_COLOR := Color(0.96, 0.74, 0.28)
const WEAPON_COOLDOWN_COLOR := Color(0.58, 0.95, 1.0)
const WEAPON_RISK_COLOR := Color(0.9, 0.18, 0.45)
const SWORD_CONFIG_PATH := "res://game/data/weapons/sword_baseline.cfg"
const SWORD_ICON_PATH := "res://game/art/sprites/weapons/sword_icon.png"
const WEAPON_DISPLAY_NAMES := {
	"sword": "剑",
	"sword_placeholder": "剑",
}
const CORRUPTION_COLORS := {
	"white": Color(0.92, 0.92, 0.86),
	"yellow": Color(1.0, 0.82, 0.25),
	"red": Color(1.0, 0.22, 0.18),
}

@onready var health_label: Label = %HealthLabel
@onready var health_bar: ProgressBar = %HealthBar
@onready var heat_label: Label = %HeatLabel
@onready var heat_bar: ProgressBar = %HeatBar
@onready var heat_hint_label: Label = %HeatHintLabel
@onready var unfold_mode_label: Label = %UnfoldModeLabel
@onready var unfold_detail_label: Label = %UnfoldDetailLabel
@onready var grey_coin_label: Label = %GreyCoinLabel
@onready var risk_label: Label = %RiskLabel
@onready var risk_hint_label: Label = %RiskHintLabel
@onready var corruption_label: Label = %CorruptionLabel
@onready var corruption_hint_label: Label = %CorruptionHintLabel
@onready var weapon_label: Label = %WeaponLabel
@onready var weapon_icon: TextureRect = %WeaponIcon
@onready var weapon_cooldown_bar: ProgressBar = %WeaponCooldownBar
@onready var weapon_cooldown_label: Label = %WeaponCooldownLabel
@onready var weapon_ready_pip: ColorRect = %WeaponReadyPip
@onready var dash_label: Label = %DashLabel
@onready var save_label: Label = %SaveLabel
@onready var death_panel: Panel = %DeathPanel
@onready var death_title_label: Label = %DeathTitleLabel
@onready var death_body_label: Label = %DeathBodyLabel
@onready var death_detail_label: Label = %DeathDetailLabel

var _last_risk := -1.0
var _last_corruption := -1.0
var _last_transition_kind := ""
var _last_unfold_end_reason := ""
var _risk_tween: Tween
var _corruption_tween: Tween
var _heat_ready_tween: Tween
var _weapon_tween: Tween
var _weapon_node: Node
var _weapon_cooldown_duration := 0.5
var _weapon_cooldown_remaining := 0.0
var _weapon_damage := 5
var _weapon_reach := 38.0

func _ready() -> void:
	_load_weapon_config()
	_load_weapon_icon()
	RunState.health_changed.connect(_on_health_changed)
	RunState.heat_changed.connect(_on_heat_changed)
	RunState.grey_coins_changed.connect(_on_grey_coins_changed)
	RunState.risk_changed.connect(_on_risk_changed)
	RunState.corruption_changed.connect(_on_corruption_changed)
	RunState.death_resolved.connect(_on_death_resolved)
	RunState.checkpoint_saved.connect(_on_checkpoint_saved)
	UnfoldManager.unfold_transition_started.connect(_on_unfold_transition_started)
	UnfoldManager.unfold_mode_changed.connect(_on_unfold_mode_changed)
	UnfoldManager.unfold_ended.connect(_on_unfold_ended)
	UnfoldManager.cooldown_started.connect(_on_cooldown_started)
	death_panel.visible = false
	_on_health_changed(RunState.hp, RunState.hp_max)
	_on_heat_changed(RunState.heat, RunState.heat_max)
	_on_grey_coins_changed(RunState.grey_coins)
	_on_risk_changed(RunState.get_permadeath_probability())
	_on_corruption_changed(RunState.corruption, RunState.get_corruption_tier())
	_update_unfold_status()
	_update_equipment_placeholders()
	_update_weapon_cooldown(0.0)

func _process(delta: float) -> void:
	_update_unfold_status()
	_update_weapon_cooldown(delta)

func _on_health_changed(current: int, maximum: int) -> void:
	health_label.text = "血量 %d / %d" % [current, maximum]
	health_bar.max_value = maximum
	health_bar.value = current

func _on_heat_changed(current: float, maximum: float) -> void:
	heat_label.text = "圣痕 %.0f / %.0f" % [current, maximum]
	heat_bar.max_value = maximum
	heat_bar.value = current
	_update_unfold_status()

func _on_grey_coins_changed(current: int) -> void:
	grey_coin_label.text = "灰币 %d" % current

func _on_risk_changed(current_probability: float) -> void:
	var anchor_rate := (1.0 - current_probability) * 100.0
	risk_label.text = "锚率 %.1f%% / 彻死 %.1f%%" % [anchor_rate, current_probability * 100.0]
	if _last_risk >= 0.0:
		var delta := current_probability - _last_risk
		if absf(delta) > 0.0001:
			_play_risk_feedback(delta)
	_last_risk = current_probability

func _on_corruption_changed(current: float, tier: String) -> void:
	var tier_label := "安全"
	if tier == "yellow":
		tier_label = "警戒"
	elif tier == "red":
		tier_label = "危险"
	corruption_label.text = "侵蚀 %s %.1f" % [tier_label, current]
	corruption_label.modulate = CORRUPTION_COLORS.get(tier, Color.WHITE)
	if _last_corruption >= 0.0:
		var delta := current - _last_corruption
		if absf(delta) > 0.0001:
			_play_corruption_feedback(delta, tier)
	_last_corruption = current

func _on_death_resolved(result: Dictionary) -> void:
	var permadeath := bool(result.get("permadeath", false))
	var probability := float(result.get("probability", 0.0))
	death_panel.visible = true
	death_title_label.text = "彻底死亡" if permadeath else "普通重塑"
	death_body_label.text = "本次判定概率 %.1f%%，结果：%s" % [probability * 100.0, result.get("result_label", "未知")]
	death_detail_label.text = "保留：%s\n失去：%s" % [
		_join_values(result.get("kept", [])),
		_join_values(result.get("lost", [])),
	]

func _on_checkpoint_saved(snapshot: Dictionary) -> void:
	save_label.text = "存档 房间 %d 已记录" % int(snapshot.get("room_index", 1))

func _update_equipment_placeholders() -> void:
	var weapon_id := RunState.current_weapon_id
	var display_name: String = WEAPON_DISPLAY_NAMES.get(weapon_id, weapon_id)
	weapon_label.text = "当前武器 %s  伤害 %d / 距离 %.0f" % [display_name, _weapon_damage, _weapon_reach]
	dash_label.text = "冲刺 %d 次 / %.1fs" % [RunState.dash_charges, RunState.dash_cooldown]
	save_label.text = "存档 待机"

func _on_unfold_transition_started(kind: String) -> void:
	_last_transition_kind = kind
	_update_unfold_status()

func _on_unfold_mode_changed(_mode: int, _mode_name: String) -> void:
	_update_unfold_status()

func _on_unfold_ended(reason: String) -> void:
	_last_unfold_end_reason = reason
	_update_unfold_status()

func _on_cooldown_started(_duration: float) -> void:
	_update_unfold_status()

func _update_unfold_status() -> void:
	var heat_ready := RunState.heat >= Balance.HEAT_TRIGGER_THRESHOLD
	if UnfoldManager.is_transition():
		var transition_label := "坍缩过渡" if _last_transition_kind == "collapse" else "展开过渡"
		unfold_mode_label.text = "模式 %s" % transition_label
		unfold_detail_label.text = "相位切换 %.1fs" % UnfoldManager.transition_remaining
		heat_hint_label.text = "%s %.1fs" % [transition_label, UnfoldManager.transition_remaining]
		_set_heat_tint(HEAT_LOCKED_COLOR if _last_transition_kind == "collapse" else HEAT_READY_COLOR)
		return
	if UnfoldManager.is_unfolded():
		var remaining_seconds := RunState.heat / maxf(Balance.UNFOLD_CONSUME_RATE, 0.001)
		unfold_mode_label.text = "模式 展开中"
		unfold_detail_label.text = "热度倒计 %.1fs" % remaining_seconds
		heat_hint_label.text = "展开倒计 %.1fs - 再按 1 提前坍缩" % remaining_seconds
		_set_heat_tint(HEAT_COUNTDOWN_COLOR)
		return
	if UnfoldManager.is_cooldown():
		var cooldown_label := "坍缩冷却" if _last_unfold_end_reason == "collapse" else "禁展冷却"
		unfold_mode_label.text = "模式 %s" % cooldown_label
		unfold_detail_label.text = "剩余 %.1fs" % UnfoldManager.cooldown_remaining
		heat_hint_label.text = "禁展冷却 %.1fs" % UnfoldManager.cooldown_remaining
		_set_heat_tint(HEAT_LOCKED_COLOR)
		return
	unfold_mode_label.text = "模式 纵平面"
	if heat_ready:
		unfold_detail_label.text = "圣痕就绪"
		heat_hint_label.text = "圣痕满载 - 按 1 展开  [1] 展开"
		_set_heat_tint(HEAT_READY_COLOR)
		_play_heat_ready_feedback()
	else:
		var needed := maxf(0.0, Balance.HEAT_TRIGGER_THRESHOLD - RunState.heat)
		unfold_detail_label.text = "距展开 %.0f" % needed
		heat_hint_label.text = "圣痕积累中"
		_set_heat_tint(HEAT_IDLE_COLOR)

func _set_heat_tint(color: Color) -> void:
	heat_label.modulate = color
	heat_bar.modulate = color
	heat_hint_label.modulate = color
	unfold_detail_label.modulate = color

func _load_weapon_config() -> void:
	var config := ConfigFile.new()
	var error := config.load(SWORD_CONFIG_PATH)
	if error != OK:
		push_warning("HUD could not read sword config: %s" % SWORD_CONFIG_PATH)
		return
	var attacks_per_second := float(config.get_value("weapon", "attacks_per_second", 2.0))
	_weapon_cooldown_duration = 1.0 / maxf(attacks_per_second, 0.01)
	_weapon_damage = int(config.get_value("weapon", "damage", _weapon_damage))
	_weapon_reach = float(config.get_value("weapon", "reach", _weapon_reach))

func _load_weapon_icon() -> void:
	if weapon_icon.texture != null:
		return
	var image := Image.load_from_file(SWORD_ICON_PATH)
	if image == null or image.is_empty():
		return
	weapon_icon.texture = ImageTexture.create_from_image(image)

func _update_weapon_cooldown(delta: float) -> void:
	_resolve_weapon_node()
	var cooldown_remaining := _read_weapon_cooldown_remaining()
	if _weapon_node == null:
		if Input.is_action_just_pressed("attack") and _weapon_cooldown_remaining <= 0.0:
			trigger_weapon_cooldown_feedback()
		_weapon_cooldown_remaining = maxf(0.0, _weapon_cooldown_remaining - delta)
		cooldown_remaining = _weapon_cooldown_remaining
	var cooldown_ratio := clampf(cooldown_remaining / maxf(_weapon_cooldown_duration, 0.001), 0.0, 1.0)
	var ready_ratio := 1.0 - cooldown_ratio
	weapon_cooldown_bar.value = ready_ratio
	if cooldown_remaining > 0.01:
		weapon_cooldown_label.text = "冷却 %.1fs" % cooldown_remaining
		weapon_cooldown_label.modulate = WEAPON_COOLDOWN_COLOR
		weapon_ready_pip.color = WEAPON_COOLDOWN_COLOR.darkened(0.24)
		weapon_icon.modulate = Color(0.72, 0.94, 1.0, 0.78)
	else:
		weapon_cooldown_label.text = "剑刃就绪"
		weapon_cooldown_label.modulate = WEAPON_READY_COLOR
		weapon_ready_pip.color = WEAPON_READY_COLOR
		weapon_icon.modulate = Color.WHITE

func trigger_weapon_cooldown_feedback() -> void:
	_weapon_cooldown_remaining = _weapon_cooldown_duration
	_play_weapon_pulse()

func _resolve_weapon_node() -> void:
	if is_instance_valid(_weapon_node):
		return
	_weapon_node = null
	var tree := get_tree()
	if tree == null:
		return
	for player in tree.get_nodes_in_group("player"):
		var sword := player.get_node_or_null("SwordAttack")
		if sword != null:
			_bind_weapon_node(sword)
			return
	var current_scene := tree.current_scene
	if current_scene == null:
		return
	var player_node := current_scene.find_child("Player", true, false)
	if player_node == null:
		return
	var fallback_sword := player_node.get_node_or_null("SwordAttack")
	if fallback_sword != null:
		_bind_weapon_node(fallback_sword)

func _bind_weapon_node(sword: Node) -> void:
	_weapon_node = sword
	if sword.has_signal("attack_started"):
		var started := Callable(self, "_on_weapon_attack_started")
		if not sword.is_connected("attack_started", started):
			sword.connect("attack_started", started)

func _read_weapon_cooldown_remaining() -> float:
	if _weapon_node == null or not is_instance_valid(_weapon_node):
		_weapon_node = null
		return 0.0
	if not _weapon_node.has_method("get_cooldown_remaining"):
		return 0.0
	return float(_weapon_node.call("get_cooldown_remaining"))

func _on_weapon_attack_started() -> void:
	_play_weapon_pulse()

func _play_heat_ready_feedback() -> void:
	if is_instance_valid(_heat_ready_tween) and _heat_ready_tween.is_running():
		return
	heat_hint_label.pivot_offset = heat_hint_label.size * 0.5
	_heat_ready_tween = create_tween()
	_heat_ready_tween.tween_property(heat_hint_label, "scale", Vector2.ONE * 1.08, 0.22)
	_heat_ready_tween.tween_property(heat_hint_label, "scale", Vector2.ONE, 0.28)

func _play_weapon_pulse() -> void:
	weapon_icon.pivot_offset = weapon_icon.size * 0.5
	weapon_ready_pip.color = WEAPON_RISK_COLOR
	if is_instance_valid(_weapon_tween):
		_weapon_tween.kill()
	_weapon_tween = create_tween()
	_weapon_tween.tween_property(weapon_icon, "scale", Vector2.ONE * 1.12, 0.08)
	_weapon_tween.tween_property(weapon_icon, "scale", Vector2.ONE, 0.18)

func _play_risk_feedback(delta: float) -> void:
	var color := RISK_UP_COLOR if delta > 0.0 else RISK_DOWN_COLOR
	risk_hint_label.text = "锚率 %+.1f%%" % [-delta * 100.0]
	risk_hint_label.modulate = color
	risk_label.pivot_offset = risk_label.size * 0.5
	risk_label.scale = Vector2.ONE * 1.24
	risk_label.modulate = color
	if is_instance_valid(_risk_tween):
		_risk_tween.kill()
	_risk_tween = create_tween()
	_risk_tween.tween_property(risk_label, "scale", Vector2.ONE, 0.32)
	_risk_tween.parallel().tween_property(risk_label, "modulate", Color.WHITE, 0.32)
	_risk_tween.parallel().tween_property(risk_hint_label, "modulate:a", 0.0, 0.85)

func _play_corruption_feedback(delta: float, tier: String) -> void:
	var color: Color = CORRUPTION_COLORS.get(tier, RISK_UP_COLOR)
	if delta < 0.0:
		color = RISK_DOWN_COLOR
	corruption_hint_label.text = "%+.1f 侵蚀" % delta
	corruption_hint_label.modulate = color
	corruption_label.pivot_offset = corruption_label.size * 0.5
	corruption_label.scale = Vector2.ONE * 1.18
	if is_instance_valid(_corruption_tween):
		_corruption_tween.kill()
	_corruption_tween = create_tween()
	_corruption_tween.tween_property(corruption_label, "scale", Vector2.ONE, 0.3)
	_corruption_tween.parallel().tween_property(corruption_hint_label, "modulate:a", 0.0, 0.85)

func _join_values(values: Variant) -> String:
	if typeof(values) != TYPE_ARRAY or values.is_empty():
		return "无"
	var parts: Array[String] = []
	for value in values:
		parts.append(str(value))
	return "、".join(parts)
