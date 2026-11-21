@tool
extends Control

const Launcher = preload("res://scripts/interaction/desktop/desktop_launcher.gd")
const FileManagerLauncher = preload("res://scripts/interaction/desktop/file_manager_launcher.gd")
const IconGrid = preload("res://scripts/interaction/desktop/desktop_icon_grid.gd")
const AppWindow = preload("res://scripts/interaction/desktop/app_window.gd")
const RETURN_CONTEXT := &"desktop_return_context"
const APP_WINDOW_SCENE: PackedScene = preload("res://scenes/interaction/desktop/app_window.tscn")

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
var _turning_off := false

@export_group("Login")
@export var login_scene: PackedScene = preload("res://scenes/interaction/desktop/login_screen.tscn")

@export_group("Themes")
@export var light_theme: Theme

@export_group("Return")
@export_file("*.tscn") var return_scene: String
@export var return_spawn: StringName

@onready var _wallpaper: TextureRect = $Wallpaper
@onready var _launchers: IconGrid = %Launchers
@onready var _windows: Control = $Windows
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
	GameClock.minute_changed.connect(_update_clock)
	_update_clock(GameClock.get_absolute_minutes())
	theme = light_theme
	_configure_return()
	if login_scene != null:
		$DesktopItems.hide()
		_windows.hide()
		$Taskbar.hide()
		_login = login_scene.instantiate() as Control
		_login.theme = $Taskbar.theme
		add_child(_login)
		_login.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_login.z_index = 10
		_login.authenticated.connect(_unlock_desktop)
		_startup_sound.play()
	else:
		_focus_launcher.call_deferred(null)


func _input(event: InputEvent) -> void:
	if Engine.is_editor_hint() or not is_node_ready() or is_instance_valid(_login):
		return
	if event is InputEventMouse and not is_instance_valid(_exam_window):
		var hit: AppWindow
		if event is InputEventMouseButton and event.pressed:
			hit = _window_at(event.position)
			if hit != null:
				_activate_window(hit)
		_launchers.handle_pointer(event, hit != null)
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


func _update_clock(_absolute_minutes: int) -> void:
	_clock.text = "Day %d   %s" % [GameClock.get_day(), GameClock.get_formatted_time()]


func _configure_return() -> void:
	if get_tree().has_meta(RETURN_CONTEXT):
		var context: Variant = get_tree().get_meta(RETURN_CONTEXT)
		get_tree().remove_meta(RETURN_CONTEXT)
		if context is Dictionary:
			return_scene = context.get("scene", return_scene)
			return_spawn = context.get("spawn", return_spawn)
	_turn_off.disabled = return_scene.is_empty()
	_turn_off.tooltip_text = "No return scene configured." if return_scene.is_empty() else "Return to the movement scene"
	_turn_off.pressed.connect(_request_turn_off)
	SceneTransition.transition_finished.connect(_on_return_finished)


func _request_turn_off() -> void:
	if _turning_off or SceneTransition.is_active() or return_scene.is_empty():
		return
	_turning_off = true
	_turn_off.disabled = true
	_launchers.cancel_drag()
	var spawn := return_spawn if not return_spawn.is_empty() else &"InitialSpawn"
	SceneTransition.change_scene(return_scene, spawn)


func _on_return_finished(error: Error) -> void:
	if not _turning_off:
		return
	_turning_off = false
	_turn_off.disabled = false
	if error != OK:
		%ReturnError.dialog_text = "Could not return to the movement scene. " + error_string(error)
		%ReturnError.popup_centered_clamped(Vector2i(340, 0))


func _connect_launcher(child: Node) -> void:
	var launcher := child as Launcher
	if launcher != null and not launcher.open_requested.is_connected(_open_launcher):
		launcher.open_requested.connect(_open_launcher)


func _open_launcher(button: Button) -> void:
	var launcher := button as Launcher
	if is_instance_valid(_login) or is_instance_valid(_exam_window) or _launchers.suppresses_activation(launcher):
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
			attachments.append_array(launcher.collect_attachments(content))
	return attachments


func _unlock_desktop() -> void:
	remove_child(_login)
	_login.queue_free()
	_login = null
	$DesktopItems.show()
	_windows.show()
	$Taskbar.show()
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
	$DesktopItems.visible = not active
	$Taskbar.visible = not active
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
