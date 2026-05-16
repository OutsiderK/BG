extends Control

const KIND_ENTER := "enter"
const KIND_COLLAPSE := "collapse"
const SETTLE_DURATION := 0.16
const COLLAPSE_FADE_DURATION := 0.12
const GLYPH_SEGMENTS := 96
const RAY_COUNT := 12

enum Phase {
	IDLE,
	ENTERING,
	ENTER_SETTLE,
	COLLAPSING,
	COLLAPSE_FADE,
}

@export var enter_duration := 0.5
@export var collapse_duration := 0.3

var _phase := Phase.IDLE
var _kind := ""
var _phase_started_msec := 0
var _phase_duration := 0.0
var _last_progress := 0.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	enter_duration = Balance.UNFOLD_TRANSITION_IN
	collapse_duration = Balance.UNFOLD_COLLAPSE_TIME
	visible = false
	if not resized.is_connected(_on_resized):
		resized.connect(_on_resized)
	if not UnfoldManager.unfold_transition_started.is_connected(_on_unfold_transition_started):
		UnfoldManager.unfold_transition_started.connect(_on_unfold_transition_started)
	if not UnfoldManager.unfold_entered.is_connected(_on_unfold_entered):
		UnfoldManager.unfold_entered.connect(_on_unfold_entered)
	if not UnfoldManager.unfold_ended.is_connected(_on_unfold_ended):
		UnfoldManager.unfold_ended.connect(_on_unfold_ended)

func _process(_delta: float) -> void:
	if _phase == Phase.IDLE:
		return
	_last_progress = _phase_progress()
	if _last_progress >= 1.0 and (_phase == Phase.ENTER_SETTLE or _phase == Phase.COLLAPSE_FADE):
		_hide_overlay()
		return
	queue_redraw()

func _draw() -> void:
	if _phase == Phase.IDLE:
		return
	var viewport_size := size
	if viewport_size.x <= 1.0 or viewport_size.y <= 1.0:
		viewport_size = get_viewport_rect().size
	if viewport_size.x <= 1.0 or viewport_size.y <= 1.0:
		return
	if _kind == KIND_COLLAPSE:
		_draw_collapse(viewport_size)
	else:
		_draw_enter(viewport_size)

func is_transition_visible() -> bool:
	return visible and _phase != Phase.IDLE

func get_transition_kind() -> String:
	return _kind

func get_transition_progress() -> float:
	return _last_progress

func _on_unfold_transition_started(kind: String) -> void:
	if kind == KIND_ENTER:
		_begin_phase(Phase.ENTERING, KIND_ENTER, enter_duration)
	elif kind == KIND_COLLAPSE:
		_begin_phase(Phase.COLLAPSING, KIND_COLLAPSE, collapse_duration)

func _on_unfold_entered() -> void:
	if _kind == KIND_ENTER:
		_begin_phase(Phase.ENTER_SETTLE, KIND_ENTER, SETTLE_DURATION)

func _on_unfold_ended(reason: String) -> void:
	if reason == KIND_COLLAPSE and _kind == KIND_COLLAPSE:
		_begin_phase(Phase.COLLAPSE_FADE, KIND_COLLAPSE, COLLAPSE_FADE_DURATION)
	elif _kind != KIND_COLLAPSE:
		_hide_overlay()

func _on_resized() -> void:
	queue_redraw()

func _begin_phase(next_phase: int, next_kind: String, duration: float) -> void:
	_phase = next_phase
	_kind = next_kind
	_phase_duration = maxf(0.001, duration)
	_phase_started_msec = Time.get_ticks_msec()
	_last_progress = 0.0
	visible = true
	queue_redraw()

func _hide_overlay() -> void:
	_phase = Phase.IDLE
	_kind = ""
	_last_progress = 1.0
	visible = false
	queue_redraw()

func _phase_progress() -> float:
	var elapsed := float(Time.get_ticks_msec() - _phase_started_msec) / 1000.0
	return clampf(elapsed / _phase_duration, 0.0, 1.0)

func _draw_enter(viewport_size: Vector2) -> void:
	var phase_progress := _phase_progress()
	var expand := smoothstep(0.0, 1.0, phase_progress)
	var settle_fade := 1.0
	var glyph_expand := expand
	if _phase == Phase.ENTER_SETTLE:
		settle_fade = 1.0 - smoothstep(0.0, 1.0, phase_progress)
		glyph_expand = 1.0 + phase_progress * 0.14
	var pulse := sin(clampf(phase_progress, 0.0, 1.0) * PI)
	var dim_alpha := (0.26 + pulse * 0.22) * settle_fade
	draw_rect(Rect2(Vector2.ZERO, viewport_size), Color(0.015, 0.018, 0.035, dim_alpha), true)

	var edge_alpha := (0.28 + pulse * 0.22) * settle_fade
	var frame_alpha := (0.48 + pulse * 0.32) * settle_fade
	_draw_edge_folds(
		viewport_size,
		lerpf(0.24, 1.0, expand),
		Color(0.95, 0.86, 0.55, edge_alpha),
		Color(0.62, 0.88, 1.0, frame_alpha)
	)
	_draw_saint_glyph(
		viewport_size,
		glyph_expand,
		Color(0.82, 0.96, 1.0, 0.58 * settle_fade),
		Color(1.0, 0.86, 0.42, 0.72 * settle_fade),
		false
	)

