extends Control

const TOTAL_DAYS := 5
const TOTAL_HUMANS := 6
const INTERLUDE_SCENE: PackedScene = preload("res://scenes/interlude.tscn")
const PROLOGUE_SCENE: PackedScene = preload("res://scenes/prologue.tscn")
const DAY_INTRO_SCENE: PackedScene = preload("res://scenes/day_intro.tscn")
const MORNING_REPORT_SCENE: PackedScene = preload("res://scenes/morning_report.tscn")
const TEMPO_GAMEPLAY_SCENE: PackedScene = preload("res://scenes/gameplay.tscn")
const NIGHT_EVALUATION_SCENE: PackedScene = preload("res://scenes/night_eval.tscn")
const FINAL_EVALUATION_SCENE: PackedScene = preload("res://scenes/final_evaluation.tscn")
const ENDING_SCENE: PackedScene = preload("res://scenes/ending.tscn")
const SAVE_SLOT_COUNT := 4
const SAVE_PATH_FORMAT := "user://save_slot_%d.json"
const REPORT_TEXT_PATH := "res://data/report_text.json"
const MORNING_REPORT_PATH_FORMAT := "res://data/morning_report%d.json"
const NIGHT_EVALUATION_PATH_FORMAT := "res://data/night_eval%d.json"
const ENDINGS_PATH := "res://data/endings.json"
## Ambang pemilihan ending (persen) sesuai dokumen "Ending final".
const ENDING_EARLY_TRIGGER_VALUE := 100
const ENDING_OUTBREAK_INFILTRATION := 50
const ENDING_SANCTUARY_MIN_SAVED := 5
const ENDING_FORTRESS_A_MAX_SUSPICION := 20
## Pengurang suspicion (persen) bila satu hari selesai tanpa kenaikan suspicion.
const PERFECT_DAY_SUSPICION_REDUCTION := 10
const MENU_BGM: AudioStream = preload("res://assets/bgm/menu.wav")
const DAY1_TO_3_BGM: AudioStream = preload("res://assets/bgm/day1to3.wav")
const DAY4_TO_5_BGM: AudioStream = preload("res://assets/bgm/day4to5.wav")
const TRUE_ENDING_BGM: AudioStream = preload("res://assets/bgm/trueending.wav")
const MILITARY_ENDING_BGM: AudioStream = preload("res://assets/bgm/military.wav")
const BAD_ENDING_1_BGM: AudioStream = preload("res://assets/bgm/badending.wav")
const BAD_ENDING_2_BGM: AudioStream = preload("res://assets/bgm/badending2.wav")
const REPORT_SFX: AudioStream = preload("res://assets/bgm/report.wav")
const BUTTON_SFX: AudioStream = preload("res://assets/bgm/button.mp3")

var _timeline: Array[Dictionary] = []
var _report_text: Dictionary = {}
var _morning_reports: Array[Dictionary] = []
var _night_evaluation_reports: Array[Dictionary] = []
var _endings: Dictionary = {}
var _timeline_index := 0
var _active_scene: Node
var _game_started := false
var _active_save_slot := -1
var _selected_save_slot := -1
var _save_slots: Array[Dictionary] = []

@onready var _main_menu := $MainMenu
@onready var _save_menu := $SaveMenu
@onready var _settings_menu := $SettingsMenu
@onready var _brightness_modulate := $BrightnessModulate
@onready var _save_content := $SaveMenu/Center/Content
@onready var _brightness_slider := $SettingsMenu/Center/Content/BrightnessRow/BrightnessSlider
@onready var _bgm_player: AudioStreamPlayer = $MenuBGM
var _report_sfx_player: AudioStreamPlayer
var _button_sfx_player: AudioStreamPlayer

