class_name StudyBook
extends Resource

enum Reward { REVIEW, BLUEPRINT }

@export var book_id: String
@export var title: String
@export var cover_color: Color = Color("#7d2638")
@export_multiline var reading_text: String
@export var reward_type: Reward = Reward.REVIEW

@export_group("Review Reward")
@export var linked_note_ids: PackedStringArray

@export_group("Blueprint Reward")
@export var blueprint_id: String
