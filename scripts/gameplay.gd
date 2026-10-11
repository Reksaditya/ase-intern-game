extends Node2D

signal outcome_finished

const MINIMUM_ANSWERS_BEFORE_SCAN := 2
const WORD_REVEAL_INTERVAL := 0.12
const SPEAKER_CHANGE_PAUSE := 0.6
const CHARACTER_DATA_PATH := "res://data/d1p1.json"

@onready var pupil: Control = $HUD/Pupil
@onready var television: Node = $Sprite2D
@onready var pupil_button: Button = $HUD/DiagnosticTools/Layout/PupilButton
@onready var heartbeat_temperature: Control = $HUD/HeartbeatTemperature
@onready var heartbeat_temperature_button: Button = $HUD/DiagnosticTools/Layout/HeartbeatTemperatureButton
@onready var dialogue_output: RichTextLabel = $HUD/DialogueOutput
@onready var outcome_continue_button: Button = $HUD/OutcomeContinueButton
@onready var transcript_click_area: Button = $HUD/TranscriptClickArea
@onready var transcript_overlay: ColorRect = $HUD/TranscriptOverlay
@onready var transcript_scroll: ScrollContainer = $HUD/TranscriptOverlay/CenterContainer/TranscriptPanel/Layout/TranscriptScroll
@onready var transcript_output: RichTextLabel = $HUD/TranscriptOverlay/CenterContainer/TranscriptPanel/Layout/TranscriptScroll/TranscriptText
@onready var close_transcript_button: Button = $HUD/TranscriptOverlay/CenterContainer/TranscriptPanel/Layout/Header/CloseButton
@onready var id_card_overlay: ColorRect = $HUD/IDCardOverlay
@onready var id_card_image: TextureRect = $HUD/IDCardOverlay/CardImage
@onready var id_card_close_button: Button = $HUD/IDCardOverlay/CloseButton
@onready var id_card_button: TextureButton = $Sprite2D/idcard

var _current_character: Dictionary = {}
var _asked_question_ids: Dictionary = {}
var _shown_tool_reactions: Dictionary = {}
var _dialogue_history: Array[Dictionary] = []
var _pending_recent_events: Array[Dictionary] = []
var _recent_event_generation := 0
var _recent_event_is_revealing := false
var _last_recent_speaker := ""
var _decision_outcome_started := false


func _ready() -> void:
	television.connect("question_asked", _on_question_asked)
	television.connect("id_card_requested", _open_id_card)
	pupil_button.pressed.connect(_open_pupil)
	pupil.connect("close_requested", _close_pupil)
	pupil.connect("tool_reaction_requested", _show_tool_reactions)
	heartbeat_temperature_button.pressed.connect(_open_heartbeat_temperature)
	heartbeat_temperature.connect("close_requested", _close_heartbeat_temperature)
	outcome_continue_button.pressed.connect(func(): outcome_finished.emit())
	transcript_click_area.pressed.connect(_open_transcript)
	close_transcript_button.pressed.connect(_close_transcript)
	id_card_close_button.pressed.connect(_close_id_card)
	pupil.set_process(false)
	heartbeat_temperature.set_process(false)
	_current_character = _load_character_data()
	pupil.call("set_character_data", _current_character)
	heartbeat_temperature.call("set_character_data", _current_character)
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
			_open_transcript()
			get_viewport().set_input_as_handled()


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
		_append_dialogue_line("PLAYER", str(entry.get("player_prompt", "")))
		_append_dialogue_line(str(entry.get("speaker", "PEMOHON")), str(entry.get("text", "")))
		return


