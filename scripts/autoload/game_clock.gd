extends Node

signal minute_changed(absolute_minutes: int)

const MINUTES_PER_DAY: int = 1440

@export_range(0.01, 60.0, 0.01, "or_greater") var seconds_per_minute: float = 1.0:
	set(value):
		seconds_per_minute = maxf(value, 0.01)
		if is_node_ready():
			_timer.start(seconds_per_minute)

var _absolute_minutes: int = 0

@onready var _timer: Timer = $MinuteTimer


func _ready() -> void:
	_timer.timeout.connect(_advance_minute)
	_timer.start(seconds_per_minute)


func get_day() -> int:
	@warning_ignore("integer_division")
	return _absolute_minutes / MINUTES_PER_DAY + 1


func get_absolute_minutes() -> int:
	return _absolute_minutes


func get_formatted_time() -> String:
	var minute_of_day := _absolute_minutes % MINUTES_PER_DAY
	@warning_ignore("integer_division")
	return "%02d:%02d" % [minute_of_day / 60, minute_of_day % 60]


func _advance_minute() -> void:
	_absolute_minutes += 1
	minute_changed.emit(_absolute_minutes)
