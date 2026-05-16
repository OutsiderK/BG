extends CanvasLayer

const RISK_UP_COLOR := Color(1.0, 0.25, 0.2)
const RISK_DOWN_COLOR := Color(0.35, 0.65, 1.0)
const CORRUPTION_COLORS := {
	"white": Color(0.92, 0.92, 0.86),
	"yellow": Color(1.0, 0.82, 0.25),
	"red": Color(1.0, 0.22, 0.18),
}

@onready var health_label: Label = %HealthLabel
@onready var health_bar: ProgressBar = %HealthBar
@onready var heat_label: Label = %HeatLabel
@onready var heat_bar: ProgressBar = %HeatBar
@onready var grey_coin_label: Label = %GreyCoinLabel
@onready var risk_label: Label = %RiskLabel
@onready var risk_hint_label: Label = %RiskHintLabel
@onready var corruption_label: Label = %CorruptionLabel
@onready var weapon_label: Label = %WeaponLabel
@onready var dash_label: Label = %DashLabel
@onready var save_label: Label = %SaveLabel
@onready var death_panel: Panel = %DeathPanel
@onready var death_title_label: Label = %DeathTitleLabel
@onready var death_body_label: Label = %DeathBodyLabel
@onready var death_detail_label: Label = %DeathDetailLabel

var _last_risk := -1.0
var _risk_tween: Tween

func _ready() -> void:
	RunState.health_changed.connect(_on_health_changed)
	RunState.heat_changed.connect(_on_heat_changed)
	RunState.grey_coins_changed.connect(_on_grey_coins_changed)
	RunState.risk_changed.connect(_on_risk_changed)
	RunState.corruption_changed.connect(_on_corruption_changed)
	RunState.death_resolved.connect(_on_death_resolved)
	RunState.checkpoint_saved.connect(_on_checkpoint_saved)
	death_panel.visible = false
	_on_health_changed(RunState.hp, RunState.hp_max)
	_on_heat_changed(RunState.heat, RunState.heat_max)
	_on_grey_coins_changed(RunState.grey_coins)
	_on_risk_changed(RunState.get_permadeath_probability())
	_on_corruption_changed(RunState.corruption, RunState.get_corruption_tier())
	_update_equipment_placeholders()

func _on_health_changed(current: int, maximum: int) -> void:
	health_label.text = "血量 %d / %d" % [current, maximum]
	health_bar.max_value = maximum
	health_bar.value = current

func _on_heat_changed(current: float, maximum: float) -> void:
	heat_label.text = "圣痕 %.0f / %.0f" % [current, maximum]
	heat_bar.max_value = maximum
	heat_bar.value = current

func _on_grey_coins_changed(current: int) -> void:
	grey_coin_label.text = "灰币 %d" % current

func _on_risk_changed(current_probability: float) -> void:
	risk_label.text = "彻底死亡 %.1f%%" % [current_probability * 100.0]
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
	weapon_label.text = "武器 %s" % RunState.current_weapon_id
	dash_label.text = "冲刺 %d 次 / %.1fs" % [RunState.dash_charges, RunState.dash_cooldown]
	save_label.text = "存档 待机"

func _play_risk_feedback(delta: float) -> void:
	var color := RISK_UP_COLOR if delta > 0.0 else RISK_DOWN_COLOR
	risk_hint_label.text = "%+.1f%%" % [delta * 100.0]
	risk_hint_label.modulate = color
	risk_label.pivot_offset = risk_label.size * 0.5
	risk_label.scale = Vector2.ONE * 1.18
	risk_label.modulate = color
	if is_instance_valid(_risk_tween):
		_risk_tween.kill()
	_risk_tween = create_tween()
	_risk_tween.tween_property(risk_label, "scale", Vector2.ONE, 0.24)
	_risk_tween.parallel().tween_property(risk_label, "modulate", Color.WHITE, 0.24)
	_risk_tween.parallel().tween_property(risk_hint_label, "modulate:a", 0.0, 0.45)

func _join_values(values: Variant) -> String:
	if typeof(values) != TYPE_ARRAY or values.is_empty():
		return "无"
	var parts: Array[String] = []
	for value in values:
		parts.append(str(value))
	return "、".join(parts)