func _ready() -> void:
	_timeline = _build_timeline()
	_report_text = _load_json_dictionary(REPORT_TEXT_PATH)
	for day in range(1, TOTAL_DAYS + 1):
		_morning_reports.append(_load_json_dictionary(MORNING_REPORT_PATH_FORMAT % day))
	for day in range(1, TOTAL_DAYS):
		_night_evaluation_reports.append(_load_json_dictionary(NIGHT_EVALUATION_PATH_FORMAT % day))
	_endings = _load_json_dictionary(ENDINGS_PATH)
	_load_save_slots()
	$MainMenu/Buttons/PlayGameButton.pressed.connect(_open_save_menu)
	$MainMenu/Buttons/SettingsButton.pressed.connect(_open_settings_menu)
	$MainMenu/Buttons/QuitButton.pressed.connect(_quit_game)
	$SettingsMenu/Center/Content/BackButton.pressed.connect(_on_back_to_main_menu_pressed)
	_brightness_slider.value_changed.connect(_on_brightness_changed)
	$SaveMenu/Center/Content/SaveSlot1.pressed.connect(_on_save_slot_pressed.bind(0))
	$SaveMenu/Center/Content/SaveSlot2.pressed.connect(_on_save_slot_pressed.bind(1))
	$SaveMenu/Center/Content/SaveSlot3.pressed.connect(_on_save_slot_pressed.bind(2))
	$SaveMenu/Center/Content/SaveSlot4.pressed.connect(_on_save_slot_pressed.bind(3))
	$SaveMenu/Center/Content/Actions/NewButton.pressed.connect(_create_new_save)
	$SaveMenu/Center/Content/Actions/LoadButton.pressed.connect(_load_selected_save)
	$SaveMenu/Center/Content/Actions/DeleteButton.pressed.connect(_delete_selected_save)

	_report_sfx_player = AudioStreamPlayer.new()
	_report_sfx_player.stream = REPORT_SFX
	_report_sfx_player.volume_db = -2.0
	add_child(_report_sfx_player)

	_button_sfx_player = AudioStreamPlayer.new()
	_button_sfx_player.stream = BUTTON_SFX
	_button_sfx_player.volume_db = -3.0
	add_child(_button_sfx_player)

	_bgm_player.finished.connect(_on_bgm_finished)
	_play_bgm(MENU_BGM)
	_refresh_save_menu()


func _unhandled_input(event: InputEvent) -> void:
	if not _game_started:
		if _settings_menu.visible and event.is_action_pressed("ui_cancel"):
			_play_button_sfx()
			_show_main_menu()
			get_viewport().set_input_as_handled()
			return
		if _save_menu.visible and event.is_action_pressed("ui_cancel"):
			_play_button_sfx()
			_show_main_menu()
			get_viewport().set_input_as_handled()
		return
	if is_instance_valid(_active_scene) and _active_scene.find_child("TerimaButton", true, false):
		return
	var should_advance := false
	if event is InputEventKey:
		var key_event := event as InputEventKey
		should_advance = key_event.pressed and not key_event.echo and (
			key_event.keycode == KEY_ENTER or key_event.keycode == KEY_KP_ENTER
		)
	elif event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		should_advance = mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed
	if should_advance:
		_advance_timeline()
		get_viewport().set_input_as_handled()


func _play_button_sfx() -> void:
	if is_instance_valid(_button_sfx_player):
		_button_sfx_player.play()


func _open_save_menu() -> void:
	_play_button_sfx()
	_selected_save_slot = -1
	_main_menu.hide()
	_settings_menu.hide()
	_save_menu.show()
	_refresh_save_menu()


func _open_settings_menu() -> void:
	_play_button_sfx()
	_main_menu.hide()
	_save_menu.hide()
	_settings_menu.show()
	_brightness_slider.grab_focus()


func _on_back_to_main_menu_pressed() -> void:
	_play_button_sfx()
	_show_main_menu()


func _show_main_menu() -> void:
	_save_menu.hide()
	_settings_menu.hide()
	_main_menu.show()
	_play_bgm(MENU_BGM)


func _bgm_volume_for(stream: AudioStream) -> float:
	if stream == MENU_BGM or stream == DAY1_TO_3_BGM:
		return -6.0
	if stream == DAY4_TO_5_BGM:
		return -5.0
	if stream == TRUE_ENDING_BGM:
		return -2.0
	if stream == MILITARY_ENDING_BGM:
		return -4.0
	if stream == BAD_ENDING_1_BGM:
		return -2.5
	if stream == BAD_ENDING_2_BGM:
		return -8.5
	return -6.0


func _play_bgm(stream: AudioStream) -> void:
	if not is_instance_valid(_bgm_player):
		return
	if stream == null:
		if _bgm_player.playing:
			_bgm_player.stop()
		_bgm_player.stream = null
		return
	_bgm_player.volume_db = _bgm_volume_for(stream)
	if _bgm_player.stream != stream:
		_bgm_player.stream = stream
		_bgm_player.play()
	elif not _bgm_player.playing:
		_bgm_player.play()


