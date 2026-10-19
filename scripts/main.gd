extends Control

const TOTAL_DAYS := 5
const TOTAL_HUMANS := 6
const TIMELINE_VERSION := 3
const DAY5_NIGHT_EVALUATION_OLD_INDEX := 16
const VERSION_2_TO_3_TIMELINE_INDEX_MAP := [
	0, 1, 2, 3, 5, 6, 7, 10, 11, 12, 14, 15, 16, 19, 20, 21, 24, 25,
]
const INTERLUDE_SCENE: PackedScene = preload("res://scenes/interlude.tscn")
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
const CHARACTER_DATA_PATH_FORMAT := "res://data/d%dp%d.json"
const ENDING_DATA_PATHS := {
	"humanity_sanctuary": "res://data/ending_humanity_sanctuary.json",
	"cold_military_fortress_a": "res://data/ending_cold_military_fortress_a.json",
	"cold_military_fortress_b": "res://data/ending_cold_military_fortress_b.json",
	"silent_outbreak": "res://data/ending_silent_outbreak.json",
	"traitors_fate": "res://data/ending_traitors_fate.json",
}

var _timeline: Array[Dictionary] = []
var _report_text: Dictionary = {}
var _morning_reports: Array[Dictionary] = []
var _night_evaluation_reports: Array[Dictionary] = []
var _commander_briefings: Dictionary = {}
var _timeline_index := 0
var _active_scene: Node
var _game_started := false
var _active_save_slot := -1
var _selected_save_slot := -1
var _save_slots: Array[Dictionary] = []
var _windowed_size := Vector2i.ZERO

@onready var _main_menu := $MainMenu
@onready var _save_menu := $SaveMenu
@onready var _settings_menu := $SettingsMenu
@onready var _brightness_modulate := $BrightnessModulate
@onready var _save_content := $SaveMenu/Center/Content
@onready var _brightness_slider := $SettingsMenu/Center/Content/BrightnessRow/BrightnessSlider
@onready var _fullscreen_toggle := $SettingsMenu/Center/Content/FullscreenRow/FullscreenToggle


func _ready() -> void:
	_windowed_size = get_window().size
	_timeline = _build_timeline()
	_report_text = _load_json_dictionary(REPORT_TEXT_PATH)
	_load_report_data()
	_load_save_slots()
	$MainMenu/Buttons/PlayGameButton.pressed.connect(_open_save_menu)
	$MainMenu/Buttons/SettingsButton.pressed.connect(_open_settings_menu)
	$MainMenu/Buttons/QuitButton.pressed.connect(_quit_game)
	$SettingsMenu/Center/Content/BackButton.pressed.connect(_show_main_menu)
	_brightness_slider.value_changed.connect(_on_brightness_changed)
	_fullscreen_toggle.toggled.connect(_on_fullscreen_toggled)
	$SaveMenu/Center/Content/SaveSlot1.pressed.connect(_on_save_slot_pressed.bind(0))
	$SaveMenu/Center/Content/SaveSlot2.pressed.connect(_on_save_slot_pressed.bind(1))
	$SaveMenu/Center/Content/SaveSlot3.pressed.connect(_on_save_slot_pressed.bind(2))
	$SaveMenu/Center/Content/SaveSlot4.pressed.connect(_on_save_slot_pressed.bind(3))
	$SaveMenu/Center/Content/Actions/NewButton.pressed.connect(_create_new_save)
	$SaveMenu/Center/Content/Actions/LoadButton.pressed.connect(_load_selected_save)
	$SaveMenu/Center/Content/Actions/DeleteButton.pressed.connect(_delete_selected_save)
	_refresh_save_menu()


func _unhandled_input(event: InputEvent) -> void:
	if not _game_started:
		if _settings_menu.visible and event.is_action_pressed("ui_cancel"):
			_show_main_menu()
			get_viewport().set_input_as_handled()
			return
		if _save_menu.visible and event.is_action_pressed("ui_cancel"):
			_show_main_menu()
			get_viewport().set_input_as_handled()
		return
	if is_instance_valid(_active_scene) and _active_scene.find_child("TerimaButton", true, false):
		return
	if (
		is_instance_valid(_active_scene)
		and _active_scene.has_method("can_advance")
		and not bool(_active_scene.call("can_advance"))
	):
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


