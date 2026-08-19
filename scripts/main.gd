extends Control

const TOTAL_DAYS := 5
const INTERLUDE_SCENE: PackedScene = preload("res://scenes/interlude.tscn")
const DAY_INTRO_SCENE: PackedScene = preload("res://scenes/day_intro.tscn")
const MORNING_REPORT_SCENE: PackedScene = preload("res://scenes/morning_report.tscn")
const AFTERNOON_SCENE: PackedScene = preload("res://scenes/afternoon.tscn")
const NIGHT_EVALUATION_SCENE: PackedScene = preload("res://scenes/night_evaluation.tscn")
const FINAL_EVALUATION_SCENE: PackedScene = preload("res://scenes/final_evaluation.tscn")
const ENDING_SCENE: PackedScene = preload("res://scenes/ending.tscn")

var _timeline: Array[Dictionary] = []
var _timeline_index := 0
var _active_scene: Node


func _ready() -> void:
	_timeline = _build_timeline()
	_show_timeline_step()


func _unhandled_input(event: InputEvent) -> void:
	var should_advance := event.is_action_pressed("ui_accept")
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		should_advance = should_advance or mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed
	if should_advance:
		_advance_timeline()
		get_viewport().set_input_as_handled()


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
		steps.append({"scene": AFTERNOON_SCENE, "title": "Afternoon"})
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
		return
	_timeline_index += 1
	_show_timeline_step()


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

	var report_header := _active_scene.get_node_or_null("popup/header") as Label
	if report_header and step.has("header"):
		report_header.text = str(step["header"]) % int(step.get("day", 1))

	var continue_button := _active_scene.get_node_or_null("ContinueButton") as Button
	if continue_button:
		continue_button.pressed.connect(_advance_timeline)
