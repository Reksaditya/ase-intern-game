extends Node2D

## Dipancarkan setelah semua pemohon hari ini selesai diputuskan.
## main.gd mendengarkan sinyal ini untuk lanjut ke Evaluasi Malam.
signal shift_finished
## Dipertahankan untuk kompatibilitas dengan main.gd lama. Hanya dipancarkan
## kalau tidak ada yang mendengarkan shift_finished (lihat _finish_shift).
signal outcome_finished
## Dipancarkan sekali per pemohon saat Terima/Tolak ditekan; main.gd menyimpan efeknya.
signal decision_made(is_accepted: bool)

const DEFAULT_SCAN_UNLOCK_QUESTIONS := 2
const WORD_REVEAL_INTERVAL := 0.12
const SPEAKER_CHANGE_PAUSE := 0.6
## Kehalusan scroll otomatis kotak dialog. Makin besar = makin cepat menyusul teks.
const DIALOGUE_SCROLL_SMOOTHING := 10.0
const FIRST_CHARACTER_DELAY := 0.6
const NEXT_CHARACTER_DELAY := 0.8
## Data pemohon: res://data/d<hari>p<urutan>.json (d1p1.json, d1p2.json, ...).
## Pemohon dimuat berurutan sampai file berikutnya tidak ada.
const CHARACTER_DATA_PATH_FORMAT := "res://data/d%dp%d.json"
const LOCKED_SFX: AudioStream = preload("res://assets/bgm/locked.mp3")
const BUTTON_SFX: AudioStream = preload("res://assets/bgm/button.mp3")
const SENTER_SFX: AudioStream = preload("res://assets/bgm/senter.wav")
const MONITOR_SFX: AudioStream = preload("res://assets/bgm/monitor.wav")
const WORD_SFX: AudioStream = preload("res://assets/bgm/word.wav")

## Aturan per hari. Hari yang belum ditulis memakai aturan hari terakhir yang ada.
## scan_unlock_questions = jumlah pertanyaan berbeda sebelum alat pemindai terbuka.
const DAY_RULES := {
	1: {
		"sop": "SOP DASAR — Cek ID Card & Suhu Referensi. Belum ada threshold penolakan ketat hari ini.",
		"scan_unlock_questions": 2,
	},
}

@onready var pupil: Control = $HUD/Pupil
@onready var television: Node = $Sprite2D
@onready var bunker: Bunker = $bunker
@onready var diagnostic_tools: Control = $HUD/DiagnosticTools
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

## Diisi oleh main.gd sebelum scene masuk tree.
var day := 1

## Hasil keputusan per pemohon, bisa dipakai untuk Evaluasi Malam.
var results: Array[Dictionary] = []
## Total efek keputusan hari ini (mis. suspicion, infiltration), dijumlah dari
## "decision_effects" di JSON tiap pemohon.
var stats: Dictionary = {}
## Jumlah pertanyaan interogasi sebelum alat pemindai terbuka. Bila > 0, menimpa
## aturan hari; diisi main.gd dari band Pelanggaran Tercatat (2 / 3 / 4).
var scan_unlock_questions_override := 0

var _scan_unlock_questions := DEFAULT_SCAN_UNLOCK_QUESTIONS
var _data_day := 1
var _next_index := 0
var _character_present := false
var _last_decision_accepted := false

var _current_character: Dictionary = {}
var _asked_question_ids: Dictionary = {}
var _shown_tool_reactions: Dictionary = {}
var _dialogue_history: Array[Dictionary] = []
var _pending_recent_events: Array[Dictionary] = []
var _recent_event_generation := 0
var _recent_event_is_revealing := false
var _last_recent_speaker := ""
var _decision_outcome_started := false
var _dialogue_scroll_target := 0.0
var _dialogue_following := false
var _locked_sfx_player: AudioStreamPlayer
var _button_sfx_player: AudioStreamPlayer
var _senter_sfx_player: AudioStreamPlayer
var _monitor_sfx_player: AudioStreamPlayer
var _word_sfx_player: AudioStreamPlayer


