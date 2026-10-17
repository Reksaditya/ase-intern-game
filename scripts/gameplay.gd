extends Node2D

signal outcome_finished

const MINIMUM_ANSWERS_BEFORE_SCAN := 2
const TYPE_SPEED := 0.025
const MAX_BLOCK_TIME := 7.0
const LINE_PAUSE := 0.7
const PLAYER_NAME := "KAMU"
const CHARACTER_DATA_PATH := "res://data/d1p1.json"
const CHARACTER_HEIGHT := 640.0
const CHARACTER_WINDOW_HEIGHT_RATIO := 0.9
const CHARACTER_TOP_MARGIN := 0.0
const CHARACTER_VERTICAL_OFFSET := 52.0
const CHARACTER_EXIT_MARGIN := 40.0
const CHARACTER_ENTER_DURATION := 2.4
const CHARACTER_EXIT_DURATION := 2.0
const CHARACTER_STEP_TIME := 0.22
const CHARACTER_BOB_HEIGHT := 7.0
const CHARACTER_SWAY_DEGREES := 1.2
const CHARACTER_HOLD_AFTER_OUTCOME := 0.9
const EMPTY_CHARACTER_EXIT_TINT := Color(0.1, 0.1, 0.14, 1.0)

@onready var pupil: Control = $HUD/DesignCanvas/Pupil
@onready var television: Node = $Sprite2D
@onready var character_window: Control = $bunker/bgpanel/WindowClip
@onready var character_holder: Node2D = $bunker/bgpanel/WindowClip/CharacterHolder
@onready var accept_button: BaseButton = $bunker/TerimaButton
@onready var decline_button: BaseButton = $bunker/TolakButton
@onready var pupil_button: Button = $HUD/DesignCanvas/DiagnosticTools/Layout/PupilButton
@onready var pupil_status_dot: Label = $HUD/DesignCanvas/DiagnosticTools/Layout/PupilButton/ButtonContent/StatusDot
@onready var pupil_app_name: Label = $HUD/DesignCanvas/DiagnosticTools/Layout/PupilButton/ButtonContent/AppName
@onready var pupil_action: Label = $HUD/DesignCanvas/DiagnosticTools/Layout/PupilButton/ButtonContent/Action
@onready var heartbeat_temperature: Control = $HUD/DesignCanvas/HeartbeatTemperature
@onready var heartbeat_temperature_button: Button = $HUD/DesignCanvas/DiagnosticTools/Layout/HeartbeatTemperatureButton
@onready var heartbeat_status_dot: Label = $HUD/DesignCanvas/DiagnosticTools/Layout/HeartbeatTemperatureButton/ButtonContent/StatusDot
@onready var heartbeat_app_name: Label = $HUD/DesignCanvas/DiagnosticTools/Layout/HeartbeatTemperatureButton/ButtonContent/AppName
@onready var heartbeat_action: Label = $HUD/DesignCanvas/DiagnosticTools/Layout/HeartbeatTemperatureButton/ButtonContent/Action
@onready var dialogue_output: RichTextLabel = $HUD/DesignCanvas/DialogueOutput
@onready var transcript_click_area: Button = $HUD/DesignCanvas/TranscriptClickArea
@onready var transcript_overlay: ColorRect = $HUD/DesignCanvas/TranscriptOverlay
@onready var transcript_scroll: ScrollContainer = $HUD/DesignCanvas/TranscriptOverlay/CenterContainer/TranscriptPanel/Layout/TranscriptScroll
@onready var transcript_output: RichTextLabel = $HUD/DesignCanvas/TranscriptOverlay/CenterContainer/TranscriptPanel/Layout/TranscriptScroll/TranscriptText
@onready var close_transcript_button: Button = $HUD/DesignCanvas/TranscriptOverlay/CenterContainer/TranscriptPanel/Layout/Header/CloseButton
@onready var id_card_overlay: ColorRect = $HUD/DesignCanvas/IDCardOverlay
@onready var id_card_image: TextureRect = $HUD/DesignCanvas/IDCardOverlay/CardImage
@onready var id_card_close_button: Button = $HUD/DesignCanvas/IDCardOverlay/CloseButton
@onready var id_card_button: TextureButton = $Sprite2D/idcard

var _current_character: Dictionary = {}
var _asked_question_ids: Dictionary = {}
var _shown_tool_reactions: Dictionary = {}
var _dialogue_history: Array[Dictionary] = []
var _pending_recent_events: Array[Dictionary] = []
var _recent_event_generation := 0
var _recent_event_is_revealing := false
var _skip_recent_reveal_requested := false
var _last_recent_speaker := ""
var _decision_outcome_started := false
var _decision_was_accepted := false
var _outcome_exit_started := false
var _character_pivot: Node2D
var _character_sprite: Sprite2D
var _character_move_tween: Tween
var _character_bob_tween: Tween
var _character_settle_tween: Tween
var _character_half_width := 150.0
var character_data_path := CHARACTER_DATA_PATH


