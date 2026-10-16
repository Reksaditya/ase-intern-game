extends Control

const MAX_PAGE_CHARACTERS := 300
const PAGE_BOTTOM_MARGIN := 20.0
const SKIP_HOLD_DURATION := 1.0
const SKIP_DECAY_RATE := 3.0
const SKIP_DOT_INTERVAL := 0.15
const SKIP_DOT_SEQUENCE: Array[int] = [0, 1, 2, 3, 2, 1]
const SKIP_DIM_MODULATE := Color(0.5, 0.5, 0.5, 0.2)
const SKIP_VIBRANT_MODULATE := Color(1.0, 1.0, 1.0, 1.0)

@onready var _paper_viewport: Control = $popup
@onready var _paper: Control = $popup/Paper
@onready var _continue_button: Button = $ContinueButton
@onready var _feed_indicator: ColorRect = $FeedIndicator
@onready var _report_label: Label = $popup/Paper/Label
@onready var _report_header: Label = $popup/Paper/header
@onready var _report_body: Label = $popup/Paper/PlaceholderText
@onready var _previous_page_button: Button = $PreviousPageButton
@onready var _next_page_button: Button = $NextPageButton
@onready var _page_indicator: Label = $PageIndicator
@onready var _skipping_label: Label = $SkippingLabel
@onready var _report_content: Array[CanvasItem] = [
	$popup/Paper/Label as CanvasItem,
	$popup/Paper/PlaceholderText as CanvasItem,
	$popup/Paper/line as CanvasItem,
	$popup/Paper/header as CanvasItem,
]
@onready var _page_controls: Array[CanvasItem] = [
	$PreviousPageButton as CanvasItem,
	$PageIndicator as CanvasItem,
	$NextPageButton as CanvasItem,
]

var _can_continue := false
var _report_revealed := false
var _pages: Array[String] = []
var _current_page_index := 0
var _paper_size := Vector2.ZERO
var _active_tween: Tween
var _is_escape_held := false
var _is_mouse_held := false
var _skip_hold_time := 0.0
var _skip_dot_timer := 0.0


func _ready() -> void:
	_paper_size = _paper_viewport.size
	var paper_size := _paper_size
	_paper_viewport.size.y = 0.0
	_continue_button.modulate.a = 0.0
	_reset_skip_state()
	# Let the sheet overlap the slot bezel while keeping the roller in front.
	move_child(_paper_viewport, $OutputSlot.get_index())
	for content in _report_content:
		content.visible = false
	for control in _page_controls:
		control.visible = false
	_previous_page_button.pressed.connect(_change_page.bind(-1))
	_next_page_button.pressed.connect(_change_page.bind(1))

	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var feed_tween := create_tween()
	_active_tween = feed_tween
	var revealed_height := 0.0
	while revealed_height < paper_size.y:
		revealed_height = minf(revealed_height + rng.randf_range(7.0, 19.0), paper_size.y)
		var step_duration := rng.randf_range(0.025, 0.075)
		var viewport_step := feed_tween.tween_property(
			_paper_viewport,
			"size:y",
			revealed_height,
			step_duration
		)
		viewport_step.set_trans(Tween.TRANS_LINEAR)
		feed_tween.parallel().tween_property(
			_paper,
			"position:y",
			rng.randf_range(-1.8, 1.8),
			step_duration
		).set_trans(Tween.TRANS_LINEAR)
		if rng.randf() < 0.4:
			feed_tween.tween_interval(rng.randf_range(0.015, 0.06))

	feed_tween.tween_property(_paper, "position:y", 0.0, 0.08).set_trans(Tween.TRANS_SINE)
	feed_tween.tween_callback(_on_printing_complete)