func _ready() -> void:
	# Scroll dialog diatur dari kode (per baris, mengikuti teks yang sedang
	# diketik), jadi scroll_following bawaan RichTextLabel dimatikan.
	dialogue_output.scroll_following = false
	_connect_television()
	pupil_button.pressed.connect(_open_pupil)
	pupil.connect("close_requested", _close_pupil)
	pupil.connect("tool_reaction_requested", _show_tool_reactions)
	heartbeat_temperature_button.pressed.connect(_open_heartbeat_temperature)
	heartbeat_temperature.connect("close_requested", _close_heartbeat_temperature)
	outcome_continue_button.pressed.connect(_on_outcome_continue_pressed)
	transcript_click_area.pressed.connect(_open_transcript)
	close_transcript_button.pressed.connect(_close_transcript)
	id_card_close_button.pressed.connect(_close_id_card)
	bunker.character_arrived.connect(_on_character_arrived)
	bunker.character_left.connect(_on_character_left)
	bunker.decision_made.connect(show_decision_outcome)
	pupil.set_process(false)
	heartbeat_temperature.set_process(false)
	_setup_audio_players()

	_apply_day_rules()
	_data_day = day if FileAccess.file_exists(CHARACTER_DATA_PATH_FORMAT % [day, 1]) else 1
	_refresh_diagnostic_access()

	await get_tree().create_timer(FIRST_CHARACTER_DELAY).timeout
	_start_next_character()


## Scroll bar kotak dialog meluncur halus ke target selama teks diketik.
## Setelah teks selesai, kendali kembali ke pemain (mouse wheel / drag scroll bar).
func _process(delta: float) -> void:
	if not _dialogue_following:
		return
	var bar := dialogue_output.get_v_scroll_bar()
	var next_value := lerpf(bar.value, _dialogue_scroll_target, 1.0 - exp(-DIALOGUE_SCROLL_SMOOTHING * delta))
	bar.value = next_value
	var settled := absf(next_value - _dialogue_scroll_target) < 0.5
	if settled and not _recent_event_is_revealing and _pending_recent_events.is_empty():
		bar.value = _dialogue_scroll_target
		_dialogue_following = false


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
		if mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_LEFT:
			if (
				diagnostic_tools.visible
				and (
					(pupil_button.disabled and pupil_button.get_global_rect().has_point(mouse_event.position))
					or (heartbeat_temperature_button.disabled and heartbeat_temperature_button.get_global_rect().has_point(mouse_event.position))
				)
			):
				if is_instance_valid(_locked_sfx_player):
					_locked_sfx_player.play()
				get_viewport().set_input_as_handled()
				return
			if transcript_click_area.get_global_rect().has_point(mouse_event.position):
				_open_transcript()
				get_viewport().set_input_as_handled()


# --- Alur shift --------------------------------------------------------------

func _connect_television() -> void:
	# Sinyal pertanyaan: question_asked (kunci pertanyaan) atau category_selected
	# (nama kategori). Keduanya diteruskan ke handler yang sama.
	if television.has_signal("question_asked"):
		television.connect("question_asked", _on_question_asked)
	elif television.has_signal("category_selected"):
		television.connect("category_selected", _on_question_asked)
	else:
		push_error("Television needs a question_asked or category_selected signal.")
	if television.has_signal("id_card_requested"):
		television.connect("id_card_requested", _open_id_card)
	else:
		push_error("Television needs an id_card_requested signal.")


func _apply_day_rules() -> void:
	var rules := _rules_for_day(day)
	_scan_unlock_questions = int(rules.get("scan_unlock_questions", DEFAULT_SCAN_UNLOCK_QUESTIONS))
	if scan_unlock_questions_override > 0:
		_scan_unlock_questions = scan_unlock_questions_override
	if rules.has("sop"):
		bunker.set_sop_text(str(rules["sop"]))