func _ready() -> void:
	television.connect("question_asked", _on_question_asked)
	television.connect("id_card_requested", _open_id_card)
	pupil_button.pressed.connect(_open_pupil)
	pupil.connect("close_requested", _close_pupil)
	pupil.connect("tool_reaction_requested", _show_tool_reactions)
	heartbeat_temperature_button.pressed.connect(_open_heartbeat_temperature)
	heartbeat_temperature.connect("close_requested", _close_heartbeat_temperature)
	transcript_click_area.pressed.connect(_open_transcript)
	close_transcript_button.pressed.connect(_close_transcript)
	id_card_close_button.pressed.connect(_close_id_card)
	accept_button.disabled = true
	decline_button.disabled = true
	pupil.set_process(false)
	heartbeat_temperature.set_process(false)
	_current_character = _load_character_data(character_data_path)
	pupil.call("set_character_data", _current_character)
	heartbeat_temperature.call("set_character_data", _current_character)
	await _animate_character_in()
	accept_button.disabled = false
	decline_button.disabled = false
	_show_pre_interaction()
	_refresh_diagnostic_access()


func _input(event: InputEvent) -> void:
	if id_card_overlay.visible and event.is_action_pressed("ui_cancel"):
		_close_id_card()
		get_viewport().set_input_as_handled()
		return
	if id_card_overlay.visible:
		return
	if transcript_overlay.visible and event.is_action_pressed("ui_cancel"):
		_close_transcript()
		get_viewport().set_input_as_handled()
		return
	if transcript_overlay.visible:
		return
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if (
			mouse_event.pressed
			and mouse_event.button_index == MOUSE_BUTTON_LEFT
			and transcript_click_area.get_global_rect().has_point(mouse_event.position)
		):
			if _recent_event_is_revealing or not _pending_recent_events.is_empty():
				_skip_recent_dialogue()
			else:
				_open_transcript()
			get_viewport().set_input_as_handled()


func _skip_recent_dialogue() -> void:
	_skip_recent_reveal_requested = true
	dialogue_output.visible_characters = -1


func get_case_tracking_data() -> Dictionary:
	var is_empty := bool(_current_character.get("is_empty", false))
	var decision_effects: Variant = _current_character.get("decision_effects", {})
	return {
		"is_empty": is_empty,
		"decision_effects": decision_effects if decision_effects is Dictionary else {},
	}


func _open_pupil() -> void:
	if not _diagnostics_unlocked():
		return
	heartbeat_temperature.hide()
	heartbeat_temperature.set_process(false)
	pupil.show()
	pupil.set_process(true)


func _close_pupil() -> void:
	pupil.hide()
	pupil.set_process(false)
	pupil_button.grab_focus()


func _open_heartbeat_temperature() -> void:
	if not _diagnostics_unlocked():
		return
	pupil.hide()
	pupil.set_process(false)
	heartbeat_temperature.show()
	heartbeat_temperature.set_process(true)
	_show_tool_reactions("biometric_monitor")


func _close_heartbeat_temperature() -> void:
	heartbeat_temperature.hide()
	heartbeat_temperature.set_process(false)
	heartbeat_temperature_button.grab_focus()


func _on_question_asked(question_key: String) -> void:
	if _decision_outcome_started:
		return
	var diagnostics_were_unlocked := _diagnostics_unlocked()
	_asked_question_ids[question_key] = true
	_show_question_response(question_key)
	_refresh_diagnostic_access()
	if not diagnostics_were_unlocked and _diagnostics_unlocked():
		_append_dialogue_line("SISTEM", "Alat Pemindai Terbuka.")


func _show_question_response(question_key: String) -> void:
	var dialogue_data: Variant = _current_character.get("dialogs", [])
	if not dialogue_data is Array:
		return

	for entry in dialogue_data:
		if not entry is Dictionary:
			continue
		if str(entry.get("trigger", "")) != question_key:
			continue
		_clear_recent_dialogue()
		_append_dialogue_line(PLAYER_NAME, str(entry.get("player_prompt", "")))
		_append_dialogue_line(str(entry.get("speaker", "PEMOHON")), str(entry.get("text", "")))
		return


