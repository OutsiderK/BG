extends CharacterBody2D

signal damaged(amount: int)
signal died

@export var max_hp := 10
@export var vertical_speed := 220.0
@export var jump_velocity := -420.0
@export var gravity := 1200.0
@export var unfolded_speed := 260.0
@export var dash_speed := 620.0
@export var dash_duration := 0.12
@export var dash_cooldown := 0.8
@export var max_dash_charges := 2
@export var hurt_knockback_speed := 180.0
@export var hurt_knockback_vertical := -80.0
@export var hurt_flash_interval := 0.06
@export var hurt_flash_color := Color(1.0, 0.35, 0.35, 1.0)
@export var death_tint := Color(0.28, 0.28, 0.32, 1.0)

var hp := 10
var facing := Vector2.RIGHT
var hit_invulnerable_remaining := 0.0
var dash_invulnerable_remaining := 0.0
var dash_remaining := 0.0
var dash_cooldown_remaining := 0.0
var dash_charges := 2
var dash_direction := Vector2.RIGHT
var dead := false
@onready var sword_attack: Node = get_node_or_null("SwordAttack")
@onready var animated_actor: Node = get_node_or_null("AnimatedActor")
@onready var legacy_visual: ColorRect = get_node_or_null("ColorRect") as ColorRect
@onready var player_visual: CanvasItem = _find_player_visual()

var _base_visual_color := Color(0.85, 0.92, 1.0, 1.0)
var _blocked_unfold_on_death := false

func _ready() -> void:
	add_to_group("player")
	UnfoldManager.set_player(self)
	hp = max_hp
	dash_charges = max_dash_charges
	RunState.set_health(hp, max_hp)
	if player_visual != null:
		_base_visual_color = player_visual.modulate
	UnfoldManager.unfold_started.connect(_on_unfold_started)
	UnfoldManager.unfold_ended.connect(_on_unfold_ended)
	_connect_actor_attack_events()

func _physics_process(delta: float) -> void:
	_tick_timers(delta)
	_update_damage_visual()
	if dead:
		_process_dead()
		move_and_slide()
		return
	if Input.is_action_just_pressed("unfold"):
		if UnfoldManager.is_unfolded():
			UnfoldManager.end_unfold("early")
		else:
			UnfoldManager.start_unfold()
	if Input.is_action_just_pressed("dash"):
		_try_start_dash()
	if Input.is_action_just_pressed("attack"):
		_try_attack()
	if UnfoldManager.is_unfolded():
		_process_unfolded(delta)
	else:
		_process_vertical(delta)
	_process_dash()
	_update_actor_animation()
	move_and_slide()

func _exit_tree() -> void:
	if _blocked_unfold_on_death:
		UnfoldManager.set_gameplay_blocked(false)
		_blocked_unfold_on_death = false

func _process_vertical(delta: float) -> void:
	motion_mode = MOTION_MODE_GROUNDED
	var direction := Input.get_axis("move_left", "move_right")
	velocity.x = direction * vertical_speed
	if direction != 0.0:
		facing = Vector2(signf(direction), 0.0)
	if not is_on_floor():
		velocity.y += gravity * delta
	if Input.is_action_just_pressed("move_up") and is_on_floor():
		velocity.y = jump_velocity

func _process_dead() -> void:
	motion_mode = MOTION_MODE_GROUNDED
	dash_remaining = 0.0
	dash_invulnerable_remaining = 0.0
	velocity = Vector2.ZERO
	_play_actor_state(&"death")

func _process_unfolded(_delta: float) -> void:
	motion_mode = MOTION_MODE_FLOATING
	var input_vector := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if input_vector.length() > 0.0:
		facing = input_vector.normalized()
	velocity = input_vector * unfolded_speed

func _process_dash() -> void:
	if dash_remaining <= 0.0:
		return
	velocity = dash_direction * dash_speed

func _tick_timers(delta: float) -> void:
	hit_invulnerable_remaining = maxf(0.0, hit_invulnerable_remaining - delta)
	dash_invulnerable_remaining = maxf(0.0, dash_invulnerable_remaining - delta)
	dash_remaining = maxf(0.0, dash_remaining - delta)
	if dash_cooldown_remaining > 0.0:
		dash_cooldown_remaining = maxf(0.0, dash_cooldown_remaining - delta)
		if dash_cooldown_remaining <= 0.0:
			dash_charges = max_dash_charges

func _try_start_dash() -> void:
	if dead or dash_remaining > 0.0 or dash_charges <= 0:
		return
	dash_direction = _get_dash_direction()
	dash_remaining = dash_duration
	dash_invulnerable_remaining = Balance.PLAYER_DASH_INVULN
	dash_charges -= 1
	if dash_charges <= 0:
		dash_cooldown_remaining = dash_cooldown

func _try_attack() -> void:
	if dead:
		return
	if sword_attack == null or not sword_attack.has_method("try_attack"):
		return
	var did_attack: bool = sword_attack.call("try_attack", facing, self)
	if did_attack:
		_play_actor_attack(&"sword-attack-1")

func _get_dash_direction() -> Vector2:
	if UnfoldManager.is_unfolded():
		var input_vector := Input.get_vector("move_left", "move_right", "move_up", "move_down")
		if input_vector.length() > 0.0:
			return input_vector.normalized()
		return facing.normalized()
	var direction := Input.get_axis("move_left", "move_right")
	if direction != 0.0:
		return Vector2(signf(direction), 0.0)
	if facing.x != 0.0:
		return Vector2(signf(facing.x), 0.0)
	return Vector2.RIGHT

func is_invulnerable() -> bool:
	return hit_invulnerable_remaining > 0.0 or dash_invulnerable_remaining > 0.0

