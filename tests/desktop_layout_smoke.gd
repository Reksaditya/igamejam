extends SceneTree

const Launcher = preload("res://scripts/interaction/desktop/desktop_launcher.gd")
const IconGrid = preload("res://scripts/interaction/desktop/desktop_icon_grid.gd")


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await _test_scattered_desktop()
	await _test_centered_browser_and_library()
	print("PASS: scattered desktop layout, resize reflow, drag/box-select, and centered Library/web pages")
	quit()


func _test_scattered_desktop() -> void:
	var desktop_scene := load("res://scenes/interaction/desktop/desktop.tscn") as PackedScene
	var desktop := desktop_scene.instantiate() as Control
	desktop.login_scene = null
	root.add_child(desktop)
	desktop.set_anchors_preset(Control.PRESET_TOP_LEFT)
	desktop.size = Vector2(1152.0, 648.0)
	await _settle()
	while desktop._boot_cover.visible:
		await process_frame

	var grid := desktop.get_node("%Launchers") as IconGrid
	assert(grid._cells.size() == 5, "Desktop should lay out all five launchers")

	var seen_cells: Dictionary[Vector2i, bool] = {}
	var has_right_scatter := false
	for icon: Launcher in grid._cells:
		var cell: Vector2i = grid._cells[icon]
		assert(not seen_cells.has(cell), "All icons must have distinct cells")
		seen_cells[cell] = true
		if cell.x >= 3:
			has_right_scatter = true
		assert(grid._visible_grid().encloses(icon.get_rect()), "Wide icon must stay inside visible grid: %s" % icon.name)
	assert(has_right_scatter, "Scattered desktop layout must spread icons beyond left columns")

	# Narrow window resize: 460x648 -> 3 columns, no collisions, all in-bounds.
	desktop.size = Vector2(460.0, 648.0)
	await _settle()
	var narrow_cols: int = grid._column_count()
	assert(narrow_cols == 3, "Expected 3 columns at 460px width, got %d" % narrow_cols)
	var narrow_cells: Dictionary[Vector2i, bool] = {}
	for icon: Launcher in grid._cells:
		var cell: Vector2i = grid._cells[icon]
		assert(cell.x >= 0 and cell.x < narrow_cols and cell.y >= 0, "Narrow cell out of range")
		assert(not narrow_cells.has(cell), "Narrow cells must not collide")
		narrow_cells[cell] = true

	# Wide restore: un-dragged icons return to their wide scattered coordinates.
	desktop.size = Vector2(1152.0, 648.0)
	await _settle()
	var project := grid.get_node("ProjectLauncher") as Launcher
	assert(grid._cells[project] == Vector2i(5, 0), "ProjectLauncher should return to its scattered cell (5, 0) when wide")

	# Simulate pointer drag of NotepadLauncher to cell (2, 2).
	var notepad := grid.get_node("NotepadLauncher") as Launcher
	var start_pos := grid.get_global_transform_with_canvas() * (notepad.position + Vector2(24.0, 24.0))
	var target_pos := grid.get_global_transform_with_canvas() * (grid._cell_origin(Vector2i(2, 2)) + Vector2(24.0, 24.0))
	_pointer_press(grid, start_pos, true)
	_pointer_move(grid, target_pos, MOUSE_BUTTON_MASK_LEFT)
	assert(grid._dragging, "Pointer drag beyond threshold must activate icon drag")
	_pointer_press(grid, target_pos, false)
	assert(grid._cells[notepad] == Vector2i(2, 2), "Dropped icon must snap to target cell (2, 2)")
	assert(grid._custom_cells[notepad] == Vector2i(2, 2), "Dropped cell must be stored as custom cell")

	# Resize / re-layout preserves custom dragged cell.
	desktop.size = Vector2(1024.0, 648.0)
	await _settle()
	assert(grid._cells[notepad] == Vector2i(2, 2), "User-dragged cell must persist across layout updates")

	# Simulate box selection over WordExplorerLauncher.
	var explorer := grid.get_node("WordExplorerLauncher") as Launcher
	var explorer_rect := explorer.get_rect()
	var box_start := grid.get_global_transform_with_canvas() * (explorer_rect.position - Vector2(8.0, 8.0))
	var box_end := grid.get_global_transform_with_canvas() * (explorer_rect.end + Vector2(8.0, 8.0))
	assert(grid.handle_pointer(_make_mouse_button(box_start, true), false))
	assert(grid._selecting)
	_pointer_move(grid, box_end, MOUSE_BUTTON_MASK_LEFT)
	assert(explorer._box_selected, "Box selection must highlight intersecting launcher")
	_pointer_press(grid, box_end, false)
	assert(not grid._selecting)

	# Dynamically add a launcher without an explicit default_cell.
	var extra := Launcher.new()
	extra.display_title = "Extra App"
	grid.add_child(extra)
	await _settle()
	assert(grid._cells.has(extra), "Dynamically added launcher must be placed")
	var unique_after_add: Dictionary[Vector2i, bool] = {}
	for cell: Vector2i in grid._cells.values():
		assert(not unique_after_add.has(cell), "Added launcher must not collide with existing icons")
		unique_after_add[cell] = true

	desktop.queue_free()
	await _settle()


