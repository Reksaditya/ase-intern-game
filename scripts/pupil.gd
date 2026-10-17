extends PanelContainer

signal close_requested
signal tool_reaction_requested(tool_key: String)

@onready var eye_stage: Control = $Layout/EyeStage
@onready var eye_rect: ColorRect = $Layout/EyeStage/EyeRect
@onready var beam_rect: ColorRect = $Layout/EyeStage/PenlightBeam
@onready var subject_label: Label = %SubjectLabel

var eye_material: ShaderMaterial
var beam_material: ShaderMaterial
var current_diameter_mm := 6.5
var target_diameter_mm := 6.5
var hippus_time := 0.0
var blink_timer := 4.0
var blink_progress := 0.0
var is_blinking := false
var prolonged_light_exposure := 0.0
var sclera_redness := 0.0
var pupil_behaviours: Dictionary = {}
var _light_reaction_emitted := false


func _ready() -> void:
	var pupil_shader: Shader = load("res://shaders/pupil.gdshader")
	eye_material = ShaderMaterial.new()
	eye_material.shader = pupil_shader
	eye_rect.material = eye_material
	beam_material = ShaderMaterial.new()
	beam_material.shader = pupil_shader
	beam_material.set_shader_parameter("beam_only", true)
	beam_material.set_shader_parameter("radius_normalized", 0.42)
	beam_material.set_shader_parameter("beam_color", Color(1.0, 0.98, 0.90, 1.0))
	beam_rect.material = beam_material

	%CloseButton.pressed.connect(func(): close_requested.emit())


func set_character_data(character_data: Dictionary) -> void:
	subject_label.text = "SUBJECT: %s" % str(character_data.get("character_name", "Unknown"))
	var behaviours: Variant = character_data.get("pupil_behaviours", {})
	pupil_behaviours = behaviours if behaviours is Dictionary else {}
	current_diameter_mm = float(pupil_behaviours.get("initial_diameter_mm", 6.5))
	target_diameter_mm = current_diameter_mm
	_light_reaction_emitted = false