func _draw_collapse(viewport_size: Vector2) -> void:
	var phase_progress := _phase_progress()
	var close_amount := smoothstep(0.0, 1.0, phase_progress)
	var fade := 1.0
	if _phase == Phase.COLLAPSE_FADE:
		fade = 1.0 - close_amount
	var flash := 1.0 - close_amount
	draw_rect(Rect2(Vector2.ZERO, viewport_size), Color(0.16, 0.0, 0.0, (0.18 + flash * 0.22) * fade), true)
	_draw_edge_folds(
		viewport_size,
		lerpf(0.55, 1.55, close_amount),
		Color(1.0, 0.1, 0.06, 0.34 * fade),
		Color(1.0, 0.38, 0.25, 0.66 * fade)
	)
	_draw_saint_glyph(
		viewport_size,
		1.0 - close_amount * 0.45,
		Color(1.0, 0.28, 0.22, 0.36 * fade),
		Color(1.0, 0.08, 0.05, 0.7 * fade),
		true
	)

func _draw_edge_folds(viewport_size: Vector2, fold_scale: float, fold_color: Color, line_color: Color) -> void:
	var width := viewport_size.x
	var height := viewport_size.y
	var max_thickness := clampf(minf(width, height) * 0.105, 42.0, 92.0)
	var thickness := max_thickness * fold_scale
	var points_top := PackedVector2Array([
		Vector2.ZERO,
		Vector2(width, 0.0),
		Vector2(width - thickness, thickness),
		Vector2(thickness, thickness),
	])
	var points_bottom := PackedVector2Array([
		Vector2(0.0, height),
		Vector2(width, height),
		Vector2(width - thickness, height - thickness),
		Vector2(thickness, height - thickness),
	])
	var points_left := PackedVector2Array([
		Vector2.ZERO,
		Vector2(thickness, thickness),
		Vector2(thickness, height - thickness),
		Vector2(0.0, height),
	])
	var points_right := PackedVector2Array([
		Vector2(width, 0.0),
		Vector2(width, height),
		Vector2(width - thickness, height - thickness),
		Vector2(width - thickness, thickness),
	])
	draw_colored_polygon(points_top, fold_color)
	draw_colored_polygon(points_bottom, fold_color)
	draw_colored_polygon(points_left, fold_color.darkened(0.18))
	draw_colored_polygon(points_right, fold_color.darkened(0.12))

	var margin := clampf(thickness * 0.72, 18.0, minf(width, height) * 0.18)
	draw_rect(Rect2(Vector2(margin, margin), viewport_size - Vector2(margin * 2.0, margin * 2.0)), line_color, false, 2.0)
	draw_line(Vector2(margin, 0.0), Vector2(margin, height), line_color, 1.0)
	draw_line(Vector2(width - margin, 0.0), Vector2(width - margin, height), line_color, 1.0)
	draw_line(Vector2(0.0, margin), Vector2(width, margin), line_color, 1.0)
	draw_line(Vector2(0.0, height - margin), Vector2(width, height - margin), line_color, 1.0)

func _draw_saint_glyph(viewport_size: Vector2, progress: float, ring_color: Color, ray_color: Color, collapse: bool) -> void:
	var center := viewport_size * 0.5
	var max_radius := minf(viewport_size.x, viewport_size.y) * 0.34
	var radius := max_radius * clampf(progress, 0.08, 1.2)
	var rotation := progress * TAU * (0.08 if not collapse else -0.12)
	for ring_index in range(3):
		var ring_radius := maxf(8.0, radius - float(ring_index) * 26.0)
		var alpha_scale := 1.0 - float(ring_index) * 0.22
		var color := Color(ring_color.r, ring_color.g, ring_color.b, ring_color.a * alpha_scale)
		draw_arc(center, ring_radius, rotation + float(ring_index) * 0.34, rotation + TAU * 0.82, GLYPH_SEGMENTS, color, 2.0, true)
	for index in range(RAY_COUNT):
		var angle := rotation + TAU * float(index) / float(RAY_COUNT)
		var direction := Vector2(cos(angle), sin(angle))
		var inner := center + direction * radius * 0.36
		var outer := center + direction * radius * (0.88 if not collapse else 0.62)
		var color := ray_color
		if index % 2 == 1:
			color.a *= 0.58
		draw_line(inner, outer, color, 1.5, true)
	var diamond_size := clampf(radius * 0.08, 8.0, 18.0)
	var diamond := PackedVector2Array([
		center + Vector2(0.0, -diamond_size),
		center + Vector2(diamond_size, 0.0),
		center + Vector2(0.0, diamond_size),
		center + Vector2(-diamond_size, 0.0),
	])
	draw_colored_polygon(diamond, ray_color)