func _on_unfold_started() -> void:
	if dead:
		UnfoldManager.end_unfold("collapse")
		return
	motion_mode = MOTION_MODE_FLOATING
	velocity = Vector2.ZERO

func _on_unfold_ended(_reason: String) -> void:
	motion_mode = MOTION_MODE_GROUNDED
	velocity = Vector2.ZERO

func apply_damage(amount: int, source: Node = null) -> bool:
	if dead or amount <= 0 or is_invulnerable():
		return false
	hp = maxi(0, hp - amount)
	RunState.set_health(hp, max_hp)
	hit_invulnerable_remaining = Balance.PLAYER_HIT_INVULN
	RunState.add_heat(Balance.HEAT_DAMAGED)
	_apply_damage_interrupt(source)
	_update_damage_visual()
	damaged.emit(amount)
	if hp <= 0:
		_die()
	elif UnfoldManager.is_unfolded() or UnfoldManager.is_transition():
		UnfoldManager.end_unfold("collapse")
	return true

func take_damage(amount: int) -> bool:
	return apply_damage(amount)

func is_dead() -> bool:
	return dead

func _apply_damage_interrupt(source: Node = null) -> void:
	dash_remaining = 0.0
	var knockback_direction := _get_damage_knockback_direction(source)
	if UnfoldManager.is_unfolded():
		velocity = knockback_direction * hurt_knockback_speed
		return
	var horizontal := knockback_direction.x
	if is_zero_approx(horizontal):
		horizontal = -signf(facing.x) if not is_zero_approx(facing.x) else -1.0
	velocity.x = signf(horizontal) * hurt_knockback_speed
	velocity.y = minf(velocity.y, hurt_knockback_vertical)

func _get_damage_knockback_direction(source: Node = null) -> Vector2:
	var source_2d := source as Node2D
	if source_2d != null:
		var offset := global_position - source_2d.global_position
		if offset.length() > 0.001:
			return offset.normalized()
	if facing.length() > 0.001:
		return -facing.normalized()
	return Vector2.LEFT

func _die() -> void:
	if dead:
		return
	dead = true
	dash_remaining = 0.0
	dash_invulnerable_remaining = 0.0
	hit_invulnerable_remaining = 0.0
	velocity = Vector2.ZERO
	if sword_attack != null and sword_attack.has_method("finish_attack"):
		sword_attack.call("finish_attack")
	if UnfoldManager.is_unfolded() or UnfoldManager.is_transition():
		UnfoldManager.end_unfold("collapse")
	UnfoldManager.set_gameplay_blocked(true)
	_blocked_unfold_on_death = true
	_update_damage_visual()
	_play_actor_state(&"death")
	died.emit()

func _update_damage_visual() -> void:
	if player_visual == null:
		return
	if dead:
		_set_visual_color(death_tint)
		return
	if hit_invulnerable_remaining > 0.0:
		var flash_on := int(floor(hit_invulnerable_remaining / hurt_flash_interval)) % 2 == 0
		if flash_on:
			_set_visual_color(hurt_flash_color)
		else:
			_set_visual_color(Color(_base_visual_color.r, _base_visual_color.g, _base_visual_color.b, 0.45))
		return
	_set_visual_color(_base_visual_color)

func _find_player_visual() -> CanvasItem:
	var actor := get_node_or_null("AnimatedActor") as CanvasItem
	if actor != null:
		return actor
	return get_node_or_null("ColorRect") as CanvasItem

func _set_visual_color(color: Color) -> void:
	if player_visual != null:
		player_visual.modulate = color
	if legacy_visual != null:
		legacy_visual.color = color

func _play_actor_state(state_name: StringName) -> void:
	if animated_actor == null or not animated_actor.has_method("play_state"):
		return
	animated_actor.call("play_state", state_name)

func _play_actor_attack(attack_name: StringName) -> void:
	if animated_actor == null or not animated_actor.has_method("play_attack"):
		return
	animated_actor.call("play_attack", attack_name)

func _update_actor_animation() -> void:
	if animated_actor == null:
		return
	if animated_actor.has_method("set_facing") and absf(facing.x) > 0.001:
		animated_actor.call("set_facing", int(signf(facing.x)))
	if animated_actor.has_method("is_action_playing") and animated_actor.call("is_action_playing"):
		return
	if dead:
		_play_actor_state(&"death")
		return
	if dash_remaining > 0.0:
		_play_actor_state(&"dash")
		return
	if UnfoldManager.is_unfolded():
		_play_actor_state(&"unfold-loop")
		return
	if not is_on_floor():
		_play_actor_state(&"jump-start" if velocity.y < 0.0 else &"fall")
		return
	if absf(velocity.x) > 1.0:
		_play_actor_state(&"run")
		return
	_play_actor_state(&"idle")

func _connect_actor_attack_events() -> void:
	if animated_actor == null or sword_attack == null:
		return
	if not animated_actor.has_method("has_animation") or not animated_actor.call("has_animation", &"sword-attack-1"):
		return
	if sword_attack.has_method("set_event_driven_hitbox"):
		sword_attack.call("set_event_driven_hitbox", true)
	if animated_actor.has_signal("hit_start") and sword_attack.has_method("begin_active_window"):
		animated_actor.connect("hit_start", Callable(sword_attack, "begin_active_window"))
	if animated_actor.has_signal("hit_end") and sword_attack.has_method("end_active_window"):
		animated_actor.connect("hit_end", Callable(sword_attack, "end_active_window"))
	if animated_actor.has_signal("anim_finished") and sword_attack.has_method("finish_attack"):
		animated_actor.connect("anim_finished", Callable(sword_attack, "finish_attack"))