func show_decision_outcome(is_accepted: bool) -> void:
	if _decision_outcome_started:
		return
	_decision_outcome_started = true

	var outcome_name := "accept" if is_accepted else "decline"
	var all_outcomes: Variant = _current_character.get("outcomes", {})
	var outcome_events: Variant = all_outcomes.get(outcome_name, []) if all_outcomes is Dictionary else []
	_clear_recent_dialogue()
	outcome_continue_button.disabled = true
	if outcome_events is Array:
		for event in outcome_events:
			if event is Dictionary:
				_append_outcome_event(event)

	for button_name in ["TerimaButton", "TolakButton"]:
		var decision_button := get_node_or_null("bunker/%s" % button_name) as BaseButton
		if decision_button:
			decision_button.disabled = true

	pupil.hide()
	heartbeat_temperature.hide()
	$HUD/DiagnosticTools.hide()
	outcome_continue_button.show()
	if not _recent_event_is_revealing and _pending_recent_events.is_empty():
		outcome_continue_button.disabled = false
	outcome_continue_button.grab_focus()


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
	if not pre_interaction is Array:
		return
	for event in pre_interaction:
		if event is Dictionary:
			_append_outcome_event(event)


func _append_formatted_event(target: RichTextLabel, event: Dictionary) -> void:
	var event_text := str(event.get("text", ""))
	if str(event.get("type", "dialogue")) == "narration":
		target.push_italics()
		target.add_text(event_text)
		target.pop()
	else:
		var speaker := str(event.get("speaker", ""))
		if not speaker.is_empty():
			target.push_bold()
			target.add_text("%s: " % speaker)
			target.pop()
		target.add_text(event_text)
	target.newline()
	target.newline()


func _clear_recent_dialogue() -> void:
	_recent_event_generation += 1
	_pending_recent_events.clear()
	_recent_event_is_revealing = false
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
	if not _last_recent_speaker.is_empty() and speaker != _last_recent_speaker:
		await get_tree().create_timer(SPEAKER_CHANGE_PAUSE).timeout
		if generation != _recent_event_generation:
			return
	await _reveal_recent_event(event, generation)
	if generation != _recent_event_generation:
		return
	_last_recent_speaker = speaker
	_recent_event_is_revealing = false
	if _pending_recent_events.is_empty():
		if _decision_outcome_started:
			outcome_continue_button.disabled = false
			outcome_continue_button.grab_focus()
		return
	_start_recent_event_reveal()


func _speaker_for_event(event: Dictionary) -> String:
	if str(event.get("type", "dialogue")) == "narration":
		return "NARRATION"
	return str(event.get("speaker", ""))


func _reveal_recent_event(event: Dictionary, generation: int) -> void:
	var start_character := dialogue_output.get_total_character_count()
	dialogue_output.visible_characters = start_character
	_append_formatted_event(dialogue_output, event)
	var final_character := dialogue_output.get_total_character_count()
	var event_text := str(event.get("text", ""))
	var speaker := str(event.get("speaker", ""))
	if str(event.get("type", "dialogue")) != "narration" and not speaker.is_empty():
		event_text = "%s: %s" % [speaker, event_text]
	var words := event_text.split(" ", false)
	var revealed_characters := 0
	for word_index in range(words.size()):
		revealed_characters += words[word_index].length()
		if word_index < words.size() - 1:
			revealed_characters += 1
		dialogue_output.visible_characters = mini(start_character + revealed_characters, final_character)
		if word_index < words.size() - 1:
			await get_tree().create_timer(WORD_REVEAL_INTERVAL).timeout
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
	pupil_button.text = "PUPIL REFLEX" if unlocked else "PUPIL REFLEX  |  LOCKED"
	heartbeat_temperature_button.text = (
		"HEARTBEAT + TEMPERATURE"
		if unlocked
		else "HEARTBEAT + TEMPERATURE  |  LOCKED"
	)


func _load_character_data() -> Dictionary:
	var file := FileAccess.open(CHARACTER_DATA_PATH, FileAccess.READ)
	if file == null:
		push_error("Could not open character data: %s" % CHARACTER_DATA_PATH)
		return {}

	var parsed = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		push_error("Character data must contain a JSON object.")
		return {}
	return parsed