func _on_bgm_finished() -> void:
	if is_instance_valid(_bgm_player) and _bgm_player.stream != null:
		_bgm_player.play()


func _ending_bgm_for(ending_key: String) -> AudioStream:
	match ending_key:
		"humanity_sanctuary":
			return TRUE_ENDING_BGM
		"cold_fortress_a", "cold_fortress_b":
			return MILITARY_ENDING_BGM
		"silent_outbreak":
			return BAD_ENDING_1_BGM
		"traitor_fate":
			return BAD_ENDING_2_BGM
	return MENU_BGM


func _update_bgm_for_step(step: Dictionary) -> void:
	var scene: PackedScene = step.get("scene")
	if scene == INTERLUDE_SCENE:
		_play_bgm(MENU_BGM)
	elif scene == PROLOGUE_SCENE:
		_play_bgm(null)
	elif scene == DAY_INTRO_SCENE:
		_play_bgm(DAY1_TO_3_BGM)
	elif scene == ENDING_SCENE:
		_play_bgm(_ending_bgm_for(_ending_key_for(_active_save_data())))
	elif step.has("day"):
		var day := int(step["day"])
		_play_bgm(DAY1_TO_3_BGM if day <= 3 else DAY4_TO_5_BGM)


func _on_brightness_changed(value: float) -> void:
	_brightness_modulate.color = Color(value, value, value, 1.0)


func _on_save_slot_pressed(slot_index: int) -> void:
	_play_button_sfx()
	_selected_save_slot = slot_index
	_refresh_save_menu()


func _create_new_save() -> void:
	_play_button_sfx()
	if _game_started or _selected_save_slot < 0:
		return
	_active_save_slot = _selected_save_slot
	_save_slots[_active_save_slot] = _new_save_data()
	_start_game_at_timeline_index(0)


func _load_selected_save() -> void:
	_play_button_sfx()
	if _game_started or _selected_save_slot < 0:
		return
	var save_data: Dictionary = _save_slots[_selected_save_slot]
	if save_data.is_empty():
		return
	_active_save_slot = _selected_save_slot
	_start_game_at_timeline_index(int(save_data.get("timeline_index", 0)))


func _delete_selected_save() -> void:
	_play_button_sfx()
	if _game_started or _selected_save_slot < 0:
		return
	if _save_slots[_selected_save_slot].is_empty():
		return
	DirAccess.remove_absolute(_save_path(_selected_save_slot))
	_save_slots[_selected_save_slot] = {}
	_refresh_save_menu()


func _start_game_at_timeline_index(start_index: int) -> void:
	_game_started = true
	_timeline = _build_timeline()
	_timeline_index = clampi(start_index, 0, _timeline.size() - 1)
	_save_current_progress()
	_main_menu.hide()
	_save_menu.hide()
	_show_timeline_step()


func _quit_game() -> void:
	_play_button_sfx()
	get_tree().quit()


func _build_timeline() -> Array[Dictionary]:
	var steps: Array[Dictionary] = [
		{"scene": INTERLUDE_SCENE, "title": "Interlude"},
		{"scene": PROLOGUE_SCENE, "title": "Prologue"},
		{"scene": DAY_INTRO_SCENE, "title": "DAY 1"},
	]

	for day in range(1, TOTAL_DAYS + 1):
		steps.append({
			"scene": MORNING_REPORT_SCENE,
			"day": day,
			"report": "morning_report",
		})
		steps.append({"scene": TEMPO_GAMEPLAY_SCENE, "title": "Afternoon", "day": day})
		if day < TOTAL_DAYS:
			steps.append({
				"scene": NIGHT_EVALUATION_SCENE,
				"day": day,
				"report": "night_eval",
			})

	steps.append({
		"scene": FINAL_EVALUATION_SCENE,
		"title": "Final Evaluation",
		"report": "final_evaluation",
	})
	steps.append({"scene": ENDING_SCENE, "title": "Ending"})
	return steps