func _process(delta: float) -> void:
	if _can_continue:
		if _skipping_label and _skipping_label.visible:
			_reset_skip_state()
		return

	if _is_escape_held and not Input.is_key_pressed(KEY_ESCAPE):
		_is_escape_held = false
	if _is_mouse_held and not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_is_mouse_held = false

	var is_skip_pressing := _is_escape_held or _is_mouse_held
	if is_skip_pressing:
		_skip_hold_time += delta
		_skip_dot_timer += delta
		if _skip_hold_time >= SKIP_HOLD_DURATION:
			_skip_printing()
			return
	else:
		_skip_hold_time = maxf(0.0, _skip_hold_time - delta * SKIP_DECAY_RATE)
		if _skip_hold_time <= 0.0:
			_skip_dot_timer = 0.0

	_update_skipping_label(is_skip_pressing)


func set_report_text(report: Dictionary) -> void:
	var body := str(report.get("body", ""))
	if body.strip_edges().is_empty():
		push_error("The report must contain body text.")
		return

	_report_label.text = str(report.get("label", ""))
	_report_header.text = str(report.get("header", ""))
	_continue_button.text = str(report.get("continue_text", _continue_button.text))
	_pages = _split_report_into_pages(body)
	_current_page_index = 0
	_update_paper_page()


func _split_report_into_pages(body: String) -> Array[String]:
	var pages: Array[String] = []
	var current_page := ""
	var words := body.split(" ", true)
	for word_index in range(words.size()):
		var separator := " " if word_index > 0 else ""
		var word: String = words[word_index]
		var candidate := current_page + separator + word
		if _page_fits(candidate):
			current_page = candidate
			continue

		if not current_page.is_empty():
			pages.append(current_page + separator)
			current_page = ""

		if _page_fits(word):
			current_page = word
			continue

		var word_chunks := _split_unbroken_text(word)
		for chunk_index in range(word_chunks.size() - 1):
			pages.append(word_chunks[chunk_index])
		current_page = word_chunks.back()
	if not current_page.is_empty():
		pages.append(current_page)
	return pages


func _split_unbroken_text(text: String) -> Array[String]:
	var chunks: Array[String] = []
	var remaining := text
	while not remaining.is_empty():
		var chunk_length := mini(MAX_PAGE_CHARACTERS, remaining.length())
		while chunk_length > 1 and not _page_fits(remaining.left(chunk_length)):
			chunk_length -= 1
		chunks.append(remaining.left(chunk_length))
		remaining = remaining.substr(chunk_length)
	return chunks


func _page_fits(text: String) -> bool:
	if text.length() > MAX_PAGE_CHARACTERS:
		return false
	var font: Font = _report_body.label_settings.font
	var font_size: int = _report_body.label_settings.font_size
	var measured_size := font.get_multiline_string_size(text, font_size, _report_body.size.x)
	var available_height := _paper.size.y - _report_body.position.y - PAGE_BOTTOM_MARGIN
	return measured_size.y <= available_height


func _input(event: InputEvent) -> void:
	if event is InputEventKey:
		var key_event := event as InputEventKey
		if key_event.pressed and not key_event.echo:
			if key_event.keycode == KEY_A or key_event.keycode == KEY_LEFT:
				_change_page(-1)
				get_viewport().set_input_as_handled()
				return
			if key_event.keycode == KEY_D or key_event.keycode == KEY_RIGHT:
				_change_page(1)
				get_viewport().set_input_as_handled()
				return

	if _can_continue:
		return

	if event is InputEventKey:
		var key_event := event as InputEventKey
		if key_event.keycode == KEY_ESCAPE and not key_event.echo:
			_is_escape_held = key_event.pressed
			get_viewport().set_input_as_handled()
			return
	elif event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT:
			_is_mouse_held = mouse_event.pressed
			get_viewport().set_input_as_handled()
			return

	var should_block := false
	if event is InputEventKey:
		var key_event := event as InputEventKey
		should_block = key_event.pressed and not key_event.echo and (
			key_event.keycode == KEY_ENTER or key_event.keycode == KEY_KP_ENTER
		)
	if should_block:
		get_viewport().set_input_as_handled()


func _on_printing_complete() -> void:
	_feed_indicator.color = Color(0.48, 0.72, 0.43, 1.0)
	var exit_tween := create_tween()
	_active_tween = exit_tween
	exit_tween.tween_interval(0.3)
	exit_tween.tween_property(
		_paper_viewport,
		"position:y",
		get_viewport_rect().size.y + 100.0,
		0.7
	).set_trans(Tween.TRANS_LINEAR)
	exit_tween.tween_callback(_show_report_closeup)


