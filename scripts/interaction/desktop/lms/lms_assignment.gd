extends Resource

const Question = preload("res://scripts/interaction/desktop/lms/lms_question.gd")

enum Kind { QUIZ, ATTACHMENT }

@export var id: String
@export var title: String
@export var kind: Kind = Kind.QUIZ
@export var questions: Array[Question]

@export_group("Attachment")
@export_multiline var instructions: String
@export var accepted_filenames: PackedStringArray

@export_group("Deadline")
## Day 0 means this assignment has no deadline.
@export_range(0, 999, 1, "or_greater") var deadline_day: int = 0
@export_range(0, 23) var deadline_hour: int = 0
@export_range(0, 59) var deadline_minute: int = 0


func get_deadline_minutes() -> int:
	if deadline_day == 0:
		return -1
	return (deadline_day - 1) * 1440 + deadline_hour * 60 + deadline_minute
