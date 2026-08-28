extends Control

const TOTAL_DAYS := 5
const INTERLUDE_SCENE: PackedScene = preload("res://scenes/interlude.tscn")
const DAY_INTRO_SCENE: PackedScene = preload("res://scenes/day_intro.tscn")
const MORNING_REPORT_SCENE: PackedScene = preload("res://scenes/morning_report.tscn")
const TEMPO_GAMEPLAY_SCENE: PackedScene = preload("res://scenes/tempo_gameplay.tscn")
const AFTERNOON_SCENE: PackedScene = preload("res://scenes/afternoon.tscn")
const NIGHT_EVALUATION_SCENE: PackedScene = preload("res://scenes/night_evaluation.tscn")
const FINAL_EVALUATION_SCENE: PackedScene = preload("res://scenes/final_evaluation.tscn")
const ENDING_SCENE: PackedScene = preload("res://scenes/ending.tscn")
const SAVE_SLOT_COUNT := 4
const SAVE_PATH_FORMAT := "user://save_slot_%d.json"

var _timeline: Array[Dictionary] = []
var _timeline_index := 0
var _active_scene: Node
var _game_started := false
var _active_save_slot := -1
var _selected_save_slot := -1
var _save_slots: Array[Dictionary] = []

@onready var _main_menu := $MainMenu
@onready var _save_menu := $SaveMenu
@onready var _save_content := $SaveMenu/Center/Content


func _ready() -> void:
	_timeline = _build_timeline()
	_load_save_slots()
	$MainMenu/Buttons/PlayGameButton.pressed.connect(_open_save_menu)
	$MainMenu/Buttons/QuitButton.pressed.connect(_quit_game)
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
		if _save_menu.visible and event.is_action_pressed("ui_cancel"):
			_show_main_menu()
			get_viewport().set_input_as_handled()
		return
	if is_instance_valid(_active_scene) and _active_scene.find_child("TerimaButton", true, false):
		return
	var should_advance := event.is_action_pressed("ui_accept")
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		should_advance = should_advance or mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed
	if should_advance:
		_advance_timeline()
		get_viewport().set_input_as_handled()


func _open_save_menu() -> void:
	_selected_save_slot = -1
	_main_menu.hide()
	_save_menu.show()
	_refresh_save_menu()


func _show_main_menu() -> void:
	_save_menu.hide()
	_main_menu.show()


func _on_save_slot_pressed(slot_index: int) -> void:
	_selected_save_slot = slot_index
	_refresh_save_menu()


func _create_new_save() -> void:
	if _game_started or _selected_save_slot < 0:
		return
	_active_save_slot = _selected_save_slot
	_save_slots[_active_save_slot] = {}
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
		{"scene": DAY_INTRO_SCENE, "title": "DAY 1"},
	]

	for day in range(1, TOTAL_DAYS + 1):
		steps.append({
			"scene": MORNING_REPORT_SCENE,
			"day": day,
			"header": "MORNING REPORT - DAY %d",
		})
		steps.append({"scene": TEMPO_GAMEPLAY_SCENE, "title": "Afternoon", "day": day})
		steps.append({
			"scene": NIGHT_EVALUATION_SCENE,
			"day": day,
			"header": "EVALUASI MALAM - HARI %d",
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
					}
		_save_slots.append(save_data)


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
	var completed := bool(_save_slots[_active_save_slot].get("completed", false))
	var save_data := {"timeline_index": _timeline_index, "completed": completed}
	_write_save_data(save_data)


func _complete_active_save() -> void:
	if _active_save_slot < 0:
		return
	var save_data := {"timeline_index": _timeline_index, "completed": true}
	_write_save_data(save_data)


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
	add_child(_active_scene)

	var title_label := _active_scene.get_node_or_null("Title") as Label
	if title_label:
		title_label.text = str(step.get("title", ""))

	var day_label := _active_scene.get_node_or_null("DayLabel") as Label
	if day_label and step.has("day"):
		day_label.text = "HARI %d" % int(step["day"])

	var report_header := _active_scene.get_node_or_null("popup/header") as Label
	if report_header and step.has("header"):
		report_header.text = str(step["header"]) % int(step.get("day", 1))

	var continue_button := _active_scene.get_node_or_null("ContinueButton") as Button
	if continue_button:
		continue_button.pressed.connect(_advance_timeline)

	for decision_name in ["TerimaButton", "TolakButton"]:
		var decision_button := _active_scene.find_child(decision_name, true, false) as BaseButton
		if decision_button:
			decision_button.pressed.connect(_advance_timeline)
