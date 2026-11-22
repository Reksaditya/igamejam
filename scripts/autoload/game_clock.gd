extends Node

signal minute_changed(absolute_minutes: int)

const MINUTES_PER_DAY: int = 1440
const DAYS_PER_SEMESTER: int = 12
const SEMESTER_COUNT: int = 2
const MORNING_MINUTES := 360
const TIMED_ATTEMPT_MINUTES := 10
const LEGACY_TIMELINE_PATH := "user://chapter_timeline.cfg"
const Save = preload("res://scripts/autoload/playthrough_save.gd")

@export_range(0.01, 60.0, 0.01, "or_greater") var seconds_per_minute: float = 0.5:
	set(value):
		seconds_per_minute = maxf(value, 0.01)
		if is_node_ready():
			_timer.start(seconds_per_minute)

var _absolute_minutes: int = 0
var _assessment_tokens: Dictionary[int, bool] = {}
var _next_assessment_token: int = 0
var _assessment_started_msec: int = 0
var _assessment_remainder_msec: int = 0
var _class_owner: Node
var _class_start: int = 0
var _timeline_initialized := false
var _timed_owner: Node
var _timed_token := 0

@onready var _timer: Timer = $MinuteTimer


func _ready() -> void:
	_timer.timeout.connect(_advance_minute)
	_timer.start(seconds_per_minute)


func resume_timeline() -> void:
	if _timeline_initialized:
		return
	var saved := Save.load_config(LEGACY_TIMELINE_PATH)
	var minutes: Variant = saved.get_value("chapter_timeline", "absolute_minutes", MORNING_MINUTES)
	restore_save_state({"minutes": minutes if minutes is int else MORNING_MINUTES})


func get_day() -> int:
	@warning_ignore("integer_division")
	return _absolute_minutes / MINUTES_PER_DAY + 1


func get_semester() -> int:
	@warning_ignore("integer_division")
	return clampi((get_day() - 1) / DAYS_PER_SEMESTER + 1, 1, SEMESTER_COUNT)


func get_day_in_semester() -> int:
	return (get_day() - 1) % DAYS_PER_SEMESTER + 1


func get_absolute_minutes() -> int:
	return _absolute_minutes


func get_week() -> int:
	return floori(float(get_day() - 1) / 7.0) + 1


func get_save_state() -> Dictionary:
	var minutes := _absolute_minutes
	var remainder := _assessment_remainder_msec
	if not _assessment_tokens.is_empty():
		var elapsed := Time.get_ticks_msec() - _assessment_started_msec + remainder
		minutes += floori(float(elapsed) / 60000.0)
		remainder = elapsed % 60000
	return {"minutes": minutes, "remainder": remainder}


func restore_save_state(state: Dictionary) -> void:
	_timeline_initialized = true
	_clear_timed_attempt()
	_class_owner = null
	_assessment_tokens.clear()
	_absolute_minutes = maxi(0, state.get("minutes", 0))
	_assessment_remainder_msec = clampi(state.get("remainder", 0), 0, 59999)
	_timer.paused = false
	_timer.start(seconds_per_minute)
	minute_changed.emit(_absolute_minutes)


func is_activity_running() -> bool:
	return is_instance_valid(_class_owner) or is_instance_valid(_timed_owner) or not _assessment_tokens.is_empty()


func begin_timed_attempt(owner: Node) -> int:
	if is_activity_running() or not is_instance_valid(owner) or not owner.is_inside_tree():
		return 0
	resume_timeline()
	_timed_token += 1
	_timed_owner = owner
	_timer.paused = true
	owner.tree_exiting.connect(_on_timed_owner_exiting.bind(_timed_token), CONNECT_ONE_SHOT)
	return _timed_token


func complete_timed_attempt(token: int) -> bool:
	if not cancel_activity(token):
		return false
	advance_minutes(TIMED_ATTEMPT_MINUTES)
	return true


func cancel_activity(token: int) -> bool:
	if not is_instance_valid(_timed_owner) or token != _timed_token:
		return false
	_clear_timed_attempt()
	_timer.paused = false
	return true


func _on_timed_owner_exiting(token: int) -> void:
	cancel_activity(token)


func _clear_timed_attempt() -> void:
	if is_instance_valid(_timed_owner):
		var callback := _on_timed_owner_exiting.bind(_timed_token)
		if _timed_owner.tree_exiting.is_connected(callback):
			_timed_owner.tree_exiting.disconnect(callback)
	_timed_owner = null


func begin_assessment() -> int:
	if is_instance_valid(_class_owner) or is_instance_valid(_timed_owner):
		return 0
	_timeline_initialized = true
	if _assessment_tokens.is_empty():
		_assessment_started_msec = Time.get_ticks_msec()
		_timer.paused = true
	_next_assessment_token += 1
	_assessment_tokens[_next_assessment_token] = true
	return _next_assessment_token


func begin_class(owner: Node) -> bool:
	if is_activity_running():
		return false
	_timeline_initialized = true
	_class_owner = owner
	_class_start = _absolute_minutes
	_timer.paused = true
	owner.tree_exiting.connect(cancel_class.bind(owner), CONNECT_ONE_SHOT)
	return true


func complete_class(owner: Node) -> bool:
	if owner != _class_owner:
		return false
	_class_owner = null
	_absolute_minutes = _class_start + 120
	_timer.paused = false
	_timer.start(seconds_per_minute)
	minute_changed.emit(_absolute_minutes)
	return true


func cancel_class(owner: Node) -> void:
	if owner == _class_owner:
		_class_owner = null
		_timer.paused = false


func advance_minutes(minutes: int) -> void:
	_timeline_initialized = true
	_absolute_minutes += maxi(0, minutes)
	_timer.start(seconds_per_minute)
	minute_changed.emit(_absolute_minutes)


func end_assessment(token: int) -> void:
	if not _assessment_tokens.has(token):
		return
	_assessment_tokens.erase(token)
	if not _assessment_tokens.is_empty():
		return
	var elapsed := Time.get_ticks_msec() - _assessment_started_msec + _assessment_remainder_msec
	var minutes := floori(float(elapsed) / 60000.0)
	_assessment_remainder_msec = elapsed % 60000
	_absolute_minutes += minutes
	_timer.paused = false
	if minutes > 0:
		minute_changed.emit(_absolute_minutes)


func get_formatted_time() -> String:
	var minute_of_day := _absolute_minutes % MINUTES_PER_DAY
	@warning_ignore("integer_division")
	return "%02d:%02d" % [minute_of_day / 60, minute_of_day % 60]


func _advance_minute() -> void:
	_absolute_minutes += 1
	minute_changed.emit(_absolute_minutes)
