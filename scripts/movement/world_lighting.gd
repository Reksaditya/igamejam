extends CanvasLayer

var screen: ColorRect
var _night_alpha: float = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 20
	screen = ColorRect.new()
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(screen)
	GameClock.minute_changed.connect(_clock_changed)
	_clock_changed(GameClock.get_absolute_minutes())
	screen.color = Color(0, 0, 0, _night_alpha)


func darkness_for_minute(minutes: int) -> float:
	var minute := posmod(minutes, 1440)
	if minute >= 1080:
		return float(minute - 1080) / 480.0 * 0.4
	if minute < 120:
		return float(minute + 360) / 480.0 * 0.4
	if minute < 180:
		return 0.4
	if minute < 360:
		return float(360 - minute) / 180.0 * 0.4
	return 0


func _clock_changed(minutes: int) -> void:
	_night_alpha = darkness_for_minute(minutes)


func _process(delta: float) -> void:
	var world := get_tree().current_scene
	var sleeping: bool = world != null and world.get("sleeping") == true
	var target: float = 0.8 if sleeping else _night_alpha
	screen.color.a = move_toward(screen.color.a, target, delta * 1.6)