func _open_save_menu() -> void:
	_selected_save_slot = -1
	_main_menu.hide()
	_settings_menu.hide()
	_save_menu.show()
	_refresh_save_menu()


func _open_settings_menu() -> void:
	_main_menu.hide()
	_save_menu.hide()
	_settings_menu.show()
	_fullscreen_toggle.set_pressed_no_signal(_is_window_fullscreen())
	_brightness_slider.grab_focus()


func _show_main_menu() -> void:
	_save_menu.hide()
	_settings_menu.hide()
	_main_menu.show()


func _on_brightness_changed(value: float) -> void:
	_brightness_modulate.color = Color(value, value, value, 1.0)


func _on_fullscreen_toggled(enabled: bool) -> void:
	var window := get_window()
	if enabled:
		if window.mode == Window.MODE_WINDOWED:
			_windowed_size = window.size
		window.mode = Window.MODE_FULLSCREEN
		return

	window.mode = Window.MODE_WINDOWED
	await get_tree().process_frame
	if _windowed_size.x > 0 and _windowed_size.y > 0:
		window.size = _windowed_size


func _is_window_fullscreen() -> bool:
	var mode := get_window().mode
	return mode == Window.MODE_FULLSCREEN or mode == Window.MODE_EXCLUSIVE_FULLSCREEN


func _on_save_slot_pressed(slot_index: int) -> void:
	_selected_save_slot = slot_index
	_refresh_save_menu()


func _create_new_save() -> void:
	if _game_started or _selected_save_slot < 0:
		return
	_active_save_slot = _selected_save_slot
	_save_slots[_active_save_slot] = _new_save_data()
	_start_game_at_timeline_index(0)


func _load_selected_save() -> void:
	if _game_started or _selected_save_slot < 0:
		return
	var save_data: Dictionary = _save_slots[_selected_save_slot]
	if save_data.is_empty():
		return
	_active_save_slot = _selected_save_slot
	_start_game_at_timeline_index(int(save_data.get("timeline_index", 0)))


func _delete_selected_save() -> void:
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
	_main_menu.hide()
	_save_menu.hide()
	_show_timeline_step()


func _quit_game() -> void:
	get_tree().quit()


func _load_report_data() -> void:
	_morning_reports.clear()
	_night_evaluation_reports.clear()
	_commander_briefings.clear()
	for day in range(1, TOTAL_DAYS + 1):
		_morning_reports.append(_load_json_dictionary(MORNING_REPORT_PATH_FORMAT % day))
		var briefing_path := CHARACTER_DATA_PATH_FORMAT % [day, 0]
		if FileAccess.file_exists(briefing_path):
			_commander_briefings[day] = _load_json_dictionary(briefing_path)
		if day < TOTAL_DAYS:
			_night_evaluation_reports.append(
				_load_json_dictionary(NIGHT_EVALUATION_PATH_FORMAT % day)
			)


func _build_timeline() -> Array[Dictionary]:
	var steps: Array[Dictionary] = [
		{"scene": INTERLUDE_SCENE, "title": "Interlude"},
		{"scene": DAY_INTRO_SCENE, "title": "DAY 1"},
	]

	for day in range(1, TOTAL_DAYS + 1):
		steps.append({
			"scene": MORNING_REPORT_SCENE,
			"day": day,
			"report": "morning_report",
		})
		var applicant_index := 1
		while true:
			var character_data_path := CHARACTER_DATA_PATH_FORMAT % [day, applicant_index]
			if not FileAccess.file_exists(character_data_path):
				break
			steps.append({
				"scene": TEMPO_GAMEPLAY_SCENE,
				"title": "Afternoon",
				"day": day,
				"character_data_path": character_data_path,
			})
			applicant_index += 1
		if applicant_index == 1:
			push_error("No applicant character data found for day %d." % day)
		if day < TOTAL_DAYS:
			steps.append({
				"scene": NIGHT_EVALUATION_SCENE,
				"day": day,
				"report": "night_eval",
			})

	steps.append({"scene": FINAL_EVALUATION_SCENE, "title": "Final Evaluation"})
	steps.append({"scene": ENDING_SCENE, "title": "Ending", "is_ending": true})
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

	var current_step: Dictionary = _timeline[_timeline_index]
	if str(current_step.get("report", "")) == "night_eval":
		var night_ending_key := _ending_key_for_night_evaluation(_active_save_data())
		if not night_ending_key.is_empty():
			_timeline_index = _timeline.size() - 1
			_save_current_progress()
			_show_timeline_step()
			return

	_timeline_index += 1
	var next_step: Dictionary = _timeline[_timeline_index]
	if _is_day_end_transition(current_step, next_step):
		_save_current_progress()
	_show_timeline_step()


