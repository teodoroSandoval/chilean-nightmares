extends Resource
class_name GameData

@export_category("Game Settings")
@export var grid_rise_interval: float = 10
@export var coin_speed_grab: float = 5000
@export var coin_speed_throw: float = 5000
@export var coin_speed_change: float = 2000
@export var time_per_letter_dialog: float = 0.04
@export var time_per_letter_request: float = 0.04

@export_category("Main Story")
@export var story_chapters: Array[StoryChapter]

@export_category("Requests")
@export var random_test_requests: Array[ClientRequest]
@export var requests_by_level: Array[Array]

func get_chapter(index: int) -> StoryChapter:
	return story_chapters[index]
func get_chapters_count() -> int:
	return story_chapters.size()

func get_random_requests_by_level(level: int) -> Array[ClientRequest]:
	return random_test_requests