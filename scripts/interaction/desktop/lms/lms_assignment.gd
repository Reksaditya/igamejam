extends Resource

const Question = preload("res://scripts/interaction/desktop/lms/lms_question.gd")

enum Kind { QUIZ, ATTACHMENT }

@export var id: String
@export var title: String
@export var kind: Kind = Kind.QUIZ
@export var questions: Array[Question]
## Leave empty to use this item’s own ID for notebook entries.
@export var notebook_assignment_id: String

@export_group("Attachment")
@export_multiline var instructions: String
@export var accepted_filenames: PackedStringArray

@export_group("Schedule")
@export_range(1, 999, 1, "or_greater") var release_day: int = 1
@export_range(0, 23) var release_hour: int = 6
@export_range(0, 59) var release_minute: int = 0

@export_group("Deadline")
## Day 0 uses six days after release in a chapter, or no deadline for standalone items.
@export_range(0, 999, 1, "or_greater") var deadline_day: int = 0
@export_range(0, 23) var deadline_hour: int = 0
@export_range(0, 59) var deadline_minute: int = 0


func get_deadline_minutes() -> int:
	if deadline_day == 0:
		return -1
	return (deadline_day - 1) * 1440 + deadline_hour * 60 + deadline_minute


func get_release_minutes() -> int:
	return (release_day - 1) * 1440 + release_hour * 60 + release_minute


func get_chapter_deadline() -> int:
	var authored := get_deadline_minutes()
	return authored if authored >= 0 else get_release_minutes() + 6 * 1440


func get_notebook_id() -> String:
	return id if notebook_assignment_id.is_empty() else notebook_assignment_id