func _input(event: InputEvent) -> void:
	if is_visible_in_tree() and event.is_action_pressed("ui_cancel"):
		close_requested.emit()
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if eye_rect.size.x <= 0.0 or eye_rect.size.y <= 0.0:
		return
	var mouse_local := eye_rect.get_local_mouse_position()
	var eye_center := eye_rect.size * 0.5
	var viewport_scale := get_viewport_rect().size.x / 1152.0
	var beam_radius := float(pupil_behaviours.get("beam_radius_px", 200.0)) * viewport_scale
	var light_intensity := float(pupil_behaviours.get("light_intensity", 1.35))
	var ambient_lux := float(pupil_behaviours.get("ambient_lux", 0.425))
	var light_response_enabled := bool(pupil_behaviours.get("light_response_enabled", true))
	var beam_coverage := clampf(1.0 - mouse_local.distance_to(eye_center) / beam_radius, 0.0, 1.0)
	if beam_coverage >= 0.8 and not _light_reaction_emitted:
		_light_reaction_emitted = true
		tool_reaction_requested.emit("pupil_light")
	var direct_lux := pow(beam_coverage, 1.3) * light_intensity
	var normalized_light := clampf((ambient_lux + direct_lux) / 1.5, 0.0, 1.0)
	if light_response_enabled:
		target_diameter_mm = lerpf(
			float(pupil_behaviours.get("dilated_diameter_mm", 7.5)),
			float(pupil_behaviours.get("constricted_diameter_mm", 2.2)),
			sqrt(normalized_light)
		)
	else:
		target_diameter_mm = current_diameter_mm
	var speed := float(pupil_behaviours.get("dilation_speed_mm_per_second", 1.6))
	if target_diameter_mm < current_diameter_mm:
		speed = float(pupil_behaviours.get("constriction_speed_mm_per_second", 4.5))
	current_diameter_mm = move_toward(current_diameter_mm, target_diameter_mm, speed * delta)

	hippus_time += delta
	var hippus := 0.0
	if light_response_enabled:
		hippus = (
			sin(hippus_time * float(pupil_behaviours.get("hippus_frequency_a", 3.2))) * float(pupil_behaviours.get("hippus_weight_a", 0.6))
			+ sin(hippus_time * float(pupil_behaviours.get("hippus_frequency_b", 7.1))) * float(pupil_behaviours.get("hippus_weight_b", 0.4))
		) * float(pupil_behaviours.get("hippus_amplitude_mm", 0.14))
	var min_diameter := float(pupil_behaviours.get("min_diameter_mm", 2.0))
	var max_diameter := float(pupil_behaviours.get("max_diameter_mm", 8.0))
	var displayed_diameter := clampf(current_diameter_mm + hippus, min_diameter, max_diameter)
	var pupil_scale := remap(displayed_diameter, min_diameter, max_diameter, 0.18, 0.78)
	var eye_uv := mouse_local / eye_rect.size
	eye_material.set_shader_parameter("pupil_scale", pupil_scale)
	eye_material.set_shader_parameter("eye_aspect", eye_rect.size.x / eye_rect.size.y)
	eye_material.set_shader_parameter("light_pos", eye_uv)
	eye_material.set_shader_parameter("light_intensity", light_intensity)
	eye_material.set_shader_parameter("light_beam_radius", beam_radius / maxf(eye_rect.size.x, eye_rect.size.y))
	eye_material.set_shader_parameter("light_on", true)
	eye_material.set_shader_parameter("ambient_light", ambient_lux)
	eye_material.set_shader_parameter("sclera_redness", sclera_redness)
	var squint := 0.0
	if light_response_enabled:
		squint = clampf(
			(direct_lux - float(pupil_behaviours.get("squint_threshold", 0.4))) * float(pupil_behaviours.get("squint_scale", 1.2)),
			0.0,
			float(pupil_behaviours.get("max_squint", 0.75))
		)
	eye_material.set_shader_parameter("squint", squint)
	eye_material.set_shader_parameter("blink", _update_blink(delta))

	var beam_diameter := beam_radius * 2.4
	beam_rect.size = Vector2.ONE * beam_diameter
	beam_rect.position = eye_stage.get_local_mouse_position() - beam_rect.size * 0.5
	beam_material.set_shader_parameter("core_brightness", light_intensity)
	if light_response_enabled:
		_update_sclera_redness(delta, direct_lux)
	else:
		prolonged_light_exposure = 0.0
		sclera_redness = 0.0


func _update_blink(delta: float) -> float:
	if not bool(pupil_behaviours.get("blink_enabled", true)):
		is_blinking = false
		blink_progress = 0.0
		return 0.0
	blink_timer -= delta
	if blink_timer <= 0.0 and not is_blinking:
		is_blinking = true
		blink_progress = 0.0
	if is_blinking:
		blink_progress += delta / maxf(float(pupil_behaviours.get("blink_duration_seconds", 0.14)), 0.01)
		if blink_progress >= 1.0:
			is_blinking = false
			blink_progress = 0.0
			blink_timer = randf_range(
				float(pupil_behaviours.get("blink_interval_min_seconds", 4.0)),
				float(pupil_behaviours.get("blink_interval_max_seconds", 8.0))
			)
			return 0.0
		return sin(blink_progress * PI)
	return 0.0


func _update_sclera_redness(delta: float, direct_lux: float) -> void:
	if direct_lux > float(pupil_behaviours.get("redness_light_threshold", 0.06)):
		prolonged_light_exposure += delta * clampf(
			direct_lux / float(pupil_behaviours.get("redness_exposure_scale", 1.2)),
			0.0,
			1.0
		)
	else:
		prolonged_light_exposure = maxf(
			0.0,
			prolonged_light_exposure - delta * float(pupil_behaviours.get("redness_recovery_per_second", 0.35))
		)
	sclera_redness = clampf(
		remap(
			prolonged_light_exposure,
			float(pupil_behaviours.get("redness_start_exposure_seconds", 1.5)),
			float(pupil_behaviours.get("redness_full_exposure_seconds", 5.0)),
			0.0,
			1.0
		),
		0.0,
		1.0
	)
