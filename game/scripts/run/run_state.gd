extends Node

signal health_changed(current: int, maximum: int)
signal heat_changed(current: float, maximum: float)
signal grey_coins_changed(current: int)
signal risk_changed(current_probability: float)
signal corruption_changed(current: float, tier: String)
signal player_died(permadeath_roll: bool)
signal death_resolved(result: Dictionary)
signal checkpoint_saved(snapshot: Dictionary)

const DEFAULT_AREA_ID := "giantwood_thin_forest"
const DEFAULT_WEAPON_ID := "sword_placeholder"
const RunCheckpointStoreScript := preload("res://game/scripts/save/run_checkpoint_store.gd")

var hp_max := 10
var hp := 10
var heat_max := 100.0
var heat := 0.0
var run_risk_delta := 0.0
var corruption := 0.0
var grey_coins := 0
var current_weapon_id := DEFAULT_WEAPON_ID
var dash_charges := 2
var dash_cooldown := 0.8
var current_area_id := DEFAULT_AREA_ID
var current_room_index := 1
var current_room_cleared := false
var player_level := 1
var items: Array[String] = []
var attribute_upgrades: Array[String] = []
var temporary_stigma_points := 0
var door_options: Array[Dictionary] = []
var last_death_result: Dictionary = {}

func _ready() -> void:
	reset_run()

func reset_run() -> void:
	hp_max = Balance.PLAYER_MAX_HP
	hp = hp_max
	heat_max = Balance.HEAT_BASE_MAX
	heat = 0.0
	run_risk_delta = 0.0
	corruption = 0.0
	grey_coins = 0
	current_weapon_id = DEFAULT_WEAPON_ID
	dash_charges = 2
	dash_cooldown = 0.8
	current_area_id = DEFAULT_AREA_ID
	current_room_index = 1
	current_room_cleared = false
	player_level = 1
	items.clear()
	attribute_upgrades.clear()
	temporary_stigma_points = 0
	door_options.clear()
	last_death_result.clear()
	health_changed.emit(hp, hp_max)
	heat_changed.emit(heat, heat_max)
	grey_coins_changed.emit(grey_coins)
	risk_changed.emit(get_permadeath_probability())
	corruption_changed.emit(corruption, get_corruption_tier())

func set_health(current: int, maximum: int = -1) -> void:
	if maximum > 0:
		hp_max = maximum
	hp_max = maxi(hp_max, 1)
	hp = clampi(current, 0, hp_max)
	health_changed.emit(hp, hp_max)

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

func add_risk_delta(delta: float) -> void:
	run_risk_delta = clampf(run_risk_delta + delta, 0.0, Balance.RISK_CAP_PER_RUN)
	risk_changed.emit(get_permadeath_probability())

func add_corruption(amount: float) -> void:
	corruption += amount
	corruption_changed.emit(corruption, get_corruption_tier())

func set_grey_coins(amount: int) -> void:
	grey_coins = maxi(amount, 0)
	grey_coins_changed.emit(grey_coins)

func add_grey_coins(amount: int) -> void:
	set_grey_coins(grey_coins + amount)

func set_room_state(area_id: String, room_index: int, room_cleared: bool, doors: Array[Dictionary] = []) -> void:
	current_area_id = area_id
	current_room_index = maxi(room_index, 1)
	current_room_cleared = room_cleared
	door_options = doors.duplicate(true)

func get_permadeath_probability() -> float:
	return clampf(Balance.PERMADEATH_BASE + run_risk_delta, 0.0, 1.0)

func get_corruption_tier() -> String:
	if corruption >= Balance.CORRUPTION_THRESHOLD_RED:
		return "red"
	if corruption >= Balance.CORRUPTION_THRESHOLD_YELLOW:
		return "yellow"
	return "white"

func roll_permadeath() -> bool:
	var permadeath := randf() < get_permadeath_probability()
	last_death_result = {
		"permadeath": permadeath,
		"result_label": "彻底死亡" if permadeath else "普通重塑",
		"probability": get_permadeath_probability(),
		"risk_delta": run_risk_delta,
		"corruption": corruption,
		"corruption_tier": get_corruption_tier(),
		"kept": ["局外圣痕点", "已解锁天赋"] if not permadeath else [],
		"lost": ["本局灰币", "本局道具", "房间进度"] if not permadeath else ["当前存档锚点", "本局全部进度"],
	}
	player_died.emit(permadeath)
	death_resolved.emit(last_death_result)
	return permadeath

func build_checkpoint_snapshot() -> Dictionary:
	return {
		"version": 0,
		"area_id": current_area_id,
		"room_index": current_room_index,
		"room_cleared": current_room_cleared,
		"player_hp": hp,
		"player_max_hp": hp_max,
		"heat": heat,
		"heat_max": heat_max,
		"corruption": corruption,
		"corruption_tier": get_corruption_tier(),
		"risk_delta": run_risk_delta,
		"permadeath_probability": get_permadeath_probability(),
		"current_weapon": current_weapon_id,
		"dash_charges": dash_charges,
		"dash_cooldown": dash_cooldown,
		"grey_coins": grey_coins,
		"temporary_stigma_points": temporary_stigma_points,
		"player_level": player_level,
		"items": items.duplicate(),
		"attribute_upgrades": attribute_upgrades.duplicate(),
		"door_options": door_options.duplicate(true),
	}

func save_run_checkpoint(extra_data: Dictionary = {}) -> Dictionary:
	var snapshot := build_checkpoint_snapshot()
	for key in extra_data:
		snapshot[key] = extra_data[key]
	RunCheckpointStoreScript.save_run_checkpoint(snapshot)
	checkpoint_saved.emit(snapshot)
	return snapshot
