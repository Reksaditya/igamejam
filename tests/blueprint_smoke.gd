extends SceneTree


func _initialize() -> void:
	set_meta(&"suppress_world_events", true)
	_run.call_deferred()


func _run() -> void:
	var progress := root.get_node("BlueprintProgress")
	var reload_test := "--reload" in OS.get_cmdline_user_args()
	if reload_test:
		assert(progress.is_complete(), "Completed blueprint must survive a new session")
		assert(progress.get_placed_count() == 6)
		assert(progress.place_piece(0, 0) == ERR_INVALID_PARAMETER)
		print("PASS: blueprint reload and duplicate placement")
		quit()
		return
	assert(progress.get_placed_count() == 0, "Use an isolated APPDATA directory for this test")
	assert(progress.complete_study("unknown_lesson") == ERR_INVALID_PARAMETER)
	assert(progress.place_piece(0, 0) == ERR_INVALID_PARAMETER, "Locked pieces cannot be placed")
	var main := load("res://scenes/interaction/blueprint/project_access.tscn").instantiate() as Node
	root.add_child(main)
	await process_frame
	var access := main
	access._open()
	assert(paused, "Study window must pause movement")
	var workbench := access.get_node("StudyWindow/Panel/Margin/Scroll/Workbench")
	var popup: Window = workbench._popup
	workbench._answer(0)
	assert(not progress.has_piece(0), "Wrong answers cannot award pieces")
	workbench._answer(1)
	assert(progress.has_piece(0))
	assert(progress.complete_study("transmission_motor") == OK)
	assert(progress.place_piece(0, 1) == ERR_INVALID_PARAMETER, "Wrong slots cannot consume a piece")
	popup.open()
	popup._select(0)
	popup._place(1)
	assert(not progress.is_placed(0))
	popup._place(0)
	assert(progress.is_placed(0))
	popup.hide()
	popup.open()
	assert(popup._slots[0].silhouette == false, "Reopening must reflect saved placement")
	var completions: Array[String] = []
	progress.project_completed.connect(func(id: String) -> void: completions.append(id))
	for index: int in range(1, 6):
		workbench._show_lesson(index)
		workbench._answer(progress.PROJECT.lessons[index].correct_option)
		assert(progress.has_piece(index))
		popup._select(index)
		popup._place(index)
	assert(progress.is_complete())
	assert(completions.size() == 1, "Completion signal must fire exactly once")
	assert(progress.place_piece(5, 5) == ERR_INVALID_PARAMETER)
	popup.hide()
	access.get_node("StudyWindow").hide()
	assert(not paused, "Closing study must restore movement")
	main.queue_free()
	await process_frame
	var desktop := load("res://scenes/interaction/desktop/desktop.tscn").instantiate() as Control
	desktop.login_scene = null
	root.add_child(desktop)
	await process_frame
	var launcher := load("res://scenes/interaction/blueprint/blueprint_launcher.tscn").instantiate() as Button
	desktop.get_node("DesktopItems/Launchers").add_child(launcher)
	desktop._open_launcher(launcher)
	assert(desktop._open_windows.size() == 1)
	var app: Control = desktop._open_windows[launcher].get_content()
	app._popup.open()
	assert(app._popup._slots.size() == 6)
	app._popup.hide()
	desktop._close_window(desktop._open_windows[launcher])
	desktop.queue_free()
	await process_frame
	print("PASS: study, rewards, placement, reopen, completion, pause, desktop integration")
	quit()
