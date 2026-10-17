extends Control

const TYPE_DELAY := 0.025
const SCROLL_START_MARGIN := 130.0
const SCROLL_BOTTOM_MARGIN := 110.0

@onready var _story_scroll: ScrollContainer = $StoryScroll
@onready var _story_text: RichTextLabel = $StoryScroll/DocumentContent/StoryText

var ending_data: Dictionary = {}
var _is_revealing := false


func set_ending_data(data: Dictionary) -> void:
	ending_data = data.duplicate(true)


func can_advance() -> bool:
	return not _is_revealing


func _ready() -> void:
	_story_text.clear()
	var body := str(ending_data.get("body", ""))
	if body.strip_edges().is_empty():
		push_error("The ending data is missing its body text.")
		return

	_is_revealing = true
	_reveal_body(body)


func _reveal_body(body: String) -> void:
	for character_index in range(body.length()):
		_story_text.append_text(body.substr(character_index, 1))
		await get_tree().create_timer(TYPE_DELAY).timeout
		_follow_revealed_text()
	_is_revealing = false


func _follow_revealed_text() -> void:
	var viewport_height := _story_scroll.size.y
	if viewport_height <= 0.0:
		return

	var text_height := maxf(
		_story_text.size.y,
		_story_text.get_combined_minimum_size().y
	)
	if text_height < viewport_height - SCROLL_START_MARGIN:
		return

	var scroll_bar := _story_scroll.get_v_scroll_bar()
	var maximum_scroll := maxf(0.0, scroll_bar.max_value - scroll_bar.page)
	var target_scroll := maxf(
		0.0,
		text_height - viewport_height + SCROLL_BOTTOM_MARGIN
	)
	_story_scroll.scroll_vertical = roundi(minf(target_scroll, maximum_scroll))
