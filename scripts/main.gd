extends Control

const TOTAL_DAYS := 5
const INTERLUDE_SCENE: PackedScene = preload("res://scenes/interlude.tscn")
const PROLOGUE_SCENE: PackedScene = preload("res://scenes/prologue.tscn")
const DAY_INTRO_SCENE: PackedScene = preload("res://scenes/day_intro.tscn")
const MORNING_REPORT_SCENE: PackedScene = preload("res://scenes/morning_report.tscn")
const TEMPO_GAMEPLAY_SCENE: PackedScene = preload("res://scenes/gameplay.tscn")
const NIGHT_EVALUATION_SCENE: PackedScene = preload("res://scenes/night_evaluation.tscn")
const FINAL_EVALUATION_SCENE: PackedScene = preload("res://scenes/final_evaluation.tscn")
const ENDING_SCENE: PackedScene = preload("res://scenes/ending.tscn")
const SAVE_SLOT_COUNT := 4
const SAVE_PATH_FORMAT := "user://save_slot_%d.json"
const REPORT_TEXT_PATH := "res://data/report_text.json"
const DAY1_MORNING_REPORT_PATH := "res://data/day1morning.json"

var _timeline: Array[Dictionary] = []
var _report_text: Dictionary = {}
var _day1_morning_report: Dictionary = {}
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

func _ready() -> void:
	_timeline = _build_timeline()
	_report_text = _load_json_dictionary(REPORT_TEXT_PATH)
	_day1_morning_report = _load_json_dictionary(DAY1_MORNING_REPORT_PATH)
	_load_save_slots()
	$MainMenu/Buttons/PlayGameButton.pressed.connect(_open_save_menu)
	$MainMenu/Buttons/SettingsButton.pressed.connect(_open_settings_menu)
	$MainMenu/Buttons/QuitButton.pressed.connect(_quit_game)
	$SettingsMenu/Center/Content/BackButton.pressed.connect(_show_main_menu)
	_brightness_slider.value_changed.connect(_on_brightness_changed)
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
	_brightness_slider.grab_focus()


func _show_main_menu() -> void:
	_save_menu.hide()
	_settings_menu.hide()
	_main_menu.show()


func _on_brightness_changed(value: float) -> void:
	_brightness_modulate.color = Color(value, value, value, 1.0)


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
	_save_current_progress()
	_main_menu.hide()
	_save_menu.hide()
	_show_timeline_step()


func _quit_game() -> void:
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
			"report": "day1_morning" if day == 1 else "day_report",
		})
		steps.append({"scene": TEMPO_GAMEPLAY_SCENE, "title": "Afternoon", "day": day})
		steps.append({
			"scene": NIGHT_EVALUATION_SCENE,
			"day": day,
			"report": "night_evaluation",
		})

	steps.append({"scene": FINAL_EVALUATION_SCENE, "title": "Final Evaluation"})
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
	if report_key == "day1_morning":
		if scene.has_method("set_report_text"):
			scene.call("set_report_text", _day1_morning_report)
		else:
			push_error("The morning report scene cannot display report text.")
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
	}


func _on_admission_decision(is_accepted: bool) -> void:
	if _active_save_slot >= 0:
		var save_data: Dictionary = _save_slots[_active_save_slot].duplicate()
		var decision_counter := "accepted_count" if is_accepted else "declined_count"
		save_data[decision_counter] = int(save_data.get(decision_counter, 0)) + 1

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
	var packed_scene: PackedScene = step["scene"]
	_active_scene = packed_scene.instantiate()
	if step.has("day") and "day" in _active_scene:
		_active_scene.set("day", int(step["day"]))
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

	# Scene gameplay mengurus tombol Terima/Tolak sendiri dan memancarkan
	# shift_finished setelah semua karakter hari itu selesai diputuskan.
	if _active_scene.has_signal("shift_finished"):
		_active_scene.connect("shift_finished", _advance_timeline)