func _return_to_main_menu() -> void:
	get_tree().paused = false
	if is_instance_valid(_active_scene):
		_active_scene.queue_free()
	_active_scene = null
	_game_started = false
	_active_save_slot = -1
	_selected_save_slot = -1
	_load_save_slots()
	_refresh_save_menu()
	_show_main_menu()


func _is_day_end_transition(current_step: Dictionary, next_step: Dictionary) -> bool:
	var current_day := int(current_step.get("day", 0))
	return current_day > 0 and int(next_step.get("day", 0)) != current_day


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
					var stored_timeline_version := int(parsed.get("timeline_version", 1))
					var timeline_index := _migrate_timeline_index(
						stored_timeline_version,
						int(parsed["timeline_index"])
					)
					var daily_decisions: Variant = parsed.get("daily_decisions", {})
					save_data = {
						"timeline_index": timeline_index,
						"timeline_version": TIMELINE_VERSION,
						"completed": bool(parsed.get("completed", false)),
						"suspicion": int(parsed.get("suspicion", 0)),
						"infiltration": int(parsed.get("infiltration", 0)),
						"accepted_count": maxi(0, int(parsed.get("accepted_count", 0))),
						"declined_count": maxi(0, int(parsed.get("declined_count", 0))),
						"empty_accepted_count": maxi(0, int(parsed.get("empty_accepted_count", 0))),
						"empty_declined_count": maxi(0, int(parsed.get("empty_declined_count", 0))),
						"daily_decisions": daily_decisions if daily_decisions is Dictionary else {},
					}
		_save_slots.append(save_data)


func _migrate_timeline_index(version: int, index: int) -> int:
	var migrated_index := index
	if version < 2 and migrated_index >= DAY5_NIGHT_EVALUATION_OLD_INDEX:
		migrated_index = maxi(DAY5_NIGHT_EVALUATION_OLD_INDEX, migrated_index - 1)
	if version < 3:
		var legacy_index := clampi(
			migrated_index,
			0,
			VERSION_2_TO_3_TIMELINE_INDEX_MAP.size() - 1
		)
		migrated_index = VERSION_2_TO_3_TIMELINE_INDEX_MAP[legacy_index]
	return migrated_index


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

		var report := _morning_reports[day - 1].duplicate()
		var format_values := _morning_report_values(_active_save_data())
		var commander_instruction := _commander_instruction_for_day(day)
		if not commander_instruction.is_empty():
			var body := str(report.get("body", ""))
			report["body"] = body.replace(
				commander_instruction,
				"{instruksi_komandan}"
			)
			format_values["instruksi_komandan"] = commander_instruction
		report = _format_report(report, format_values)
		scene.call("set_report_text", report)
		return

	if report_key == "night_eval":
		if not scene.has_method("set_report_text"):
			push_error("The night evaluation scene cannot display report text.")
			return
		if day < 1 or day > _night_evaluation_reports.size():
			push_error("Night evaluation data is missing for day %d." % day)
			return

		var report := _night_evaluation_reports[day - 1].duplicate()
		var save_data := _active_save_data()
		var daily_decisions: Variant = save_data.get("daily_decisions", {})
		var day_decisions: Dictionary = {}
		if daily_decisions is Dictionary:
			var stored_day_decisions: Variant = daily_decisions.get(str(day), {})
			if stored_day_decisions is Dictionary:
				day_decisions = stored_day_decisions
		var baris2 := str(report.get("baris2", ""))
		if baris2.is_empty():
			var band := _infiltration_band(int(save_data.get("infiltration", 0)))
			var branch_key := "baris2_waspada" if band != "Rendah" else "baris2_rendah"
			baris2 = str(report.get(branch_key, ""))
		var format_values := {
			"diterima": int(day_decisions.get("accepted_count", 0)),
			"ditolak": int(day_decisions.get("declined_count", 0)),
			"baris1": str(report.get("baris1", "")),
			"baris2": baris2,
		}
		report = _format_report(report, format_values)
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


