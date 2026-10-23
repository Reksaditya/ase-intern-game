extends Node2D

signal outcome_finished
signal return_to_main_menu

const MINIMUM_ANSWERS_BEFORE_SCAN := 2
const TYPE_SPEED := 0.025
const MAX_BLOCK_TIME := 7.0
const LINE_PAUSE := 0.7
const DIALOGUE_SCROLL_STEP := 56.0
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
const LOCKED_SFX: AudioStream = preload("res://assets/bgm/locked.mp3")
const BUTTON_SFX: AudioStream = preload("res://assets/bgm/button.mp3")
const REJECT_SFX: AudioStream = preload("res://assets/bgm/reject.wav")
const SENTER_SFX: AudioStream = preload("res://assets/bgm/senter.wav")
const MONITOR_SFX: AudioStream = preload("res://assets/bgm/monitor.wav")
const WORD_SFX: AudioStream = preload("res://assets/bgm/word.wav")
const STEP_SFX: AudioStream = preload("res://assets/bgm/step.wav")
const WORD_SFX_MIN_INTERVAL_MS := 90

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
@onready var intlog_button: TextureButton = $Sprite2D/intlog
@onready var pause_button: Button = $HUD/DesignCanvas/PauseButton
@onready var pause_overlay: ColorRect = $HUD/DesignCanvas/PauseOverlay
@onready var pupil_close_button: Button = $HUD/DesignCanvas/Pupil/Layout/Header/CloseButton
@onready var heartbeat_close_button: Button = (
	$HUD/DesignCanvas/HeartbeatTemperature/Layout/Header/CloseButton
)
@onready var pause_resume_button: Button = (
	$HUD/DesignCanvas/PauseOverlay/Center/Content/ResumeButton
)
@onready var pause_how_to_play_button: Button = (
	$HUD/DesignCanvas/PauseOverlay/Center/Content/HowToPlayButton
)
@onready var pause_main_menu_button: Button = (
	$HUD/DesignCanvas/PauseOverlay/Center/Content/MainMenuButton
)

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
var _focus_return_target: Control
var _dialogue_scroll_mode := false
var character_data_path := CHARACTER_DATA_PATH
var _locked_sfx_player: AudioStreamPlayer
var _button_sfx_player: AudioStreamPlayer
var _reject_sfx_player: AudioStreamPlayer
var _senter_sfx_player: AudioStreamPlayer
var _monitor_sfx_player: AudioStreamPlayer
var _word_sfx_player: AudioStreamPlayer
var _step_sfx_player: AudioStreamPlayer
var _last_word_sfx_ms := -1000


func _ready() -> void:
	television.connect("question_asked", _on_question_asked)
	television.connect("id_card_requested", _open_id_card)
	television.connect("log_panel_opened", _on_log_panel_opened)
	television.connect("log_panel_closed", _on_log_panel_closed)
	pupil_button.pressed.connect(_open_pupil)
	pupil.connect("close_requested", _close_pupil)
	pupil.connect("tool_reaction_requested", _show_tool_reactions)
	heartbeat_temperature_button.pressed.connect(_open_heartbeat_temperature)
	heartbeat_temperature.connect("close_requested", _close_heartbeat_temperature)
	close_transcript_button.pressed.connect(_close_transcript)
	id_card_close_button.pressed.connect(_close_id_card)
	dialogue_output.focus_entered.connect(_on_dialogue_focus_entered)
	dialogue_output.focus_exited.connect(_on_dialogue_focus_exited)
	pause_button.pressed.connect(_open_pause_menu.bind(true))
	pause_overlay.connect("resume_requested", _resume_from_pause)
	pause_overlay.connect("main_menu_requested", _return_to_main_menu)
	accept_button.disabled = true
	decline_button.disabled = true
	pupil.set_process(false)
	heartbeat_temperature.set_process(false)
	_setup_audio_players()
	_current_character = _load_character_data(character_data_path)
	pupil.call("set_character_data", _current_character)
	heartbeat_temperature.call("set_character_data", _current_character)
	await _animate_character_in()
	accept_button.disabled = false
	decline_button.disabled = false
	_show_pre_interaction()
	_refresh_diagnostic_access()
	_update_focus_ring()
	intlog_button.grab_focus()
	InputGuide.enter_gameplay()


