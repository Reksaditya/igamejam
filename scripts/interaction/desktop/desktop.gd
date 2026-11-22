@tool
extends Control

const Launcher = preload("res://scripts/interaction/desktop/desktop_launcher.gd")
const FileManagerLauncher = preload("res://scripts/interaction/desktop/file_manager_launcher.gd")
const IconGrid = preload("res://scripts/interaction/desktop/desktop_icon_grid.gd")
const AppWindow = preload("res://scripts/interaction/desktop/app_window.gd")
const APP_WINDOW_SCENE: PackedScene = preload("res://scenes/interaction/desktop/app_window.tscn")
const RETURN_CONTEXT := &"desktop_return_context"
const BOOT_SECONDS := 1.5
const LATE_CLOCK_COLOR := Color("#ff827f")

@export_group("Wallpaper")
@export var wallpaper_texture: Texture2D:
	set(value):
		wallpaper_texture = value
		_refresh_wallpaper()
## Set to 0 for smooth wallpaper sampling.
@export_range(0, 512) var wallpaper_pixel_columns: int = 500:
	set(value):
		wallpaper_pixel_columns = value
		_refresh_wallpaper()
## 0 and 1 leave the wallpaper colors unchanged.
@export_range(0, 256) var wallpaper_color_levels: int = 0:
	set(value):
		wallpaper_color_levels = value
		_refresh_wallpaper()

var _open_windows: Dictionary[Launcher, AppWindow] = {}
var _active_window: AppWindow
var _exam_window: AppWindow
var _login: Control
var _normal_clock_color: Color
var _turning_off := false

@export_group("Login")
@export var login_scene: PackedScene

@export_group("Themes")
@export var light_theme: Theme

@export_group("Return")
@export_file("*.tscn") var return_scene: String
@export var return_spawn: StringName
@export var return_label := "Turn off"

@onready var _display: Control = $Display
@onready var _wallpaper: TextureRect = $Display/Wallpaper
@onready var _launchers: IconGrid = %Launchers
@onready var _windows: Control = $Display/Windows
@onready var _boot_cover: ColorRect = $Display/BootCover
@onready var _taskbar: PanelContainer = $Display/Taskbar
@onready var _clock: Label = %Clock
@onready var _turn_off: Button = %TurnOff
@onready var _startup_sound: AudioStreamPlayer = $StartupSound


func _ready() -> void:
	_refresh_wallpaper()
	if Engine.is_editor_hint():
		return

	for child: Node in _launchers.get_children():
		_connect_launcher(child)
	_launchers.child_entered_tree.connect(_connect_launcher)
	_windows.resized.connect(_resize_windows)
	get_viewport().gui_focus_changed.connect(_on_focus_changed)
	get_window().focus_exited.connect(_launchers.cancel_drag)
	_normal_clock_color = _clock.get_theme_color("font_color")
	%EnergyIcon.draw.connect(_draw_energy_icon)
	PlayerStats.changed.connect(_update_energy)
	_update_energy()
	GameClock.resume_timeline()
	GameClock.minute_changed.connect(_update_clock)
	_update_clock(GameClock.get_absolute_minutes())
	theme = light_theme
	_configure_return()
	if login_scene != null:
		$Display/DesktopItems.hide()
		_windows.hide()
		$Display/Taskbar.hide()
		_login = login_scene.instantiate() as Control
		_login.theme = _taskbar.theme
		_display.add_child(_login)
		_login.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_login.z_index = 10
		_login.authenticated.connect(_unlock_desktop)
	_startup_sound.play()
	_boot_cover.show()
	var boot := create_tween()
	boot.tween_property(_boot_cover, "color:a", 0.0, BOOT_SECONDS)
	boot.finished.connect(_finish_boot)


func _finish_boot() -> void:
	_boot_cover.hide()
	if not is_instance_valid(_login):
		_focus_launcher(null)


func _input(event: InputEvent) -> void:
	if Engine.is_editor_hint() or not is_node_ready():
		return
	if _boot_cover.visible:
		get_viewport().set_input_as_handled()
		return
	if is_instance_valid(_login):
		return
	if event is InputEventMouse and not is_instance_valid(_exam_window):
		var hit := _window_at(event.position)
		if event is InputEventMouseButton and event.pressed and hit != null:
			_activate_window(hit)
		var over_taskbar := _taskbar.is_visible_in_tree() and _taskbar.get_global_rect().has_point(event.position)
		if _launchers.handle_pointer(event, hit != null or over_taskbar):
			get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_W and event.ctrl_pressed and is_instance_valid(_active_window):
			_close_window(_active_window)
			get_viewport().set_input_as_handled()