func _rules_for_day(d: int) -> Dictionary:
	var best := 1
	for key in DAY_RULES.keys():
		if int(key) <= d and int(key) > best:
			best = int(key)
	return DAY_RULES.get(best, {})


func _character_data_exists(person: int) -> bool:
	return FileAccess.file_exists(CHARACTER_DATA_PATH_FORMAT % [_data_day, person])


func _start_next_character() -> void:
	var person := _next_index + 1
	if not _character_data_exists(person):
		if person == 1:
			push_error("No character data found: %s" % (CHARACTER_DATA_PATH_FORMAT % [_data_day, 1]))
		_finish_shift()
		return

	_reset_for_new_character(_load_character_data(CHARACTER_DATA_PATH_FORMAT % [_data_day, person]))

	var image_path := str(_current_character.get("character_image", ""))
	if image_path.is_empty():
		image_path = str(_current_character.get("texture", ""))
	var offset_y := float(_current_character.get("offset_y", 0.0))
	bunker.spawn_character(image_path, offset_y)


func _reset_for_new_character(data: Dictionary) -> void:
	_current_character = data
	_character_present = false
	_decision_outcome_started = false
	_asked_question_ids.clear()
	_shown_tool_reactions.clear()
	_dialogue_history.clear()
	_clear_recent_dialogue()

	bunker.set_decision_enabled(false)
	outcome_continue_button.hide()
	diagnostic_tools.show()
	pupil.hide()
	pupil.set_process(false)
	heartbeat_temperature.hide()
	heartbeat_temperature.set_process(false)
	_stop_tool_sfx()
	pupil.call("set_character_data", _current_character)
	heartbeat_temperature.call("set_character_data", _current_character)
	_refresh_diagnostic_access()


func _on_character_arrived() -> void:
	_character_present = true
	bunker.set_decision_enabled(true)
	_show_pre_interaction()


func _on_outcome_continue_pressed() -> void:
	if is_instance_valid(_button_sfx_player):
		_button_sfx_player.play()
	outcome_continue_button.hide()
	_character_present = false
	var darken := not _last_decision_accepted and bool(_current_character.get("is_empty", false))
	bunker.dismiss_character(_last_decision_accepted, darken)


func _on_character_left(accepted: bool) -> void:
	var effects := _decision_effects_for(accepted)
	for key in effects:
		var value: Variant = effects[key]
		if value is int or value is float:
			stats[key] = stats.get(key, 0) + value
	results.append({
		"index": _next_index,
		"character_id": str(_current_character.get("character_id", "")),
		"accepted": accepted,
	})
	_next_index += 1
	if not _character_data_exists(_next_index + 1):
		_finish_shift()
		return
	await get_tree().create_timer(NEXT_CHARACTER_DELAY).timeout
	_start_next_character()


func _finish_shift() -> void:
	# main.gd baru mendengarkan shift_finished; main.gd lama mendengarkan
	# outcome_finished. Pancarkan yang punya pendengar supaya timeline maju sekali.
	if shift_finished.get_connections().is_empty():
		outcome_finished.emit()
	else:
		shift_finished.emit()


func _decision_effects_for(is_accepted: bool) -> Dictionary:
	var effects: Variant = _current_character.get("decision_effects", {})
	if not effects is Dictionary:
		return {}
	var keys := ["accept", "accepted"] if is_accepted else ["decline", "declined", "reject"]
	for key in keys:
		if effects.get(key) is Dictionary:
			return effects[key]
	return {}


func get_case_tracking_data() -> Dictionary:
	var is_empty := bool(_current_character.get("is_empty", false))
	var decision_effects: Variant = _current_character.get("decision_effects", {})
	return {
		"is_empty": is_empty,
		"decision_effects": decision_effects if decision_effects is Dictionary else {},
		"is_last_applicant": not _character_data_exists(_next_index + 2),
	}


