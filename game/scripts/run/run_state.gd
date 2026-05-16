extends Node

signal heat_changed(current: float, maximum: float)
signal risk_changed(current_probability: float)
signal corruption_changed(current: float)
signal player_died(permadeath_roll: bool)

var heat_max := 100.0
var heat := 0.0
var run_risk_delta := 0.0
var corruption := 0.0

func _ready() -> void:
	reset_run()

func reset_run() -> void:
	heat_max = Balance.HEAT_BASE_MAX
	heat = 0.0
	run_risk_delta = 0.0
	corruption = 0.0
	heat_changed.emit(heat, heat_max)
	risk_changed.emit(get_permadeath_probability())
	corruption_changed.emit(corruption)

func add_heat(amount: float) -> void:
	heat = clampf(heat + amount, 0.0, heat_max)
	heat_changed.emit(heat, heat_max)

func consume_heat(amount: float) -> void:
	heat = clampf(heat - amount, 0.0, heat_max)
	heat_changed.emit(heat, heat_max)

func can_unfold() -> bool:
	return heat >= Balance.HEAT_TRIGGER_THRESHOLD

func add_unfold_risk(delta: float) -> void:
	run_risk_delta = minf(run_risk_delta + delta, Balance.RISK_CAP_PER_RUN)
	risk_changed.emit(get_permadeath_probability())

func add_corruption(amount: float) -> void:
	corruption += amount
	corruption_changed.emit(corruption)

func get_permadeath_probability() -> float:
	return clampf(Balance.PERMADEATH_BASE + run_risk_delta, 0.0, 1.0)

func roll_permadeath() -> bool:
	var failed := randf() < get_permadeath_probability()
	player_died.emit(failed)
	return failed

