extends Node

signal unfold_started
signal unfold_ended(reason: String)

enum Mode {
	VERTICAL,
	TRANSITION,
	UNFOLDED,
	COOLDOWN,
}

var mode := Mode.VERTICAL
var cooldown_remaining := 0.0

func _process(delta: float) -> void:
	if mode == Mode.COOLDOWN:
		cooldown_remaining = maxf(0.0, cooldown_remaining - delta)
		if cooldown_remaining <= 0.0:
			mode = Mode.VERTICAL
	if mode == Mode.UNFOLDED:
		RunState.consume_heat(Balance.UNFOLD_CONSUME_RATE * delta)
		if RunState.heat <= 0.0:
			end_unfold("natural")

func can_unfold() -> bool:
	return mode == Mode.VERTICAL and RunState.can_unfold()

func start_unfold() -> bool:
	if not can_unfold():
		return false
	mode = Mode.UNFOLDED
	unfold_started.emit()
	return true

func end_unfold(reason: String) -> void:
	if mode != Mode.UNFOLDED:
		return
	match reason:
		"collapse":
			RunState.consume_heat(RunState.heat)
			RunState.add_unfold_risk(Balance.RISK_COLLAPSE)
			RunState.add_corruption(Balance.CORRUPTION_COLLAPSE)
			_start_cooldown(Balance.UNFOLD_COOLDOWN_COLLAPSE)
		"early":
			RunState.add_unfold_risk(Balance.RISK_UNFOLD_EARLY)
			RunState.add_corruption(Balance.CORRUPTION_UNFOLD_EARLY)
			_start_cooldown(Balance.UNFOLD_COOLDOWN_NORMAL)
		_:
			RunState.add_unfold_risk(Balance.RISK_UNFOLD_FULL)
			RunState.add_corruption(Balance.CORRUPTION_UNFOLD_FULL)
			_start_cooldown(Balance.UNFOLD_COOLDOWN_NORMAL)
	unfold_ended.emit(reason)

func is_unfolded() -> bool:
	return mode == Mode.UNFOLDED

func is_vertical() -> bool:
	return mode == Mode.VERTICAL

func _start_cooldown(duration: float) -> void:
	mode = Mode.COOLDOWN
	cooldown_remaining = duration