func _ending_key_for_night_evaluation(save_data: Dictionary) -> String:
	if int(save_data.get("infiltration", 0)) >= 100:
		return "silent_outbreak"
	if int(save_data.get("suspicion", 0)) >= 100:
		return "traitors_fate"
	return ""


func _ending_key_for_final_evaluation(save_data: Dictionary) -> String:
	var infiltration := int(save_data.get("infiltration", 0))
	var suspicion := int(save_data.get("suspicion", 0))
	if infiltration >= 100:
		return "silent_outbreak"
	if suspicion >= 100:
		return "traitors_fate"
	if infiltration >= 50:
		return "silent_outbreak"
	if _human_saved_count(save_data) >= 5:
		return "humanity_sanctuary"
	return "cold_military_fortress_a" if suspicion < 20 else "cold_military_fortress_b"


func _human_saved_count(save_data: Dictionary) -> int:
	var accepted_count := int(save_data.get("accepted_count", 0))
	var empty_accepted_count := int(save_data.get("empty_accepted_count", 0))
	return clampi(accepted_count - empty_accepted_count, 0, TOTAL_HUMANS)


func _ending_data_for_save(save_data: Dictionary) -> Dictionary:
	var ending_key := _ending_key_for_final_evaluation(save_data)
	var ending_path := str(ENDING_DATA_PATHS.get(ending_key, ""))
	if ending_path.is_empty():
		push_error("No ending data path is configured for '%s'." % ending_key)
		return {}

	var ending_data := _load_json_dictionary(ending_path)
	if ending_data.is_empty():
		return {}

	var format_values := {
		"indikasi_penyusup": str(clampi(int(save_data.get("infiltration", 0)), 0, 100)) + "%",
		"pelanggaran_tercatat": str(clampi(int(save_data.get("suspicion", 0)), 0, 100)) + "%",
		"manusia_terselamatkan": _human_saved_count(save_data),
	}
	ending_data["body"] = str(ending_data.get("body", "")).format(format_values)
	ending_data["ending_key"] = ending_key
	return ending_data


func _morning_report_values(save_data: Dictionary) -> Dictionary:
	var infiltration_band := _infiltration_band(int(save_data.get("infiltration", 0)))
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
		"band_infiltrasi": infiltration_band,
		"band_pelanggaran": violation_band,
		"syarat": required_questions,
	}


func _commander_instruction_for_day(day: int) -> String:
	var briefing: Variant = _commander_briefings.get(day, {})
	if not briefing is Dictionary:
		return ""
	var events: Variant = briefing.get("pre_interaction", [])
	if not events is Array:
		return ""
	for event in events:
		if event is Dictionary and str(event.get("speaker", "")) == "KOMANDAN":
			return str(event.get("text", ""))
	return ""


func _infiltration_band(value: int) -> String:
	if value >= 75:
		return "Kritis"
	if value >= 50:
		return "Waspada"
	return "Rendah"


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
		"timeline_version": TIMELINE_VERSION,
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
		var current_day := int(_timeline[_timeline_index].get("day", 1))
		var day_key := str(current_day)
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

		_save_slots[_active_save_slot] = save_data
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
	var packed_scene: PackedScene = step["scene"]
	_active_scene = packed_scene.instantiate()
	var character_data_path := str(step.get("character_data_path", ""))
	if not character_data_path.is_empty():
		_active_scene.set("character_data_path", character_data_path)
	if bool(step.get("is_ending", false)):
		if _active_scene.has_method("set_ending_data"):
			_active_scene.call("set_ending_data", _ending_data_for_save(_active_save_data()))
		else:
			push_error("The ending scene cannot display ending data.")
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

	var continue_button := _active_scene.get_node_or_null("ContinueButton") as Button
	if continue_button:
		continue_button.pressed.connect(_advance_timeline)
	if _active_scene.has_signal("outcome_finished"):
		_active_scene.connect("outcome_finished", _advance_timeline)
	if _active_scene.has_signal("return_to_main_menu"):
		_active_scene.connect("return_to_main_menu", _return_to_main_menu)

	for decision_name in ["TerimaButton", "TolakButton"]:
		var decision_button := _active_scene.find_child(decision_name, true, false) as BaseButton
		if decision_button:
			decision_button.pressed.connect(
				_on_admission_decision.bind(decision_name == "TerimaButton")
			)