func _input(event: InputEvent) -> void:
	if id_card_overlay.visible and event.is_action_pressed("ui_cancel"):
		_close_id_card()
		get_viewport().set_input_as_handled()
		return
	if id_card_overlay.visible:
		return
	if transcript_overlay.visible:
		if event.is_action_pressed("ui_cancel"):
			_close_transcript()
			get_viewport().set_input_as_handled()
			return
		if event.is_action_pressed("ui_up"):
			transcript_scroll.scroll_vertical -= 60
			get_viewport().set_input_as_handled()
			return
		if event.is_action_pressed("ui_down"):
			transcript_scroll.scroll_vertical += 60
			get_viewport().set_input_as_handled()
			return
		return
	if television.log_open and event.is_action_pressed("ui_cancel"):
		television.call("close_log_panel")
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("ui_pause"):
		if pupil.visible or heartbeat_temperature.visible:
			return
		_open_pause_menu()
		get_viewport().set_input_as_handled()
		return
	var is_key_echo := event is InputEventKey and (event as InputEventKey).echo
	if dialogue_output.has_focus() and not is_key_echo:
		if event.is_action_pressed("ui_accept"):
			if _dialogue_scroll_mode:
				_open_transcript()
			else:
				_set_dialogue_scroll_mode(true)
			get_viewport().set_input_as_handled()
			return
		if _dialogue_scroll_mode:
			if event.is_action_pressed("ui_up"):
				if _scroll_dialogue(-1.0):
					get_viewport().set_input_as_handled()
					return
				_focus_adjacent_from_dialogue(false)
				get_viewport().set_input_as_handled()
				return
			elif event.is_action_pressed("ui_down"):
				if _scroll_dialogue(1.0):
					get_viewport().set_input_as_handled()
					return
				_focus_adjacent_from_dialogue(true)
				get_viewport().set_input_as_handled()
				return
		else:
			# Before scroll mode is activated, Up/Down navigate the focus ring
			# instead of being consumed by the RichTextLabel's own scrolling.
			if event.is_action_pressed("ui_up"):
				_focus_adjacent_from_dialogue(false)
				get_viewport().set_input_as_handled()
				return
			elif event.is_action_pressed("ui_down"):
				_focus_adjacent_from_dialogue(true)
				get_viewport().set_input_as_handled()
				return
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if (
			mouse_event.pressed
			and mouse_event.button_index == MOUSE_BUTTON_LEFT
			and not _diagnostics_unlocked()
			and not _decision_outcome_started
			and not pupil.visible
			and not heartbeat_temperature.visible
			and (
				pupil_button.get_global_rect().has_point(mouse_event.position)
				or heartbeat_temperature_button.get_global_rect().has_point(mouse_event.position)
			)
		):
			_play_sfx(_locked_sfx_player)
			get_viewport().set_input_as_handled()
			return
		var dialogue_scrollbar := dialogue_output.get_v_scroll_bar()
		var clicked_dialogue_scrollbar := (
			dialogue_scrollbar.visible
			and dialogue_scrollbar.get_global_rect().has_point(mouse_event.position)
		)
		if (
			mouse_event.pressed
			and mouse_event.button_index == MOUSE_BUTTON_LEFT
			and transcript_click_area.get_global_rect().has_point(mouse_event.position)
			and not clicked_dialogue_scrollbar
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


func _setup_audio_players() -> void:
	_locked_sfx_player = _create_sfx_player(LOCKED_SFX, -3.0)
	_button_sfx_player = _create_sfx_player(BUTTON_SFX, -3.0)
	_reject_sfx_player = _create_sfx_player(REJECT_SFX, -3.0)
	_senter_sfx_player = _create_sfx_player(SENTER_SFX, 0.0)
	_monitor_sfx_player = _create_sfx_player(MONITOR_SFX, -4.0)
	_monitor_sfx_player.finished.connect(func():
		if heartbeat_temperature.visible:
			_monitor_sfx_player.play()
	)
	_word_sfx_player = _create_sfx_player(WORD_SFX, -2.0)
	_step_sfx_player = _create_sfx_player(STEP_SFX, 12.0)
	_step_sfx_player.finished.connect(func():
		if _character_bob_tween and _character_bob_tween.is_running():
			_step_sfx_player.play()
	)


func _create_sfx_player(stream: AudioStream, volume_db: float) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.volume_db = volume_db
	add_child(player)
	return player


func _play_sfx(player: AudioStreamPlayer) -> void:
	if is_instance_valid(player):
		player.play()


func _stop_sfx(player: AudioStreamPlayer) -> void:
	if is_instance_valid(player) and player.playing:
		player.stop()


func _play_word_sfx() -> void:
	if not is_instance_valid(_word_sfx_player):
		return
	var now := Time.get_ticks_msec()
	if now - _last_word_sfx_ms < WORD_SFX_MIN_INTERVAL_MS:
		return
	_last_word_sfx_ms = now
	_word_sfx_player.play()


func _stop_tool_sfx() -> void:
	_stop_sfx(_senter_sfx_player)
	_stop_sfx(_monitor_sfx_player)


func _open_pupil() -> void:
	if not _diagnostics_unlocked():
		_play_sfx(_locked_sfx_player)
		return
	_play_sfx(_button_sfx_player)
	_stop_sfx(_monitor_sfx_player)
	_remember_focus(pupil_button)
	heartbeat_temperature.hide()
	heartbeat_temperature.set_process(false)
	pupil.show()
	pupil.set_process(true)
	pupil.call("reset_light_tracking")
	_play_sfx(_senter_sfx_player)
	_update_focus_ring()
	pupil_close_button.grab_focus()


func _close_pupil() -> void:
	_play_sfx(_button_sfx_player)
	_stop_sfx(_senter_sfx_player)
	pupil.hide()
	pupil.set_process(false)
	_update_focus_ring()
	_restore_focus(pupil_button)


func _open_heartbeat_temperature() -> void:
	if not _diagnostics_unlocked():
		_play_sfx(_locked_sfx_player)
		return
	_play_sfx(_button_sfx_player)
	_stop_sfx(_senter_sfx_player)
	_remember_focus(heartbeat_temperature_button)
	pupil.hide()
	pupil.set_process(false)
	heartbeat_temperature.show()
	heartbeat_temperature.set_process(true)
	if not _monitor_sfx_player.playing:
		_play_sfx(_monitor_sfx_player)
	_show_tool_reactions("biometric_monitor")
	_update_focus_ring()
	heartbeat_close_button.grab_focus()


func _close_heartbeat_temperature() -> void:
	_play_sfx(_button_sfx_player)
	_stop_sfx(_monitor_sfx_player)
	heartbeat_temperature.hide()
	heartbeat_temperature.set_process(false)
	_update_focus_ring()
	_restore_focus(heartbeat_temperature_button)


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
	if is_accepted:
		_play_sfx(_button_sfx_player)
	else:
		_play_sfx(_reject_sfx_player)
	_stop_tool_sfx()

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
	_stop_sfx(_word_sfx_player)
	_last_word_sfx_ms = -1000
	dialogue_output.clear()
	dialogue_output.visible_characters = 0
	dialogue_output.scroll_following = true
	dialogue_output.scroll_following_visible_characters = true


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
	var timer := get_tree().create_timer(LINE_PAUSE, false)
	while (
		timer.time_left > 0.0
		and generation == _recent_event_generation
		and not _skip_recent_reveal_requested
	):
		await get_tree().process_frame


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
	await get_tree().create_timer(CHARACTER_HOLD_AFTER_OUTCOME, false).timeout
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
	if not _step_sfx_player.playing:
		_play_sfx(_step_sfx_player)
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
	_stop_sfx(_step_sfx_player)
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
		_play_word_sfx()
		if character < final_character:
			await get_tree().create_timer(character_delay, false).timeout
			if generation != _recent_event_generation:
				return
	dialogue_output.visible_characters = final_character


func _scroll_dialogue(direction: float) -> bool:
	var scroll_bar := dialogue_output.get_v_scroll_bar()
	var maximum_scroll := maxf(0.0, scroll_bar.max_value - scroll_bar.page)
	var target := clampf(scroll_bar.value + direction * DIALOGUE_SCROLL_STEP, 0.0, maximum_scroll)
	if is_equal_approx(target, scroll_bar.value):
		return false
	scroll_bar.value = target
	# Stop auto-following while reading history; resume it at the bottom once
	# the current reveal has finished.
	var follow_bottom := (
		target >= maximum_scroll - 0.5
		and not _recent_event_is_revealing
		and _pending_recent_events.is_empty()
	)
	dialogue_output.scroll_following = follow_bottom
	dialogue_output.scroll_following_visible_characters = follow_bottom
	return true


func _on_dialogue_focus_entered() -> void:
	_set_dialogue_scroll_mode(false)


func _on_dialogue_focus_exited() -> void:
	_set_dialogue_scroll_mode(false)


func _set_dialogue_scroll_mode(enabled: bool) -> void:
	if _dialogue_scroll_mode == enabled:
		return
	_dialogue_scroll_mode = enabled


func _focus_adjacent_from_dialogue(forward: bool) -> void:
	var target := (
		dialogue_output.find_next_valid_focus()
		if forward
		else dialogue_output.find_prev_valid_focus()
	)
	if is_instance_valid(target):
		target.grab_focus()


func _open_transcript() -> void:
	_play_sfx(_button_sfx_player)
	_remember_focus(dialogue_output)
	transcript_output.clear()
	if _dialogue_history.is_empty():
		transcript_output.add_text("No dialogue yet.")
	else:
		for event in _dialogue_history:
			_append_formatted_event(transcript_output, event)
	transcript_scroll.set_deferred("scroll_vertical", 0)
	transcript_overlay.show()
	_update_focus_ring()
	close_transcript_button.grab_focus()


func _close_transcript() -> void:
	_play_sfx(_button_sfx_player)
	transcript_overlay.hide()
	_update_focus_ring()
	_restore_focus(dialogue_output)


func _open_id_card() -> void:
	_remember_focus(id_card_button)
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
	_update_focus_ring()
	id_card_close_button.grab_focus()


func _close_id_card() -> void:
	_play_sfx(_button_sfx_player)
	id_card_overlay.hide()
	_update_focus_ring()
	_restore_focus(id_card_button)


func _open_pause_menu(from_button: bool = false) -> void:
	if pause_overlay.visible:
		return
	_play_sfx(_button_sfx_player)
	_remember_focus(pause_button if from_button else null)
	InputGuide.hide_tip()
	pause_overlay.call("open_menu")
	get_tree().paused = true
	_update_focus_ring()
	pause_resume_button.grab_focus()


func _resume_from_pause() -> void:
	_play_sfx(_button_sfx_player)
	pause_overlay.hide()
	get_tree().paused = false
	_update_focus_ring()
	_restore_focus(pause_button)
	InputGuide.refresh_active_tip()


func _return_to_main_menu() -> void:
	get_tree().paused = false
	InputGuide.leave_context()
	return_to_main_menu.emit()


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
	_update_focus_ring()


func _on_log_panel_opened() -> void:
	_remember_focus(intlog_button)
	_update_focus_ring()


func _on_log_panel_closed() -> void:
	_update_focus_ring()
	_restore_focus(intlog_button)


func _default_focus_controls() -> Array:
	var controls: Array = [
		intlog_button,
		id_card_button,
		dialogue_output,
		accept_button,
		decline_button,
	]
	if not pupil_button.disabled:
		controls.append(pupil_button)
	if not heartbeat_temperature_button.disabled:
		controls.append(heartbeat_temperature_button)
	controls.append(pause_button)
	return controls


func _update_focus_ring() -> void:
	if pause_overlay.visible:
		_set_focus_ring([pause_resume_button, pause_how_to_play_button, pause_main_menu_button])
		return
	if pupil.visible:
		_set_focus_ring([pupil_close_button])
		return
	if heartbeat_temperature.visible:
		_set_focus_ring([heartbeat_close_button])
		return
	if id_card_overlay.visible:
		_set_focus_ring([id_card_close_button])
		return
	if transcript_overlay.visible:
		_set_focus_ring([close_transcript_button])
		return
	if bool(television.get("log_open")):
		_set_focus_ring(television.call("get_log_focus_controls"))
		return
	_set_focus_ring(_default_focus_controls())


func _set_focus_ring(controls: Array) -> void:
	var ring: Array[Control] = []
	for control in controls:
		if control is Control and is_instance_valid(control):
			var focus_control := control as Control
			focus_control.focus_mode = Control.FOCUS_ALL
			ring.append(focus_control)
	if ring.is_empty():
		return

	for index in ring.size():
		var control := ring[index]
		var previous := ring[(index - 1 + ring.size()) % ring.size()]
		var next := ring[(index + 1) % ring.size()]
		var previous_path := control.get_path_to(previous)
		var next_path := control.get_path_to(next)
		control.focus_neighbor_top = previous_path
		control.focus_neighbor_left = previous_path
		control.focus_neighbor_bottom = next_path
		control.focus_neighbor_right = next_path
		control.focus_next = next_path
		control.focus_previous = previous_path


func _remember_focus(preferred: Control = null) -> void:
	var focus_owner := get_viewport().gui_get_focus_owner()
	if is_instance_valid(preferred):
		_focus_return_target = preferred
	elif is_instance_valid(focus_owner):
		_focus_return_target = focus_owner


func _restore_focus(fallback: Control) -> void:
	var target := _focus_return_target
	_focus_return_target = null
	if _can_take_focus(target):
		target.grab_focus()
		return
	if _can_take_focus(fallback):
		fallback.grab_focus()


func _can_take_focus(control: Control) -> bool:
	if control == null or not is_instance_valid(control):
		return false
	if not control.is_inside_tree() or not control.is_visible_in_tree():
		return false
	if control.focus_mode == Control.FOCUS_NONE:
		return false
	if control is BaseButton and (control as BaseButton).disabled:
		return false
	return true


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
