extends Resource

## Blueprint mapping for the 2-semester x 12-day loop:
## Index 0: Sem 1 Midterm (Hari 6), Index 1: Sem 1 Final (Hari 12),
## Index 2: Sem 2 Midterm (Hari 6), Index 3: Sem 2 Final (Hari 12).
@export var semester_blueprint_ids := PackedStringArray(["core_drive", "sediment_sorter", "sieve_shaker", "core_centrifuge"])
@export var semester_blueprint_days := PackedInt32Array([1, 7, 1, 7])
@export var semester_blueprint_deadlines := PackedInt32Array([6, 12, 6, 12])
@export_range(0, 1440, 1, "suffix:min") var one_missing_minutes := 60
@export_range(0, 1440, 1, "suffix:min") var two_missing_minutes := 120


func blueprint_for_half(semester: int, half: int) -> String:
	var idx := (semester - 1) * 2 + (half - 1)
	if semester < 1 or semester > 2 or half < 1 or half > 2 or idx < 0 or idx >= semester_blueprint_ids.size():
		return ""
	return semester_blueprint_ids[idx]


func blueprint_for(semester: int) -> String:
	return blueprint_for_half(semester, 1)


func unlock_day_for_half(semester: int, half: int) -> int:
	var idx := (semester - 1) * 2 + (half - 1)
	if idx < 0 or idx >= semester_blueprint_days.size():
		return 1
	return semester_blueprint_days[idx]


func deadline_day_for_half(semester: int, half: int) -> int:
	var idx := (semester - 1) * 2 + (half - 1)
	if idx < 0 or idx >= semester_blueprint_deadlines.size():
		return 6 if half == 1 else 12
	return semester_blueprint_deadlines[idx]