func _advance_timeline() -> void:
	if _timeline_index >= _timeline.size() - 1:
		_complete_active_save()
		if is_instance_valid(_active_scene):
			_active_scene.queue_free()
		_active_scene = null
		_game_started = false
		_active_save_slot = -1
		_refresh_save_menu()
		_show_main_menu()
		return
	# Evaluasi malam yang memicu ending dini (infiltrasi / suspicion 100%):
	# sisa hari dilewati, langsung ke Evaluasi Akhir lalu ending.
	var current_step: Dictionary = _timeline[_timeline_index]
	if (
		str(current_step.get("report", "")) == "night_eval"
		and _early_ending_triggered(_active_save_data())
	):
		_timeline_index = _timeline.size() - 2
	else:
		_timeline_index += 1
	_save_current_progress()
	_show_timeline_step()


func _load_save_slots() -> void:
	_save_slots.clear()
	for slot_index in range(SAVE_SLOT_COUNT):
		var save_data: Dictionary = {}
		var path := _save_path(slot_index)
		if FileAccess.file_exists(path):
			var file := FileAccess.open(path, FileAccess.READ)
			if file:
				var parsed = JSON.parse_string(file.get_as_text())
				if parsed is Dictionary and parsed.has("timeline_index"):
						save_data = {
						"timeline_index": int(parsed["timeline_index"]),
						"completed": bool(parsed.get("completed", false)),
						"suspicion": int(parsed.get("suspicion", 0)),
						"infiltration": int(parsed.get("infiltration", 0)),
						"accepted_count": maxi(0, int(parsed.get("accepted_count", 0))),
						"declined_count": maxi(0, int(parsed.get("declined_count", 0))),
						"empty_accepted_count": maxi(0, int(parsed.get("empty_accepted_count", 0))),
						"empty_declined_count": maxi(0, int(parsed.get("empty_declined_count", 0))),
						"daily_decisions": parsed["daily_decisions"] if parsed.get("daily_decisions") is Dictionary else {},
					}
		_save_slots.append(save_data)