func _refresh_wallpaper() -> void:
	if not is_node_ready():
		return
	_wallpaper.texture = wallpaper_texture
	_wallpaper.visible = wallpaper_texture != null
	var shader_material := _wallpaper.material as ShaderMaterial
	shader_material.set_shader_parameter("pixel_columns", float(wallpaper_pixel_columns))
	shader_material.set_shader_parameter("color_levels", float(wallpaper_color_levels))


func _update_energy() -> void:
	var percentage := roundi(PlayerStats.get_energy() / PlayerStats.ENERGY_MAX * 100.0)
	%Energy.text = "%d%%" % percentage
	%Energy.accessibility_name = "Energi %d percent" % percentage


func _draw_energy_icon() -> void:
	var icon: Control = %EnergyIcon
	icon.draw_set_transform(Vector2(1, (icon.size.y - 14.0) * 0.5))
	icon.draw_colored_polygon(PackedVector2Array([
		Vector2(6, 0), Vector2(1, 8), Vector2(5, 8),
		Vector2(4, 14), Vector2(12, 5), Vector2(7, 5)
	]), Color("#f2c46d"))


func _update_clock(absolute_minutes: int) -> void:
	_clock.text = "Day %d   %s" % [GameClock.get_day(), GameClock.get_formatted_time()]
	var since_late := posmod(absolute_minutes - 23 * 60, GameClock.MINUTES_PER_DAY)
	var blend := clampf(minf(since_late / 180.0, (420 - since_late) / 240.0), 0.0, 1.0)
	_clock.add_theme_color_override("font_color", _normal_clock_color.lerp(LATE_CLOCK_COLOR, blend))


func _configure_return() -> void:
	if get_tree().has_meta(RETURN_CONTEXT):
		var context: Variant = get_tree().get_meta(RETURN_CONTEXT)
		get_tree().remove_meta(RETURN_CONTEXT)
		if context is Dictionary:
			return_scene = context.get("scene", return_scene)
			return_spawn = context.get("spawn", return_spawn)
	_turn_off.disabled = return_scene.is_empty()
	_turn_off.text = return_label
	_turn_off.tooltip_text = "No return scene configured." if return_scene.is_empty() else return_label
	_turn_off.pressed.connect(_request_turn_off)
	SceneTransition.transition_finished.connect(_on_return_finished)


func _request_turn_off() -> void:
	if _turning_off or SceneTransition.is_active() or return_scene.is_empty():
		return
	_turning_off = true
	_turn_off.disabled = true
	_launchers.cancel_drag()
	SceneTransition.change_scene(return_scene, return_spawn)


func _on_return_finished(error: Error) -> void:
	if not _turning_off:
		return
	_turning_off = false
	_turn_off.disabled = false
	if error != OK:
		%ReturnError.dialog_text = "Could not return. " + error_string(error)
		%ReturnError.popup_centered_clamped(Vector2i(340, 0))


func _connect_launcher(child: Node) -> void:
	var launcher := child as Launcher
	if launcher != null and not launcher.open_requested.is_connected(_open_launcher):
		launcher.open_requested.connect(_open_launcher)


func _open_launcher(button: Button) -> void:
	var launcher := button as Launcher
	if _boot_cover.visible or is_instance_valid(_login) or is_instance_valid(_exam_window) or _launchers.suppresses_activation(launcher):
		return
	var window: AppWindow = _open_windows.get(launcher)
	if not is_instance_valid(window):
		var app: Control = launcher.create_app()
		if app == null:
			return
		window = APP_WINDOW_SCENE.instantiate() as AppWindow
		var cascade: float = float(_windows.get_child_count() % 7) * 36.0
		var left: float = 300.0 if _windows.size.x >= 900.0 else 24.0
		window.position = Vector2(left + cascade, 52.0 + cascade)
		_windows.add_child(window)
		if app.has_method("set_attachment_provider"):
			app.call("set_attachment_provider", _collect_attachments)
		if app.has_method("set_exam_host"):
			app.call("set_exam_host", _display)
		window.set_content(launcher.display_title, app)
		if app.has_signal("open_requested"):
			app.connect("open_requested", _open_launcher)
		if app.has_signal("exam_mode_changed"):
			app.connect("exam_mode_changed", _set_exam_mode.bind(window))
		var release_launcher := _release_launcher.bind(launcher)
		if not launcher.tree_exiting.is_connected(release_launcher):
			launcher.tree_exiting.connect(release_launcher, CONNECT_ONE_SHOT)
		window.set_initial_size(launcher.preferred_window_size, launcher.minimum_window_size)
		window.fit_within(_windows.size)
		window.close_requested.connect(_close_window)
		window.tree_exited.connect(_on_window_removed.bind(window), CONNECT_ONE_SHOT)
		_open_windows[launcher] = window

	_activate_window(window)
	window.focus_title()