func show_decision_outcome(is_accepted: bool) -> void:
	if _decision_outcome_started:
		return
	_decision_outcome_started = true
	_decision_was_accepted = is_accepted

	var outcome_name := "accept" if is_accepted else "decline"
	var all_outcomes: Variant = _current_character.get("outcomes", {})
	var outcome_events: Variant = all_outcomes.get(outcome_name, []) if all_outcomes is Dictionary else []
	_clear_recent_dialogue()
	if outcome_events is Array:
		for event in outcome_events:
			if event is Dictionary:
				_append_outcome_event(event)

	for button_name in ["TerimaButton", "TolakButton"]:
		var decision_button := get_node_or_null("bunker/%s" % button_name) as BaseButton
		if decision_button:
			decision_button.disabled = true

	pupil.hide()
	pupil.set_process(false)
	heartbeat_temperature.hide()
	heartbeat_temperature.set_process(false)
	$HUD/DesignCanvas/DiagnosticTools.hide()
	if not _recent_event_is_revealing and _pending_recent_events.is_empty():
		_finish_outcome_presentation()


func _append_outcome_event(event: Dictionary) -> void:
	var transcript_event := event.duplicate()
	_dialogue_history.append(transcript_event)
	_queue_recent_event(transcript_event)


func _append_dialogue_line(speaker: String, text: String) -> void:
	var event := {"type": "dialogue", "speaker": speaker, "text": text}
	_dialogue_history.append(event)
	_queue_recent_event(event)


func _show_pre_interaction() -> void:
	var pre_interaction: Variant = _current_character.get("pre_interaction", [])
	if pre_interaction is Array:
		for event in pre_interaction:
			if event is Dictionary:
				_append_outcome_event(event)

	if MINIMUM_ANSWERS_BEFORE_SCAN > 0:
		_append_outcome_event({
			"type": "dialogue",
			"speaker": "SISTEM",
			"text": "Alat Pemindai Terkunci. Ajukan minimal %d pertanyaan Interogasi untuk membuka akses."
				% MINIMUM_ANSWERS_BEFORE_SCAN,
		})


func _append_formatted_event(target: RichTextLabel, event: Dictionary) -> void:
	var event_text := str(event.get("text", ""))
	if str(event.get("type", "dialogue")) == "narration":
		target.push_italics()
		target.add_text("> " + event_text)
		target.pop()
	else:
		var speaker := str(event.get("speaker", ""))
		if not speaker.is_empty():
			target.push_bold()
			var speaker_prefix := "[SISTEM] " if speaker == "SISTEM" else "%s: " % speaker
			target.add_text(speaker_prefix)
			target.pop()
		target.add_text(event_text)
	target.newline()
	target.newline()


func _clear_recent_dialogue() -> void:
	_recent_event_generation += 1
	_pending_recent_events.clear()
	_recent_event_is_revealing = false
	_skip_recent_reveal_requested = false
	_last_recent_speaker = ""
	dialogue_output.clear()
	dialogue_output.visible_characters = 0


func _queue_recent_event(event: Dictionary) -> void:
	_pending_recent_events.append(event.duplicate())
	_start_recent_event_reveal()


func _start_recent_event_reveal() -> void:
	if _recent_event_is_revealing or _pending_recent_events.is_empty():
		return
	_recent_event_is_revealing = true
	var generation := _recent_event_generation
	var event: Dictionary = _pending_recent_events.pop_front()
	var speaker := _speaker_for_event(event)
	if not _last_recent_speaker.is_empty() and not _skip_recent_reveal_requested:
		await _wait_recent_line_pause(generation)
		if generation != _recent_event_generation:
			return
	await _reveal_recent_event(event, generation)
	if generation != _recent_event_generation:
		return
	_last_recent_speaker = speaker
	_recent_event_is_revealing = false
	if _pending_recent_events.is_empty():
		_skip_recent_reveal_requested = false
		if _decision_outcome_started:
			_finish_outcome_presentation()
		return
	_start_recent_event_reveal()


func _wait_recent_line_pause(generation: int) -> void:
	var remaining := LINE_PAUSE
	var last_tick := Time.get_ticks_usec()
	while remaining > 0.0 and generation == _recent_event_generation and not _skip_recent_reveal_requested:
		await get_tree().process_frame
		var now := Time.get_ticks_usec()
		remaining -= float(now - last_tick) / 1_000_000.0
		last_tick = now


func _finish_outcome_presentation() -> void:
	if _outcome_exit_started:
		return
	_outcome_exit_started = true
	await _animate_character_out()
	outcome_finished.emit()


