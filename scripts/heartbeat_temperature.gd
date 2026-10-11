extends PanelContainer

signal close_requested

const NORMAL_BPM := 110.0
const NORMAL_TEMPERATURE := 37.0

@onready var heartbeat_label: Label = %HeartbeatValue
@onready var temperature_label: Label = %TemperatureValue
@onready var subject_label: Label = %SubjectLabel

var elapsed := 0.0
var heartbeat_profile: Dictionary = {}


func _ready() -> void:
	%CloseButton.pressed.connect(func(): close_requested.emit())


func set_character_data(character_data: Dictionary) -> void:
	subject_label.text = "SUBJECT: %s" % str(character_data.get("character_name", "Unknown"))
	var profile: Variant = character_data.get("heartbeat", {})
	heartbeat_profile = profile if profile is Dictionary else {}
	elapsed = 0.0
	_update_readout()


func _input(event: InputEvent) -> void:
	if is_visible_in_tree() and event.is_action_pressed("ui_cancel"):
		close_requested.emit()
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	elapsed += delta
	_update_readout()


func _update_readout() -> void:
	var bpm := _read_profile_value(
		"base_bpm",
		"min_bpm",
		"max_bpm",
		NORMAL_BPM,
		"primary_wave_amplitude_bpm",
		"primary_wave_frequency",
		"secondary_wave_amplitude_bpm",
		"secondary_wave_frequency"
	)
	var temperature := _read_profile_value(
		"base_temperature_c",
		"min_temperature_c",
		"max_temperature_c",
		NORMAL_TEMPERATURE,
		"primary_temperature_amplitude_c",
		"primary_temperature_frequency",
		"secondary_temperature_amplitude_c",
		"secondary_temperature_frequency"
	)

	heartbeat_label.text = "%0.0f BPM" % bpm
	temperature_label.text = "%0.1f C" % temperature


func _read_profile_value(
	base_key: String,
	min_key: String,
	max_key: String,
	fallback: float,
	primary_amplitude_key: String,
	primary_frequency_key: String,
	secondary_amplitude_key: String,
	secondary_frequency_key: String
) -> float:
	var value := float(heartbeat_profile.get(base_key, fallback))
	value += sin(elapsed * float(heartbeat_profile.get(primary_frequency_key, 0.0))) * float(heartbeat_profile.get(primary_amplitude_key, 0.0))
	value += sin(elapsed * float(heartbeat_profile.get(secondary_frequency_key, 0.0))) * float(heartbeat_profile.get(secondary_amplitude_key, 0.0))
	return clampf(value, float(heartbeat_profile.get(min_key, value)), float(heartbeat_profile.get(max_key, value)))