# --- Alat pemindai -----------------------------------------------------------

func _setup_audio_players() -> void:
	_locked_sfx_player = AudioStreamPlayer.new()
	_locked_sfx_player.stream = LOCKED_SFX
	_locked_sfx_player.volume_db = -3.0
	add_child(_locked_sfx_player)

	_button_sfx_player = AudioStreamPlayer.new()
	_button_sfx_player.stream = BUTTON_SFX
	_button_sfx_player.volume_db = -3.0
	add_child(_button_sfx_player)

	_senter_sfx_player = AudioStreamPlayer.new()
	_senter_sfx_player.stream = SENTER_SFX
	_senter_sfx_player.volume_db = 0.0
	add_child(_senter_sfx_player)

	_monitor_sfx_player = AudioStreamPlayer.new()
	_monitor_sfx_player.stream = MONITOR_SFX
	_monitor_sfx_player.volume_db = -4.0
	_monitor_sfx_player.finished.connect(func():
		if heartbeat_temperature.visible:
			_monitor_sfx_player.play()
	)
	add_child(_monitor_sfx_player)

	_word_sfx_player = AudioStreamPlayer.new()
	_word_sfx_player.stream = WORD_SFX
	_word_sfx_player.volume_db = -2.0
	add_child(_word_sfx_player)


func _stop_tool_sfx() -> void:
	if is_instance_valid(_senter_sfx_player) and _senter_sfx_player.playing:
		_senter_sfx_player.stop()
	if is_instance_valid(_monitor_sfx_player) and _monitor_sfx_player.playing:
		_monitor_sfx_player.stop()


func _open_pupil() -> void:
	if not _diagnostics_unlocked():
		if is_instance_valid(_locked_sfx_player):
			_locked_sfx_player.play()
		return
	if is_instance_valid(_button_sfx_player):
		_button_sfx_player.play()
	if is_instance_valid(_monitor_sfx_player) and _monitor_sfx_player.playing:
		_monitor_sfx_player.stop()
	heartbeat_temperature.hide()
	heartbeat_temperature.set_process(false)
	pupil.show()
	pupil.set_process(true)
	if is_instance_valid(_senter_sfx_player):
		_senter_sfx_player.play()


func _close_pupil() -> void:
	if is_instance_valid(_button_sfx_player):
		_button_sfx_player.play()
	if is_instance_valid(_senter_sfx_player) and _senter_sfx_player.playing:
		_senter_sfx_player.stop()
	pupil.hide()
	pupil.set_process(false)
	pupil_button.grab_focus()


func _open_heartbeat_temperature() -> void:
	if not _diagnostics_unlocked():
		if is_instance_valid(_locked_sfx_player):
			_locked_sfx_player.play()
		return
	if is_instance_valid(_button_sfx_player):
		_button_sfx_player.play()
	if is_instance_valid(_senter_sfx_player) and _senter_sfx_player.playing:
		_senter_sfx_player.stop()
	pupil.hide()
	pupil.set_process(false)
	heartbeat_temperature.show()
	heartbeat_temperature.set_process(true)
	if is_instance_valid(_monitor_sfx_player) and not _monitor_sfx_player.playing:
		_monitor_sfx_player.play()
	_show_tool_reactions("biometric_monitor")


func _close_heartbeat_temperature() -> void:
	if is_instance_valid(_button_sfx_player):
		_button_sfx_player.play()
	if is_instance_valid(_monitor_sfx_player) and _monitor_sfx_player.playing:
		_monitor_sfx_player.stop()
	heartbeat_temperature.hide()
	heartbeat_temperature.set_process(false)
	heartbeat_temperature_button.grab_focus()


# --- Pertanyaan & keputusan --------------------------------------------------

