extends Node

signal minute_changed(absolute_minutes: int)

const MINUTES_PER_DAY: int = 1440

@export_range(0.01, 60.0, 0.01, "or_greater") var seconds_per_minute: float = 1.0:
	set(value):
		seconds_per_minute = maxf(value, 0.01)
		if is_node_ready():
			_timer.start(seconds_per_minute)

var _absolute_minutes: int = 0
var _assessment_tokens: Dictionary[int, bool] = {}
var _next_assessment_token: int = 0
var _assessment_started_msec: int = 0
var _assessment_remainder_msec: int = 0

@onready var _timer: Timer = $MinuteTimer


func _ready() -> void:
	_timer.timeout.connect(_advance_minute)
	_timer.start(seconds_per_minute)


func get_day() -> int:
	@warning_ignore("integer_division")
	return _absolute_minutes / MINUTES_PER_DAY + 1


func get_absolute_minutes() -> int:
	return _absolute_minutes


func get_week() -> int:
	return floori(float(get_day() - 1) / 7.0) + 1


func begin_assessment() -> int:
	if _assessment_tokens.is_empty():
		_assessment_started_msec = Time.get_ticks_msec()
		_timer.paused = true
	_next_assessment_token += 1
	_assessment_tokens[_next_assessment_token] = true
	return _next_assessment_token


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