func _show_report_closeup() -> void:
	var viewport_size := get_viewport_rect().size
	var paper_size := _paper_viewport.size
	var target_position := (viewport_size - paper_size) * 0.5
	target_position.y -= 30.0

	move_child(_paper_viewport, get_child_count() - 1)
	_paper_viewport.pivot_offset = paper_size * 0.5
	_paper_viewport.scale = Vector2.ONE
	_paper_viewport.position = Vector2(target_position.x, viewport_size.y + 100.0)
	for content in _report_content:
		content.visible = true
	_report_revealed = true
	_update_page_controls()

	var closeup_tween := create_tween()
	_active_tween = closeup_tween
	closeup_tween.set_parallel(true)
	closeup_tween.tween_property(
		_paper_viewport,
		"position",
		target_position,
		0.7
	).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	closeup_tween.tween_property(
		_paper_viewport,
		"scale",
		Vector2.ONE * 1.2,
		0.7
	).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	closeup_tween.chain().tween_callback(_finish_paper_presentation)


func _skip_printing() -> void:
	if _can_continue:
		return
	if _active_tween:
		_active_tween.kill()
		_active_tween = null

	_feed_indicator.color = Color(0.48, 0.72, 0.43, 1.0)
	_paper.position.y = 0.0
	_paper_viewport.size = _paper_size

	var viewport_size := get_viewport_rect().size
	var target_position := (viewport_size - _paper_size) * 0.5
	target_position.y -= 30.0

	move_child(_paper_viewport, get_child_count() - 1)
	_paper_viewport.pivot_offset = _paper_size * 0.5
	_paper_viewport.position = target_position
	_paper_viewport.scale = Vector2.ONE * 1.2
	for content in _report_content:
		content.visible = true
	_report_revealed = true
	_update_page_controls()
	_finish_paper_presentation()


func _update_skipping_label(is_skip_pressing: bool) -> void:
	if not is_skip_pressing and _skip_hold_time <= 0.0:
		_skipping_label.visible = false
		return
	_skipping_label.visible = true
	var dot_step := int(_skip_dot_timer / SKIP_DOT_INTERVAL) % SKIP_DOT_SEQUENCE.size()
	var dot_count: int = SKIP_DOT_SEQUENCE[dot_step]
	_skipping_label.text = "skipping" + ".".repeat(dot_count)
	var progress := clampf(_skip_hold_time / SKIP_HOLD_DURATION, 0.0, 1.0)
	_skipping_label.modulate = SKIP_DIM_MODULATE.lerp(SKIP_VIBRANT_MODULATE, progress)


func _reset_skip_state() -> void:
	_is_escape_held = false
	_is_mouse_held = false
	_skip_hold_time = 0.0
	_skip_dot_timer = 0.0
	if _skipping_label:
		_skipping_label.visible = false
		_skipping_label.text = "skipping"
		_skipping_label.modulate = SKIP_DIM_MODULATE


func _change_page(direction: int) -> void:
	if not _can_continue:
		return
	var next_page_index := _current_page_index + direction
	if next_page_index < 0 or next_page_index >= _pages.size():
		return
	_current_page_index = next_page_index
	_update_paper_page()


func _update_paper_page() -> void:
	if _pages.is_empty():
		return
	_report_body.text = _pages[_current_page_index]
	_page_indicator.text = "PAGE %d / %d" % [_current_page_index + 1, _pages.size()]
	_update_page_controls()


func _update_page_controls() -> void:
	var show_controls := _report_revealed and _pages.size() > 1
	for control in _page_controls:
		control.visible = show_controls
	_previous_page_button.disabled = _current_page_index == 0
	_next_page_button.disabled = _current_page_index >= _pages.size() - 1


func _finish_paper_presentation() -> void:
	_active_tween = null
	_can_continue = true
	_reset_skip_state()
	var prompt_tween := create_tween()
	prompt_tween.tween_property(_continue_button, "modulate:a", 1.0, 0.25)
