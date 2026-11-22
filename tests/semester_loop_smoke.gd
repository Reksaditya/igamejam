extends SceneTree

const Curriculum = preload("res://scripts/academic/curriculum.gd")


func _initialize() -> void:
	set_meta(&"suppress_world_events", true)
	_run.call_deferred()


func _run() -> void:
	var clock := root.get_node("GameClock")
	var stats := root.get_node("PlayerStats")
	var career := root.get_node("CareerProgress")
	var saves := root.get_node("GameSave")
	var blueprints := root.get_node("ProjectBlueprints")

	# 1. Question bank integrity check (EVERY question in Sem 1 & Sem 2).
	for sem: int in [1, 2]:
		var bank := Curriculum.load_question_bank(sem)
		assert(bank.size() >= 150, "Expected rich bank for Sem %d, got %d" % [sem, bank.size()])
		var math_count := 0
		var machine_count := 0
		var seen_ids: Dictionary[String, bool] = {}
		for q: Dictionary in bank:
			var id := str(q.get("id", ""))
			assert(not id.is_empty() and not seen_ids.has(id), "Duplicate or empty id in Sem %d" % sem)
			seen_ids[id] = true
			var prompt := str(q.get("prompt", "")).strip_edges()
			assert(prompt.length() >= 8, "Empty/short prompt: " + id)
			assert(not prompt.contains("$") and not prompt.contains("\\"), "Raw LaTeX in prompt: " + id)
			assert(not prompt.contains("  "), "Blank stripped gap in prompt: " + id)
			var choices: Array = q.get("choices", [])
			assert(choices.size() == 4, "Need 4 choices: " + id)
			var unique_choices: Dictionary[String, bool] = {}
			for c: Variant in choices:
				var cs := str(c).strip_edges()
				assert(not cs.is_empty(), "Blank choice in " + id)
				assert(not cs.contains("$") and not cs.contains("\\"), "Raw LaTeX in choice: " + id)
				unique_choices[cs.to_lower()] = true
			assert(unique_choices.size() == 4, "Duplicate choices in " + id)
			var cidx := int(q.get("correct_index", -1))
			assert(cidx >= 0 and cidx <= 3, "Invalid correct_index in " + id)
			var topic := str(q.get("topic", ""))
			assert(topic in ["math", "machine"], "Invalid topic in " + id)
			if topic == "math":
				math_count += 1
			else:
				machine_count += 1
		assert(math_count >= 50 and machine_count >= 100, "Topic balance low in Sem %d: math=%d machine=%d" % [sem, math_count, machine_count])
		# Verify balanced non-repeating 10-question draw
		var draw := Curriculum.questions(sem, 1, "tugas", 10)
		assert(draw.size() == 10, "Draw size must be 10")
		var draw_ids: Dictionary[String, bool] = {}
		for q: Dictionary in draw:
			draw_ids[str(q.id)] = true
		assert(draw_ids.size() == 10, "Drawn questions must be non-repeating")
		print("BANK OK Sem %d: total=%d (math=%d, machine=%d)" % [sem, bank.size(), math_count, machine_count])

	# 2. New Game starts in bedroom (dorm_room210.tscn) with exact GDD 4.4 stats & Sem 1 Day 1 06:00.
	assert(saves.start_new_game("Yohan") == OK)
	await scene_changed
	await process_frame
	await process_frame
	assert(current_scene.scene_file_path == "res://scenes/movement/dorm_room210.tscn", "New game must start in dorm_room210.tscn, got: " + current_scene.scene_file_path)
	assert(is_equal_approx(stats.get_energy(), 100.0), "Starting Energi must be 100.0")
	assert(is_equal_approx(stats.get_sanity(), 40.0), "Starting Kewarasan must be 40.0")
	assert(is_equal_approx(stats.get_gpa(), 0.0), "Starting IPK must be 0.0")
	assert(clock.get_day() == 1 and clock.get_semester() == 1 and clock.get_day_in_semester() == 1)
	assert(clock.get_formatted_time() == "06:00")
	var profile := current_scene.get_node("PlayerProfile")
	assert(profile._hud_semester.text == "SEM 1")
	assert(profile._hud_day.text == "HARI 1/12")

	# 3. Calendar mapping check (Day 1..12 = Sem 1, Day 13..24 = Sem 2).
	assert(Curriculum.semester_for_day(1) == 1 and Curriculum.day_in_semester(1) == 1)
	assert(Curriculum.semester_for_day(6) == 1 and Curriculum.day_in_semester(6) == 6)
	assert(Curriculum.semester_for_day(12) == 1 and Curriculum.day_in_semester(12) == 12)
	assert(Curriculum.semester_for_day(13) == 2 and Curriculum.day_in_semester(13) == 1)
	assert(Curriculum.semester_for_day(18) == 2 and Curriculum.day_in_semester(18) == 6)
	assert(Curriculum.semester_for_day(24) == 2 and Curriculum.day_in_semester(24) == 12)

	# 4. GDD 4.4 Energi costs, Kewarasan +10, Blur at >= 80, Late-sleep formula, Energi <= 0 rules.
	assert(career.begin_activity("class", "test_class_1") == OK)
	assert(is_equal_approx(stats.get_energy(), 85.0))
	assert(is_equal_approx(stats.get_sanity(), 50.0))
	assert(career.begin_activity("tugas", "test_tugas_1") == OK)
	assert(is_equal_approx(stats.get_energy(), 80.0))
	assert(is_equal_approx(stats.get_sanity(), 60.0))
	assert(career.begin_activity("kuis", "test_kuis_1") == OK)
	assert(is_equal_approx(stats.get_energy(), 75.0))
	assert(is_equal_approx(stats.get_sanity(), 70.0))
	assert(career.begin_activity("uts", "test_uts_1") == OK)
	assert(is_equal_approx(stats.get_energy(), 45.0))
	assert(is_equal_approx(stats.get_sanity(), 80.0))
	var wf := current_scene.get_node("WorldFeatures")
	assert(wf._blur.visible, "Blur must activate when Kewarasan >= 80")
	assert(wf._blur.mouse_filter == Control.MOUSE_FILTER_IGNORE)
	assert(career.begin_activity("project", "test_proj_1") == OK)
	assert(is_equal_approx(stats.get_energy(), 25.0))
	assert(is_equal_approx(stats.get_sanity(), 90.0))

	# Energi <= 0 blocks project, allows class (sleep in class).
	stats.set_energy(0.0)
	assert(career.begin_activity("project", "test_proj_blocked") == ERR_UNAVAILABLE)
	assert(career.begin_activity("class", "test_class_sleep") == OK)

	# Late-sleep formula verification (<=22:00 -> 100, 23:00 -> 90, 00:00 -> 80, 01:00 -> 70) + Kewarasan -> 50.
	assert(is_equal_approx(career.wake_energy_for_minute(21 * 60), 100.0))
	assert(is_equal_approx(career.wake_energy_for_minute(22 * 60), 100.0))
	assert(is_equal_approx(career.wake_energy_for_minute(23 * 60), 90.0))
	assert(is_equal_approx(career.wake_energy_for_minute(0), 80.0))
	assert(is_equal_approx(career.wake_energy_for_minute(1 * 60), 70.0))
	clock.restore_save_state({"minutes": 23 * 60, "remainder": 0})
	assert(career.rest(8) == OK)
	assert(is_equal_approx(stats.get_energy(), 90.0), "23:00 sleep must wake at 90 Energi")
	assert(is_equal_approx(stats.get_sanity(), 50.0), "Sleep must reset Kewarasan to 50 (Normal)")
	assert(not wf._blur.visible, "Blur must turn off when Kewarasan < 80")

	# 5. Exact grade cutoffs (85 A, 75 B, 65 C, 50 D, <50 E) & Ending rules.
	assert(career.letter_grade_for(100.0) == "A")
	assert(career.letter_grade_for(85.0) == "A")
	assert(career.letter_grade_for(84.9) == "B")
	assert(career.letter_grade_for(75.0) == "B")
	assert(career.letter_grade_for(74.9) == "C")
	assert(career.letter_grade_for(65.0) == "C")
	assert(career.letter_grade_for(64.9) == "D")
	assert(career.letter_grade_for(50.0) == "D")
	assert(career.letter_grade_for(49.9) == "E")
	assert(career.ending_for(3.5, true) == "happy")
	assert(career.ending_for(3.49, true) == "basic")
	assert(career.ending_for(3.8, false) == "bad")

	# 6. Split Blueprint math (0/2 = 0%, 1/2 = 15%, 2/2 = 30%) + 12-day rollover + idempotency.
	assert(saves.start_new_game("Yohan") == OK)
	await scene_changed
	await process_frame
	assert(career.record_result(1, 1, "tugas", 100.0) == OK)
	assert(career.record_result(1, 2, "tugas", 100.0) == OK)
	assert(career.record_result(1, 1, "kuis", 100.0) == OK)
	assert(career.record_result(1, 2, "kuis", 100.0) == OK)
	assert(career.record_result(1, 6, "uts", 100.0) == OK)
	assert(career.record_result(1, 12, "uas", 100.0) == OK)

	# 0/2 blueprints -> 70.0 (C, IPS 2.80)
	var b0: Dictionary = career.semester_breakdown(1)
	assert(is_equal_approx(b0.final_score, 70.0), "0/2 blueprints must score 70.0, got %.2f" % b0.final_score)
	assert(b0.letter_grade == "C" and is_equal_approx(b0.ips, 2.80))
	assert(is_equal_approx(stats.get_gpa(), 0.0), "IPK must stay 0.00 before Sem 1 finishes")

	# 1/2 blueprints (Sem 1 Midterm core_drive on Day 5 <= Day 6) -> 85.0 (A, IPS 3.40)
	clock.restore_save_state({"minutes": 4 * 1440 + 600, "remainder": 0}) # Day 5
	assert(career.complete_blueprint("core_drive") == OK)
	var b1: Dictionary = career.semester_breakdown(1)
	assert(is_equal_approx(b1.final_score, 85.0), "1/2 blueprints must score 85.0, got %.2f" % b1.final_score)
	assert(b1.letter_grade == "A" and is_equal_approx(b1.ips, 3.40))

	# 2/2 blueprints (Sem 1 Final sediment_sorter on Day 11 <= Day 12) -> 100.0 (A, IPS 4.00)
	clock.restore_save_state({"minutes": 10 * 1440 + 600, "remainder": 0}) # Day 11
	assert(career.is_assessment_overdue(1, 1, "tugas"), "Paruh 1 Tugas must be overdue on Day 11")
	assert(not career.is_assessment_overdue(1, 2, "tugas"), "Paruh 2 Tugas must NOT be overdue on Day 11")
	assert(career.complete_blueprint("sediment_sorter") == OK)
	var b2: Dictionary = career.semester_breakdown(1)
	assert(is_equal_approx(b2.final_score, 100.0), "2/2 blueprints must score 100.0, got %.2f" % b2.final_score)
	assert(b2.letter_grade == "A" and is_equal_approx(b2.ips, 4.00))

	# Advance to Sem 2 Day 1 (Day 13) -> triggers Sem 1 evaluation once!
	clock.restore_save_state({"minutes": 12 * 1440 + 360, "remainder": 0}) # Day 13 = Sem 2 Hari 1
	assert(career.semester() == 2 and career.day_in_semester() == 1)
	assert(career.state.evaluated_semesters.has("1"))
	assert(is_equal_approx(stats.get_gpa(), 4.0), "IPK after Sem 1 perfect must be 4.00")
	var khs1: Dictionary = career.get_pending_khs()
	assert(not khs1.is_empty() and int(khs1.semester) == 1)
	# Verify idempotency: re-evaluating Sem 1 returns identical snapshot without altering IPK.
	var khs1_again: Dictionary = career.evaluate_semester(1)
	assert(is_equal_approx(float(khs1_again.final_score), 100.0))
	assert(career.acknowledge_khs() == OK and career.get_pending_khs().is_empty())

	# Complete Sem 2 with 75.0 (B, IPS 3.00) -> average IPK = (4.0 + 3.0) / 2 = 3.50 -> Happy Ending!
	assert(career.record_result(2, 1, "tugas", 100.0) == OK)
	assert(career.record_result(2, 2, "tugas", 100.0) == OK)
	assert(career.record_result(2, 1, "kuis", 100.0) == OK)
	assert(career.record_result(2, 2, "kuis", 100.0) == OK)
	assert(career.record_result(2, 6, "uts", 100.0) == OK)
	assert(career.record_result(2, 12, "uas", 100.0) == OK)
	# Complete Sem 2 Midterm blueprint (sieve_shaker) on Day 15 <= 18 (+15%), skip Final (0%) -> 85.0 (IPS 3.40) -> IPK 3.70!
	clock.restore_save_state({"minutes": 14 * 1440 + 600, "remainder": 0}) # Day 15 = Sem 2 Hari 3
	assert(career.complete_blueprint("sieve_shaker") == OK)
	# Advance past Day 24 -> triggers Sem 2 evaluation & Happy Ending!
	clock.restore_save_state({"minutes": 24 * 1440 + 360, "remainder": 0})
	assert(career.state.evaluated_semesters.has("2"))
	assert(career.state.ending == "happy", "Expected happy ending with IPK %.2f, got %s" % [stats.get_gpa(), career.state.ending])
	assert(is_equal_approx(stats.get_gpa(), 3.70), "Expected IPK 3.70, got %.2f" % stats.get_gpa())

	print("PASS: 2-semester 12-day loop, dorm start, 439 Bank Soal questions, split 15%+15% blueprints, GDD 4.4 stats/blur, A-E cutoffs, KHS rollover & endings all verified!")
	quit()
