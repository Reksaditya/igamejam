extends Node

signal minute_changed(absolute_minutes: int)

enum Activity { NONE, CLASS, TIMED_ATTEMPT }

const Save = preload("res://scripts/autoload/playthrough_save.gd")
const SAVE_PATH := "user://chapter_timeline.cfg"
const MINUTES_PER_DAY := 1440
const MORNING_MINUTES := 360
const CLASS_MINUTES := 120
const TIMED_ATTEMPT_MINUTES := 10

@export_range(0.01, 60.0, 0.01, "or_greater") var seconds_per_minute: float = 0.5:
	set(value):
		seconds_per_minute = maxf(value, 0.01)
		if is_node_ready() and not is_activity_running():
			_reset_tick()


var _absolute_minutes := MORNING_MINUTES
var _timeline_active := false
var _next_tick_us := 0
var _activity := Activity.NONE
var _serial := 0
var _activity_owner: Node
var _activity_start := MORNING_MINUTES
var _remaining_tick_us := 0

var _assessment_tokens: Dictionary[int, bool] = {}
var _next_assessment_token := 0
var _assessment_started_msec := 0
var _assessment_remainder_msec := 0
var _pause_started_us := 0


func _ready() -> void:
	_reset_tick()


func _notification(what: int) -> void:
	if what == NOTIFICATION_PAUSED:
		_pause_started_us = Time.get_ticks_usec()
	elif what == NOTIFICATION_UNPAUSED and _pause_started_us > 0:
		_next_tick_us += Time.get_ticks_usec() - _pause_started_us
		_pause_started_us = 0


func _process(_delta: float) -> void:
	if is_activity_running():
		return
	var now := Time.get_ticks_usec()
	if now < _next_tick_us:
		return
	var period := _period_us()
	@warning_ignore("integer_division")
	var minutes := (now - _next_tick_us) / period + 1
	_next_tick_us += minutes * period
	_absolute_minutes += minutes
	_publish_minute()


func resume_timeline() -> void:
	if _timeline_active:
		return
	_timeline_active = true
	var saved := Save.load_config(SAVE_PATH)
	var minutes: Variant = saved.get_value("chapter_timeline", "absolute_minutes", MORNING_MINUTES)
	_absolute_minutes = maxi(minutes, 0) if minutes is int else MORNING_MINUTES
	_reset_tick()
	_publish_minute()


func get_day() -> int:
	@warning_ignore("integer_division")
	return _absolute_minutes / MINUTES_PER_DAY + 1


func get_week() -> int:
	@warning_ignore("integer_division")
	return (get_day() - 1) / 7 + 1


func get_save_state() -> Dictionary:
	var minutes := _absolute_minutes
	var remainder := _assessment_remainder_msec
	if not _assessment_tokens.is_empty():
		var elapsed := Time.get_ticks_msec() - _assessment_started_msec + remainder
		@warning_ignore("integer_division")
		minutes += elapsed / 60000
		remainder = elapsed % 60000
	return {"minutes": minutes, "remainder": remainder}


func restore_save_state(state: Dictionary) -> void:
	if _activity != Activity.NONE:
		_clear_activity()
	_assessment_tokens.clear()
	_timeline_active = true
	_absolute_minutes = maxi(0, state.get("minutes", MORNING_MINUTES))
	_assessment_remainder_msec = clampi(state.get("remainder", 0), 0, 59999)
	_reset_tick()
	_publish_minute()


func reset_timeline() -> void:
	if _activity != Activity.NONE:
		_clear_activity()
	_assessment_tokens.clear()
	_timeline_active = false
	_absolute_minutes = MORNING_MINUTES
	_assessment_remainder_msec = 0
	_reset_tick()
	minute_changed.emit(_absolute_minutes)


func begin_assessment() -> int:
	if _activity != Activity.NONE:
		return 0
	if _assessment_tokens.is_empty():
		_assessment_started_msec = Time.get_ticks_msec()
	_next_assessment_token += 1
	_assessment_tokens[_next_assessment_token] = true
	return _next_assessment_token