func _test_centered_browser_and_library() -> void:
	var host := Control.new()
	host.size = Vector2(1080.0, 648.0)
	root.add_child(host)

	var explorer_scene := load("res://scenes/interaction/desktop/word_explorer.tscn") as PackedScene
	var explorer := explorer_scene.instantiate()
	explorer.loading_seconds = 0.0
	explorer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	host.add_child(explorer)
	await _settle()

	# Homework tab (active by default: start_tab = 1).
	var homework_tab = explorer._active
	assert(explorer._tabs.size() == 2 and homework_tab.address == "www.redlineuni.com")
	explorer._navigate("https://WWW.HOMEWORKPLACE.COM/")
	assert(homework_tab.address == "www.redlineuni.com")
	explorer._open_new_tab()
	explorer.get_node("%Home").pressed.emit()
	assert(explorer._active.address == "www.redlineuni.com")
	explorer._close_tab(explorer._active)
	explorer._select_tab(homework_tab)
	await _settle()
	assert(homework_tab.page.get_theme_constant("margin_left") > 22, "Wide browser should center content with side margins > 22")
	assert(homework_tab.page.get_theme_constant("margin_left") == homework_tab.page.get_theme_constant("margin_right"))
	var homework_home := homework_tab.page.get_child(0) as Control
	assert(homework_home.size.x > 300.0 and homework_home.size.x <= 682.0, "Web page width should stay within readable centered max width")

	# Switch to Library tab (tab 0).
	explorer._select_tab(explorer._tabs[0])
	await _settle()
	var study_tab = explorer._active
	var study_home := study_tab.page.get_child(0) as Control
	var books := study_home.get_node("%Books") as FlowContainer
	assert(books.alignment == FlowContainer.ALIGNMENT_CENTER, "Library books shelf must be centered")
	assert(books.last_wrap_alignment == FlowContainer.LAST_WRAP_ALIGNMENT_CENTER, "Last wrapped row must be centered")
	assert(books.get_child_count() == 5, "Library should render all 5 configured books")

	# Open a Blueprint book reading view and verify passages wrap cleanly without zero-width collapse.
	var sorter_card := books.get_child(1)
	var sorter_button := sorter_card.get_node("%Study") as Button
	sorter_button.pressed.emit()
	await _settle()
	var reading := study_home.get_node("%Reading") as Control
	assert(reading.visible, "Reading view must open when selecting the Core Drive manual")
	var passages := study_home.get_node("%Passages") as VBoxContainer
	assert(passages.get_child_count() >= 1)
	var first_paragraph := passages.get_child(0) as Label
	assert(first_paragraph.size.x > 200.0 and first_paragraph.size.y > 16.0, "Reading paragraph must not collapse horizontally")

	# Narrow browser viewport: margins shrink cleanly down to 22 without clipping.
	host.size = Vector2(430.0, 500.0)
	await _settle()
	assert(study_tab.page.get_theme_constant("margin_left") == 22, "Narrow browser must clamp side margins to 22px")
	assert(first_paragraph.size.x > 250.0, "Reading paragraph must still use full available narrow width")

	host.queue_free()
	await _settle()


func _make_mouse_button(pos: Vector2, pressed: bool) -> InputEventMouseButton:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = pressed
	ev.position = pos
	return ev


func _pointer_press(grid: Control, pos: Vector2, pressed: bool) -> void:
	grid.handle_pointer(_make_mouse_button(pos, pressed), false)


func _pointer_move(grid: Control, pos: Vector2, mask: int) -> void:
	var ev := InputEventMouseMotion.new()
	ev.position = pos
	ev.button_mask = mask as MouseButtonMask
	grid.handle_pointer(ev, false)


func _settle() -> void:
	for _i: int in range(4):
		await process_frame