func _collect_attachments() -> Array[Dictionary]:
	var attachments: Array[Dictionary] = []
	for child: Node in _launchers.get_children():
		var launcher := child as Launcher
		if launcher == null:
			continue
		var metadata := launcher.get_attachment_metadata()
		if not metadata.is_empty():
			metadata["source"] = "Desktop"
			attachments.append(metadata)
		if launcher is FileManagerLauncher:
			var window: Variant = _open_windows.get(launcher)
			var content: Control = window.get_content() if is_instance_valid(window) else null
			for item: Dictionary in launcher.collect_attachments(content):
				if item not in attachments:
					attachments.append(item)
	return attachments


func _unlock_desktop() -> void:
	_display.remove_child(_login)
	_login.queue_free()
	_login = null
	$Display/DesktopItems.show()
	_windows.show()
	$Display/Taskbar.show()
	_focus_launcher(null)


func _release_launcher(launcher: Launcher) -> void:
	_open_windows.erase(launcher)


func _on_window_removed(window: AppWindow) -> void:
	var launcher: Launcher = _open_windows.find_key(window)
	if launcher != null:
		_open_windows.erase(launcher)
	if _active_window == window:
		_active_window = null
	if _exam_window == window:
		_set_exam_mode(false, window)


func _window_at(point: Vector2) -> AppWindow:
	for index: int in range(_windows.get_child_count() - 1, -1, -1):
		var window := _windows.get_child(index) as AppWindow
		var local_point: Vector2 = window.get_global_transform_with_canvas().affine_inverse() * point
		if Rect2(Vector2.ZERO, window.size).has_point(local_point):
			return window
	return null


func _activate_window(window: AppWindow) -> void:
	if is_instance_valid(_exam_window) and window != _exam_window:
		return
	if window == _active_window:
		return
	if is_instance_valid(_active_window):
		_active_window.set_active(false)
	_windows.move_child(window, -1)
	_active_window = window
	window.set_active(true)


func _set_exam_mode(active: bool, window: AppWindow) -> void:
	if active:
		if is_instance_valid(_exam_window):
			return
		_activate_window(window)
		_exam_window = window
	elif _exam_window == window:
		_exam_window = null
	else:
		return
	if not _windows.is_inside_tree():
		return
	_launchers.cancel_drag()
	$Display/DesktopItems.visible = not active
	$Display/Taskbar.visible = not active
	_windows.visible = not active
	if window.is_inside_tree():
		window.set_close_enabled(not active)
	if not active:
		_restore_desktop_focus.call_deferred()


func _restore_desktop_focus() -> void:
	if not is_inside_tree() or not _windows.is_visible_in_tree():
		return
	var focus := get_viewport().gui_get_focus_owner()
	if is_instance_valid(focus) and focus.is_visible_in_tree():
		return
	if _windows.get_child_count() > 0:
		var front := _windows.get_child(-1) as AppWindow
		_activate_window(front)
		front.focus_title()
	else:
		_focus_launcher(null)


func _on_focus_changed(control: Control) -> void:
	var ancestor: Node = control
	while ancestor != null and ancestor != self:
		if ancestor is AppWindow:
			_activate_window(ancestor)
			return
		ancestor = ancestor.get_parent()


func _close_window(control: Control) -> void:
	if is_instance_valid(_exam_window):
		return
	var window := control as AppWindow
	var opener: Launcher = _open_windows.find_key(window)
	_open_windows.erase(opener)
	var was_active: bool = window == _active_window
	if was_active:
		_active_window = null
	_windows.remove_child(window)
	window.queue_free()

	if was_active:
		if _windows.get_child_count() > 0:
			var front := _windows.get_child(-1) as AppWindow
			_activate_window(front)
			front.focus_title()
		else:
			_focus_launcher(opener)


func _resize_windows() -> void:
	for window: AppWindow in _windows.get_children():
		window.fit_within(_windows.size)


func _focus_launcher(preferred: Launcher) -> void:
	if is_instance_valid(preferred) and preferred.is_visible_in_tree() and not preferred.disabled:
		preferred.grab_focus()
		return
	for child: Node in _launchers.get_children():
		var launcher := child as Launcher
		if launcher != null and launcher.is_visible_in_tree() and not launcher.disabled:
			launcher.grab_focus()
			return