func _on_question_asked(question_key: String) -> void:
	if not _character_present or _decision_outcome_started:
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
	if _decision_outcome_started or not _character_present:
		return
	_decision_outcome_started = true
	_last_decision_accepted = is_accepted
	decision_made.emit(is_accepted)

	var outcome_name := "accept" if is_accepted else "decline"
	var all_outcomes: Variant = _current_character.get("outcomes", {})
	var outcome_events: Variant = all_outcomes.get(outcome_name, []) if all_outcomes is Dictionary else []
	_clear_recent_dialogue()
	outcome_continue_button.disabled = true
	if outcome_events is Array:
		for event in outcome_events:
			if event is Dictionary:
				_append_outcome_event(event)

	bunker.set_decision_enabled(false)
	_stop_tool_sfx()
	pupil.hide()
	pupil.set_process(false)
	heartbeat_temperature.hide()
	heartbeat_temperature.set_process(false)
	diagnostic_tools.hide()
	outcome_continue_button.show()
	if not _recent_event_is_revealing and _pending_recent_events.is_empty():
		outcome_continue_button.disabled = false
	outcome_continue_button.grab_focus()


# --- Dialog ------------------------------------------------------------------

func _append_outcome_event(event: Dictionary) -> void:
	var transcript_event := event.duplicate()
	_dialogue_history.append(transcript_event)
	_queue_recent_event(transcript_event)


func _append_dialogue_line(speaker: String, text: String) -> void:
	var event := {"type": "dialogue", "speaker": speaker, "text": text}
	_dialogue_history.append(event)
	_queue_recent_event(event)


## Narasi pembuka + syarat akses alat, ditampilkan setelah karakter tiba di jendela.
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
	if is_instance_valid(_word_sfx_player) and _word_sfx_player.playing:
		_word_sfx_player.stop()
	dialogue_output.clear()
	dialogue_output.visible_characters = 0
	_dialogue_following = false
	_dialogue_scroll_target = 0.0
	dialogue_output.get_v_scroll_bar().value = 0.0


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
		if is_instance_valid(_word_sfx_player):
			_word_sfx_player.play()
		_update_dialogue_scroll_target()
		if word_index < words.size() - 1:
			await get_tree().create_timer(WORD_REVEAL_INTERVAL).timeout
			if generation != _recent_event_generation:
				return
	dialogue_output.visible_characters = final_character
	_update_dialogue_scroll_target()


## Hitung posisi scroll agar baris terakhir yang sudah tampil selalu terlihat
## penuh. Scroll dijatuhkan tepat di awal sebuah baris, jadi baris paling atas
## tidak pernah terpotong separuh.
func _update_dialogue_scroll_target() -> void:
	var total := dialogue_output.get_total_character_count()
	if total <= 0 or dialogue_output.get_line_count() < 2:
		return
	var last_char := clampi(dialogue_output.visible_characters - 1, 0, total - 1)
	var last_line := dialogue_output.get_character_line(last_char)
	var line_height := dialogue_output.get_line_offset(1) - dialogue_output.get_line_offset(0)
	if line_height <= 0.0:
		return
	var rows := maxi(1, floori(dialogue_output.size.y / line_height))
	var top_line := maxi(0, last_line - rows + 1)
	_dialogue_scroll_target = dialogue_output.get_line_offset(top_line)
	_dialogue_following = true


# --- Transcript & ID Card ----------------------------------------------------

func _open_transcript() -> void:
	if is_instance_valid(_button_sfx_player):
		_button_sfx_player.play()
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
	if is_instance_valid(_button_sfx_player):
		_button_sfx_player.play()
	transcript_overlay.hide()
	transcript_click_area.grab_focus()


func _open_id_card() -> void:
	if not _character_present:
		return
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
	if is_instance_valid(_button_sfx_player):
		_button_sfx_player.play()
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
	return _asked_question_ids.size() >= _scan_unlock_questions


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


func _load_character_data(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Could not open character data: %s" % path)
		return {}

	var parsed = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		push_error("Character data must contain a JSON object: %s" % path)
		return {}
	return parsed