func _animate_character_in() -> void:
	var image_path := str(_current_character.get("character_image", ""))
	if image_path.is_empty() or not ResourceLoader.exists(image_path):
		if image_path.is_empty():
			push_error("The current character is missing its character_image path.")
		else:
			push_error("Character image not found: %s" % image_path)
		return

	var texture := load(image_path) as Texture2D
	if texture == null:
		push_error("Character image is not a texture: %s" % image_path)
		return
	if character_window.size.x <= 0.0 or character_window.size.y <= 0.0:
		await get_tree().process_frame
	var image := texture.get_image()
	if image == null:
		push_error("Could not read character image: %s" % image_path)
		return
	var visible_region := image.get_used_rect()
	if visible_region.size.x <= 0 or visible_region.size.y <= 0:
		push_error("Character image has no visible pixels: %s" % image_path)
		return

	_character_pivot = Node2D.new()
	_character_sprite = Sprite2D.new()
	_character_sprite.texture = texture
	_character_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_character_sprite.region_enabled = true
	_character_sprite.region_filter_clip_enabled = true
	_character_sprite.region_rect = Rect2(
		Vector2(visible_region.position),
		Vector2(visible_region.size)
	)
	var character_height := minf(
		CHARACTER_HEIGHT,
		character_window.size.y * CHARACTER_WINDOW_HEIGHT_RATIO
	)
	var sprite_scale := character_height / float(visible_region.size.y)
	_character_sprite.scale = Vector2(sprite_scale, sprite_scale)
	_character_half_width = float(visible_region.size.x) * sprite_scale * 0.5
	_character_pivot.add_child(_character_sprite)
	character_holder.add_child(_character_pivot)

	var stand_y := (
		CHARACTER_TOP_MARGIN
		+ character_height * 0.5
		+ CHARACTER_VERTICAL_OFFSET
		+ float(_current_character.get("offset_y", 0.0))
	)
	_character_pivot.position = Vector2(
		-_character_half_width - CHARACTER_EXIT_MARGIN,
		stand_y
	)
	await _walk_character_to(
		character_window.size.x * 0.5,
		CHARACTER_ENTER_DURATION,
		Tween.EASE_OUT
	)


func _animate_character_out() -> void:
	if not is_instance_valid(_character_pivot):
		return
	await get_tree().create_timer(CHARACTER_HOLD_AFTER_OUTCOME).timeout
	if not is_instance_valid(_character_pivot):
		return

	if not _decision_was_accepted and bool(_current_character.get("is_empty", false)):
		create_tween().tween_property(
			_character_sprite,
			"modulate",
			EMPTY_CHARACTER_EXIT_TINT,
			0.8
		)

	var target_x := character_window.size.x + _character_half_width + CHARACTER_EXIT_MARGIN
	if not _decision_was_accepted:
		target_x = -_character_half_width - CHARACTER_EXIT_MARGIN
	await _walk_character_to(target_x, CHARACTER_EXIT_DURATION, Tween.EASE_IN)
	if is_instance_valid(_character_pivot):
		_character_pivot.queue_free()
	_character_pivot = null
	_character_sprite = null


func _walk_character_to(target_x: float, duration: float, ease_type: Tween.EaseType) -> void:
	if not is_instance_valid(_character_pivot):
		return
	_start_character_walk_bob()
	if _character_move_tween:
		_character_move_tween.kill()
	_character_move_tween = create_tween()
	_character_move_tween.set_trans(Tween.TRANS_SINE).set_ease(ease_type)
	_character_move_tween.tween_property(_character_pivot, "position:x", target_x, duration)
	await _character_move_tween.finished
	_stop_character_walk_bob()


func _start_character_walk_bob() -> void:
	if _character_bob_tween:
		_character_bob_tween.kill()
	if _character_settle_tween:
		_character_settle_tween.kill()
	_character_bob_tween = create_tween().set_loops()
	_character_bob_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	var steps := [
		[-CHARACTER_BOB_HEIGHT, CHARACTER_SWAY_DEGREES],
		[0.0, 0.0],
		[-CHARACTER_BOB_HEIGHT, -CHARACTER_SWAY_DEGREES],
		[0.0, 0.0],
	]
	for step in steps:
		_character_bob_tween.tween_property(
			_character_sprite,
			"position:y",
			step[0],
			CHARACTER_STEP_TIME
		)
		_character_bob_tween.parallel().tween_property(
			_character_sprite,
			"rotation",
			deg_to_rad(step[1]),
			CHARACTER_STEP_TIME
		)


func _stop_character_walk_bob() -> void:
	if _character_bob_tween:
		_character_bob_tween.kill()
	if not is_instance_valid(_character_sprite):
		return
	_character_settle_tween = create_tween()
	_character_settle_tween.set_parallel(true)
	_character_settle_tween.tween_property(_character_sprite, "position:y", 0.0, 0.12)
	_character_settle_tween.tween_property(_character_sprite, "rotation", 0.0, 0.12)