func _load_json_dictionary(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Could not open JSON data: %s" % path)
		return {}

	var parsed = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		push_error("JSON data at '%s' must contain an object." % path)
		return {}
	return parsed


func _apply_report_text(scene: Node, report_key: String, day: int) -> void:
	if report_key == "morning_report":
		if not scene.has_method("set_report_text"):
			push_error("The morning report scene cannot display report text.")
			return
		if day < 1 or day > _morning_reports.size():
			push_error("Morning report data is missing for day %d." % day)
			return
		var report := _format_report(
			_morning_reports[day - 1], _morning_report_values(_active_save_data())
		)
		scene.call("set_report_text", report)
		return

	if report_key == "night_eval":
		if not scene.has_method("set_report_text"):
			push_error("The night evaluation scene cannot display report text.")
			return
		if day < 1 or day > _night_evaluation_reports.size():
			push_error("Night evaluation data is missing for day %d." % day)
			return
		var report_template := _night_evaluation_reports[day - 1]
		var report := _format_report(
			report_template,
			_night_evaluation_values(_active_save_data(), day, report_template)
		)
		scene.call("set_report_text", report)
		return

	if report_key == "final_evaluation":
		if not scene.has_method("set_report_text"):
			push_error("The final evaluation scene cannot display report text.")
			return
		var final_eval_template: Variant = _endings.get("final_evaluation", {})
		if not final_eval_template is Dictionary or (final_eval_template as Dictionary).is_empty():
			push_error("Final evaluation data is missing in %s." % ENDINGS_PATH)
			return
		var report := _format_report(
			final_eval_template as Dictionary,
			_final_evaluation_values(_active_save_data())
		)
		scene.call("set_report_text", report)
		return

	if not _report_text.has(report_key):
		push_error("Report text data is missing '%s'." % report_key)
		return

	var report = _report_text[report_key]
	if not report is Dictionary:
		push_error("Report text data for '%s' must contain a JSON object." % report_key)
		return

	for node_path in report:
		var text_node := scene.get_node_or_null(str(node_path))
		var text := str(report[node_path]).format({"day": day})
		if text_node is Label:
			(text_node as Label).text = text
		elif text_node is Button:
			(text_node as Button).text = text
		else:
			push_error("Report text node '%s' was not found in %s." % [node_path, scene.name])
			continue


## Mengisi placeholder teks laporan dengan nilai band (mis. {band_infiltrasi}).
func _format_report(report: Dictionary, values: Dictionary) -> Dictionary:
	var formatted := report.duplicate()
	for field in ["label", "header", "continue_text", "body"]:
		if formatted.has(field):
			formatted[field] = str(formatted[field]).format(values)
	return formatted


func _active_save_data() -> Dictionary:
	if _active_save_slot >= 0 and _active_save_slot < _save_slots.size():
		return _save_slots[_active_save_slot]
	return {}


## Pemain hanya melihat band, bukan persen asli (persen hanya tampil di ending).
func _infiltration_band(value: int) -> String:
	if value >= 75:
		return "Kritis"
	if value >= 50:
		return "Waspada"
	return "Rendah"


## Band Pelanggaran Tercatat dan kuota pertanyaan interogasi dari suspicion:
## 0-19% = Rendah / 2, 20-39% = Waspada / 3, >= 40% = Kritis / 4.
func _morning_report_values(save_data: Dictionary) -> Dictionary:
	var suspicion := int(save_data.get("suspicion", 0))
	var violation_band := "Rendah"
	var required_questions := 2
	if suspicion >= 40:
		violation_band = "Kritis"
		required_questions = 4
	elif suspicion >= 20:
		violation_band = "Waspada"
		required_questions = 3
	return {
		"band_infiltrasi": _infiltration_band(int(save_data.get("infiltration", 0))),
		"band_pelanggaran": violation_band,
		"syarat": required_questions,
	}


func _night_evaluation_values(
	save_data: Dictionary,
	day: int,
	report_template: Dictionary
) -> Dictionary:
	var daily_decisions: Dictionary = {}
	var stored_daily_decisions: Variant = save_data.get("daily_decisions", {})
	if stored_daily_decisions is Dictionary:
		var stored_day_decisions: Variant = stored_daily_decisions.get(str(day), {})
		if stored_day_decisions is Dictionary:
			daily_decisions = stored_day_decisions
	var infiltration := int(save_data.get("infiltration", 0))
	var baris2 := str(report_template.get("baris2", ""))
	if baris2.is_empty():
		baris2 = str(
			report_template.get(
				"baris2_waspada"
				if _infiltration_band(infiltration) != "Rendah"
				else "baris2_rendah",
				""
			)
		)
	return {
		"diterima": maxi(0, int(daily_decisions.get("accepted_count", 0))),
		"ditolak": maxi(0, int(daily_decisions.get("declined_count", 0))),
		"baris1": str(report_template.get("baris1", "")),
		"baris2": baris2,
	}


func _final_evaluation_values(save_data: Dictionary) -> Dictionary:
	return {
		"infiltration": clampi(int(save_data.get("infiltration", 0)), 0, 100),
		"violations": clampi(int(save_data.get("suspicion", 0)), 0, 100),
		"saved": _humans_saved(save_data),
		"human_total": TOTAL_HUMANS,
	}


## Manusia yang diterima = total diterima dikurangi The Empty yang diterima.
func _humans_saved(save_data: Dictionary) -> int:
	return maxi(
		0,
		int(save_data.get("accepted_count", 0)) - int(save_data.get("empty_accepted_count", 0))
	)


## True bila ending harus langsung terpicu (permainan berhenti di tengah jalan):
## Infiltrasi Empty 100% (Silent Outbreak) atau Kecurigaan Militer 100% (Traitor's Fate).
func _early_ending_triggered(save_data: Dictionary) -> bool:
	return (
		int(save_data.get("infiltration", 0)) >= ENDING_EARLY_TRIGGER_VALUE
		or int(save_data.get("suspicion", 0)) >= ENDING_EARLY_TRIGGER_VALUE
	)


## Memilih ending (tepat satu) sesuai dokumen "Ending final", dengan urutan:
## Silent Outbreak (infiltrasi 100) > Traitor's Fate (suspicion 100) >
## Silent Outbreak (infiltrasi >= 50) > Humanity's Sanctuary (saved >= 5) >
## The Cold Military Fortress (versi A bila pelanggaran < 20%, selain itu B).
func _ending_key_for(save_data: Dictionary) -> String:
	var infiltration := int(save_data.get("infiltration", 0))
	var suspicion := int(save_data.get("suspicion", 0))
	if infiltration >= ENDING_EARLY_TRIGGER_VALUE:
		return "silent_outbreak"
	if suspicion >= ENDING_EARLY_TRIGGER_VALUE:
		return "traitor_fate"
	if infiltration >= ENDING_OUTBREAK_INFILTRATION:
		return "silent_outbreak"
	if _humans_saved(save_data) >= ENDING_SANCTUARY_MIN_SAVED:
		return "humanity_sanctuary"
	if suspicion < ENDING_FORTRESS_A_MAX_SUSPICION:
		return "cold_fortress_a"
	return "cold_fortress_b"


func _selected_ending_data() -> Dictionary:
	var key := _ending_key_for(_active_save_data())
	var data: Variant = _endings.get(key, {})
	if not data is Dictionary or data.is_empty():
		push_error("Ending data '%s' is missing in %s." % [key, ENDINGS_PATH])
		return {}
	return data


func _refresh_save_menu() -> void:
	for slot_index in range(SAVE_SLOT_COUNT):
		var button := _save_content.get_node("SaveSlot%d" % (slot_index + 1)) as Button
		var is_occupied := not _save_slots[slot_index].is_empty()
		var status := "EMPTY"
		if is_occupied:
			if bool(_save_slots[slot_index].get("completed", false)):
				status = "COMPLETE"
			else:
					status = "IN PROGRESS - DAY %d" % _day_for_timeline_index(int(_save_slots[slot_index].get("timeline_index", 0)))
		button.text = "SAVE FILE %d - %s" % [slot_index + 1, status]

	var has_selection := _selected_save_slot >= 0
	var new_button := _save_content.get_node("Actions/NewButton") as Button
	var load_button := _save_content.get_node("Actions/LoadButton") as Button
	var delete_button := _save_content.get_node("Actions/DeleteButton") as Button
	new_button.disabled = not has_selection
	load_button.disabled = not has_selection
	delete_button.disabled = not has_selection

func _save_current_progress() -> void:
	if _active_save_slot < 0:
		return
	var save_data: Dictionary = _save_slots[_active_save_slot].duplicate()
	save_data["timeline_index"] = _timeline_index
	save_data["completed"] = bool(save_data.get("completed", false))
	_write_save_data(save_data)


func _complete_active_save() -> void:
	if _active_save_slot < 0:
		return
	var save_data: Dictionary = _save_slots[_active_save_slot].duplicate()
	save_data["timeline_index"] = _timeline_index
	save_data["completed"] = true
	_write_save_data(save_data)


func _new_save_data() -> Dictionary:
	return {
		"timeline_index": 0,
		"completed": false,
		"suspicion": 0,
		"infiltration": 0,
		"accepted_count": 0,
		"declined_count": 0,
		"empty_accepted_count": 0,
		"empty_declined_count": 0,
		"daily_decisions": {},
	}


func _on_admission_decision(is_accepted: bool) -> void:
	if _active_save_slot >= 0:
		var save_data: Dictionary = _save_slots[_active_save_slot].duplicate()
		var decision_counter := "accepted_count" if is_accepted else "declined_count"
		save_data[decision_counter] = int(save_data.get(decision_counter, 0)) + 1

		var daily_decisions: Dictionary = {}
		var stored_daily_decisions: Variant = save_data.get("daily_decisions", {})
		if stored_daily_decisions is Dictionary:
			daily_decisions = stored_daily_decisions.duplicate()
		var day_key := str(int(_timeline[_timeline_index].get("day", 1)))
		var day_decisions: Dictionary = {}
		var stored_day_decisions: Variant = daily_decisions.get(day_key, {})
		if stored_day_decisions is Dictionary:
			day_decisions = stored_day_decisions.duplicate()
		day_decisions[decision_counter] = int(day_decisions.get(decision_counter, 0)) + 1
		daily_decisions[day_key] = day_decisions
		save_data["daily_decisions"] = daily_decisions

		var case_tracking: Dictionary = {}
		if is_instance_valid(_active_scene) and _active_scene.has_method("get_case_tracking_data"):
			var tracking_data: Variant = _active_scene.call("get_case_tracking_data")
			if tracking_data is Dictionary:
				case_tracking = tracking_data

		if bool(case_tracking.get("is_empty", false)):
			var empty_decision_counter := "empty_accepted_count" if is_accepted else "empty_declined_count"
			save_data[empty_decision_counter] = int(save_data.get(empty_decision_counter, 0)) + 1

		var all_decision_effects: Variant = case_tracking.get("decision_effects", {})
		if all_decision_effects is Dictionary:
			var decision_key := "accept" if is_accepted else "decline"
			var decision_effects: Variant = all_decision_effects.get(decision_key, {})
			if decision_effects is Dictionary:
				for metric in ["suspicion", "infiltration"]:
					var current_value := int(save_data.get(metric, 0))
					var change := int(decision_effects.get(metric, 0))
					save_data[metric] = clampi(current_value + change, 0, 100)
					if metric == "suspicion" and change > 0:
						day_decisions["suspicion_gained"] = int(day_decisions.get("suspicion_gained", 0)) + change

		# Perfect Day: pemohon terakhir hari ini diputuskan dan tidak ada kenaikan
		# suspicion sepanjang hari (tidak ada Empty / pelanggar SOP yang diterima).
		if (
			bool(case_tracking.get("is_last_applicant", false))
			and int(day_decisions.get("suspicion_gained", 0)) == 0
		):
			save_data["suspicion"] = clampi(
				int(save_data.get("suspicion", 0)) - PERFECT_DAY_SUSPICION_REDUCTION, 0, 100
			)

		_write_save_data(save_data)
	if is_instance_valid(_active_scene) and _active_scene.has_method("show_decision_outcome"):
		_active_scene.call("show_decision_outcome", is_accepted)
		return
	_advance_timeline()


func _write_save_data(save_data: Dictionary) -> void:
	if _active_save_slot < 0:
		return
	var file := FileAccess.open(_save_path(_active_save_slot), FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(save_data))
	_save_slots[_active_save_slot] = save_data


func _day_for_timeline_index(saved_index: int) -> int:
	if _timeline.is_empty():
		return 1
	var index := clampi(saved_index, 0, _timeline.size() - 1)
	var step: Dictionary = _timeline[index]
	if step.has("day"):
		return int(step["day"])
	if index >= _timeline.size() - 2:
		return TOTAL_DAYS
	return 1


func _save_path(slot_index: int) -> String:
	return SAVE_PATH_FORMAT % (slot_index + 1)


func _show_timeline_step() -> void:
	if is_instance_valid(_active_scene):
		_active_scene.queue_free()

	var step: Dictionary = _timeline[_timeline_index]
	_update_bgm_for_step(step)
	var packed_scene: PackedScene = step["scene"]
	_active_scene = packed_scene.instantiate()
	if step.has("day") and "day" in _active_scene:
		_active_scene.set("day", int(step["day"]))
	# Kuota pertanyaan interogasi mengikuti band suspicion (2/3/4).
	if "scan_unlock_questions_override" in _active_scene:
		_active_scene.set(
			"scan_unlock_questions_override",
			int(_morning_report_values(_active_save_data())["syarat"])
		)
	if _active_scene.has_method("set_ending_data"):
		_active_scene.call("set_ending_data", _selected_ending_data())
	add_child(_active_scene)

	var title_label := _active_scene.get_node_or_null("Title") as Label
	if title_label:
		title_label.text = str(step.get("title", ""))

	var day_label := _active_scene.get_node_or_null("DayLabel") as Label
	if day_label and step.has("day"):
		day_label.text = "HARI %d" % int(step["day"])

	var report_key := str(step.get("report", ""))
	if not report_key.is_empty():
		_apply_report_text(_active_scene, report_key, int(step.get("day", 1)))
		if is_instance_valid(_report_sfx_player):
			_report_sfx_player.play()

	var continue_button := _active_scene.get_node_or_null("ContinueButton") as Button
	if continue_button:
		continue_button.pressed.connect(_advance_timeline)
	if _active_scene.has_signal("outcome_finished"):
		_active_scene.connect("outcome_finished", _advance_timeline)

	# Scene gameplay mengurus tombol Terima/Tolak sendiri dan memancarkan
	# shift_finished setelah semua karakter hari itu selesai diputuskan.
	if _active_scene.has_signal("shift_finished"):
		_active_scene.connect("shift_finished", _advance_timeline)

	# Keputusan Terima/Tolak per pemohon disimpan (suspicion, infiltrasi, hitungan).
	if _active_scene.has_signal("decision_made"):
		_active_scene.connect("decision_made", _on_admission_decision)