func end_assessment(token: int) -> void:
	if not _assessment_tokens.erase(token) or not _assessment_tokens.is_empty():
		return
	var elapsed := Time.get_ticks_msec() - _assessment_started_msec + _assessment_remainder_msec
	@warning_ignore("integer_division")
	var minutes := elapsed / 60000
	_assessment_remainder_msec = elapsed % 60000
	_absolute_minutes += minutes
	_reset_tick()
	if minutes > 0:
		_publish_minute()


func get_absolute_minutes() -> int:
	return _absolute_minutes


func get_formatted_time() -> String:
	var minute_of_day := _absolute_minutes % MINUTES_PER_DAY
	@warning_ignore("integer_division")
	return "%02d:%02d" % [minute_of_day / 60, minute_of_day % 60]


func advance_to_next_morning() -> void:
	if is_activity_running():
		return
	_absolute_minutes = get_day() * MINUTES_PER_DAY + MORNING_MINUTES
	_reset_tick()
	_publish_minute()


func is_activity_running() -> bool:
	return _activity != Activity.NONE or not _assessment_tokens.is_empty()


## A token belongs to its owner. Leaving the tree cancels the activity.
func begin_class(owner: Node) -> int:
	return _begin_activity(owner, Activity.CLASS)


func complete_class(token: int) -> bool:
	return _complete_activity(token, Activity.CLASS, CLASS_MINUTES)


func begin_timed_attempt(owner: Node) -> int:
	return _begin_activity(owner, Activity.TIMED_ATTEMPT)


func complete_timed_attempt(token: int) -> bool:
	return _complete_activity(token, Activity.TIMED_ATTEMPT, TIMED_ATTEMPT_MINUTES)


func cancel_activity(token: int) -> bool:
	if not _owns_activity(token):
		return false
	_clear_activity()
	_reset_tick()
	_next_tick_us -= _period_us() - _remaining_tick_us
	return true


func _begin_activity(owner: Node, activity: Activity) -> int:
	if is_activity_running() or not is_instance_valid(owner) or not owner.is_inside_tree() or owner.is_queued_for_deletion():
		return 0
	resume_timeline()
	if is_activity_running() or not is_instance_valid(owner) or not owner.is_inside_tree() or owner.is_queued_for_deletion():
		return 0
	_serial += 1
	_activity = activity
	_activity_owner = owner
	_activity_start = _absolute_minutes
	_remaining_tick_us = clampi(_next_tick_us - Time.get_ticks_usec(), 0, _period_us())
	owner.tree_exiting.connect(_on_activity_owner_exiting.bind(_serial), CONNECT_ONE_SHOT)
	return _serial


func _owns_activity(token: int) -> bool:
	return is_activity_running() and token == _serial


func _complete_activity(token: int, activity: Activity, minutes: int) -> bool:
	if not _owns_activity(token) or _activity != activity:
		return false
	_absolute_minutes = _activity_start + minutes
	_clear_activity()
	_reset_tick()
	_publish_minute()
	return true


func _on_activity_owner_exiting(token: int) -> void:
	cancel_activity(token)


func _clear_activity() -> void:
	var connection := _on_activity_owner_exiting.bind(_serial)
	if is_instance_valid(_activity_owner) and _activity_owner.tree_exiting.is_connected(connection):
		_activity_owner.tree_exiting.disconnect(connection)
	_activity_owner = null
	_activity = Activity.NONE


func _period_us() -> int:
	return roundi(seconds_per_minute * 1_000_000)


func _reset_tick() -> void:
	var now := Time.get_ticks_usec()
	_next_tick_us = now + _period_us()
	if is_inside_tree() and get_tree().paused:
		_pause_started_us = now


func _publish_minute() -> void:
	if _timeline_active:
		var config := ConfigFile.new()
		config.set_value("chapter_timeline", "absolute_minutes", _absolute_minutes)
		var error := Save.write_config(config, SAVE_PATH, false)
		if error != OK:
			push_warning("Gagal menyimpan waktu bab (%s)." % error_string(error))
	minute_changed.emit(_absolute_minutes)