func _speaker_for_event(event: Dictionary) -> String:
	if str(event.get("type", "dialogue")) == "narration":
		return "NARRATION"
	return str(event.get("speaker", ""))


func _reveal_recent_event(event: Dictionary, generation: int) -> void:
	var start_character := dialogue_output.get_total_character_count()
	dialogue_output.visible_characters = start_character
	_append_formatted_event(dialogue_output, event)
	var final_character := dialogue_output.get_total_character_count()
	var character_count := final_character - start_character
	if character_count <= 0:
		return
	if _skip_recent_reveal_requested:
		dialogue_output.visible_characters = final_character
		return

	var duration := clampf(character_count * TYPE_SPEED, 0.05, MAX_BLOCK_TIME)
	var character_delay := duration / float(character_count)
	for character in range(start_character + 1, final_character + 1):
		if generation != _recent_event_generation:
			return
		if _skip_recent_reveal_requested:
			dialogue_output.visible_characters = final_character
			return
		dialogue_output.visible_characters = character
		if character < final_character:
			await get_tree().create_timer(character_delay).timeout
			if generation != _recent_event_generation:
				return
	dialogue_output.visible_characters = final_character


func _open_transcript() -> void:
	transcript_output.clear()
	if _dialogue_history.is_empty():
		transcript_output.add_text("No dialogue yet.")
	else:
		for event in _dialogue_history:
			_append_formatted_event(transcript_output, event)
	transcript_scroll.set_deferred("scroll_vertical", 0)
	transcript_overlay.show()
	close_transcript_button.grab_focus()


func _close_transcript() -> void:
	transcript_overlay.hide()
	transcript_click_area.grab_focus()


func _open_id_card() -> void:
	var image_path := str(_current_character.get("id_card_image", ""))
	if image_path.is_empty():
		var character_id := str(_current_character.get("character_id", "unknown"))
		push_error("Character '%s' is missing id_card_image." % character_id)
		return
	if not ResourceLoader.exists(image_path):
		push_error("ID card image not found: %s" % image_path)
		return

	var card_texture := load(image_path) as Texture2D
	if card_texture == null:
		push_error("ID card image is not a texture: %s" % image_path)
		return

	id_card_image.texture = card_texture
	id_card_overlay.show()
	id_card_close_button.grab_focus()


func _close_id_card() -> void:
	id_card_overlay.hide()
	id_card_button.grab_focus()


func _show_tool_reactions(tool_key: String) -> void:
	if _shown_tool_reactions.has(tool_key):
		return
	var all_reactions: Variant = _current_character.get("tool_reactions", {})
	if not all_reactions is Dictionary:
		return
	var reactions: Variant = all_reactions.get(tool_key, [])
	if not reactions is Array or reactions.is_empty():
		return
	_shown_tool_reactions[tool_key] = true
	for reaction in reactions:
		if reaction is Dictionary:
			_append_outcome_event(reaction)


func _diagnostics_unlocked() -> bool:
	return _asked_question_ids.size() >= MINIMUM_ANSWERS_BEFORE_SCAN


func _refresh_diagnostic_access() -> void:
	var unlocked := _diagnostics_unlocked()
	pupil_button.disabled = not unlocked
	heartbeat_temperature_button.disabled = not unlocked
	pupil_action.text = "LAUNCH ↵" if unlocked else "LOCKED"
	heartbeat_action.text = "EXECUTE ↵" if unlocked else "LOCKED"
	var app_color := Color(0.28, 0.38, 0.42, 0.85)
	var action_color := Color(0.21, 0.30, 0.33, 0.75)
	var dot_color := Color(0.17, 0.31, 0.35, 0.8)
	if unlocked:
		app_color = Color(0.24, 0.68, 0.75, 1.0)
		action_color = Color(0.22, 0.57, 0.65, 1.0)
		dot_color = Color(0.18, 0.68, 0.77, 1.0)
	for label in [pupil_app_name, heartbeat_app_name]:
		label.add_theme_color_override("font_color", app_color)
	for label in [pupil_action, heartbeat_action]:
		label.add_theme_color_override("font_color", action_color)
	for label in [pupil_status_dot, heartbeat_status_dot]:
		label.add_theme_color_override("font_color", dot_color)


func _load_character_data(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Could not open character data: %s" % path)
		return {}

	var parsed = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		push_error("Character data at '%s' must contain a JSON object." % path)
		return {}
	return parsed
