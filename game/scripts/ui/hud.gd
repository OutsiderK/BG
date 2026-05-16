extends CanvasLayer

@onready var heat_label: Label = %HeatLabel
@onready var risk_label: Label = %RiskLabel
@onready var corruption_label: Label = %CorruptionLabel

func _ready() -> void:
	RunState.heat_changed.connect(_on_heat_changed)
	RunState.risk_changed.connect(_on_risk_changed)
	RunState.corruption_changed.connect(_on_corruption_changed)
	_on_heat_changed(RunState.heat, RunState.heat_max)
	_on_risk_changed(RunState.get_permadeath_probability())
	_on_corruption_changed(RunState.corruption)

func _on_heat_changed(current: float, maximum: float) -> void:
	heat_label.text = "圣痕 %.0f / %.0f" % [current, maximum]

func _on_risk_changed(current_probability: float) -> void:
	risk_label.text = "彻底死亡 %.1f%%" % [current_probability * 100.0]

func _on_corruption_changed(current: float) -> void:
	corruption_label.text = "侵蚀 %.1f" % current

