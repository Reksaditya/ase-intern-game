extends Control

const START_DELAY := 1.0
const FADE_IN := 1.2
const FADE_OUT := 0.8
const HOLD_MIN := 2.0
const HOLD_MAX := 3.0
const BUTTON_DELAY := 1.0
const BUTTON_FADE := 0.8
const SKIP_HOLD_DURATION := 1.0
const SHORT_CLICK_THRESHOLD := 0.22
const MOUSE_SKIP_SHOW_DELAY := 0.12
const SKIP_DECAY_RATE := 3.0
const SKIP_DOT_INTERVAL := 0.15
const SKIP_DOT_SEQUENCE: Array[int] = [0, 1, 2, 3, 2, 1]
const SKIP_DIM_MODULATE := Color(0.5, 0.5, 0.5, 0.2)
const SKIP_VIBRANT_MODULATE := Color(1.0, 1.0, 1.0, 1.0)
const CLICK_SFX: AudioStream = preload("res://assets/bgm/clickeveywhere.mp3")

const PARAGRAPHS: Array[String] = [
	"Dunia sudah lama berhenti menjadi tempat yang aman. Atmosfer beracun. Badai asam yang datang tiap hari, tanpa peringatan, tanpa ampun.",
	"Peradaban di luar sana sudah runtuh total.",
	"Bunker 07 adalah yang tersisa — satu-satunya bunker yang diketahui masih bertahan. Tidak ada gerbang lain untuk dihubungi. Tidak ada laporan dari luar. Hanya reruntuhan, dan siapapun — atau apapun — yang masih bergerak di dalamnya.",
	"Belakangan ini, sesuatu berubah.",
	"Penyintas yang datang ke gerbang tidak semuanya seperti yang mereka klaim. Sesuatu di antara reruntuhan itu telah menemukan cara meniru manusia — dari sisa-sisa yang gagal bertahan, dari ID card, dari kata-kata terakhir yang sempat terekam.",
	"Militer menyebutnya The Empty.",
	"Kamu adalah filter terakhir. Satu-satunya yang berdiri di antara gerbang bunker dan dunia yang sekarat. Setiap keputusan adalah taruhan.",
	"Terima yang salah, dan infiltrasi dimulai dari dalam. Tolak yang benar, dan kemanusiaan yang tersisa berkurang satu lagi.",
	"SOP akan terus berubah. Semakin ketat, semakin banyak yang tersingkir — termasuk mereka yang paling nyata butuh pertolongan.",
	"Kamu yang memutuskan siapa yang layak melihat esok hari.",
]

var _index := -1
var _finished := false
var _scene_skipped := false
var _tween: Tween
var _is_skip_held := false
var _is_mouse_held := false
var _mouse_press_time := 0.0
var _skip_hold_time := 0.0
var _skip_dot_timer := 0.0
var _click_sfx_player: AudioStreamPlayer

@onready var _story: Label = $Story
@onready var _start_button: Button = $ContinueButton
@onready var _skipping_label: Label = $SkippingLabel


func _ready() -> void:
	_story.modulate.a = 0.0
	_start_button.visible = false
	_start_button.modulate.a = 0.0
	_reset_skip_state()
	_click_sfx_player = AudioStreamPlayer.new()
	_click_sfx_player.stream = CLICK_SFX
	_click_sfx_player.volume_db = -3.0
	add_child(_click_sfx_player)
	_tween = create_tween()
	_tween.tween_interval(START_DELAY)
	_tween.tween_callback(_show_paragraph.bind(0))


func _process(delta: float) -> void:
	if _scene_skipped:
		return
	if _is_skip_held and not Input.is_action_pressed("ui_pause"):
		_is_skip_held = false
	if _is_mouse_held and not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_is_mouse_held = false

	if _is_mouse_held:
		_mouse_press_time += delta

	var is_skip_pressing := _is_skip_held or (_is_mouse_held and _mouse_press_time >= MOUSE_SKIP_SHOW_DELAY)
	if _is_skip_held or _is_mouse_held:
		_skip_hold_time += delta
		_skip_dot_timer += delta
		if _skip_hold_time >= SKIP_HOLD_DURATION:
			_skip_scene()
			return
	else:
		_skip_hold_time = maxf(0.0, _skip_hold_time - delta * SKIP_DECAY_RATE)
		if _skip_hold_time <= 0.0:
			_skip_dot_timer = 0.0

	_update_skipping_label(is_skip_pressing)


func _unhandled_input(event: InputEvent) -> void:
	if _scene_skipped:
		return
	if event.is_action_pressed("ui_pause"):
		_is_skip_held = true
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT:
			if mouse_event.pressed:
				_is_mouse_held = true
				_mouse_press_time = 0.0
			else:
				var was_mouse_held := _is_mouse_held
				_is_mouse_held = false
				if was_mouse_held and _mouse_press_time < SHORT_CLICK_THRESHOLD:
					_reset_skip_state()
					if _finished:
						_skip_scene()
					else:
						_skip()
			get_viewport().set_input_as_handled()
			return
	if event.is_action_pressed("ui_accept") and not _finished:
		get_viewport().set_input_as_handled()
		_skip()


func _update_skipping_label(is_skip_pressing: bool) -> void:
	if not is_skip_pressing and _skip_hold_time <= 0.0:
		_skipping_label.visible = false
		return
	if not is_skip_pressing and not _skipping_label.visible:
		return
	_skipping_label.visible = true
	var dot_step := int(_skip_dot_timer / SKIP_DOT_INTERVAL) % SKIP_DOT_SEQUENCE.size()
	var dot_count: int = SKIP_DOT_SEQUENCE[dot_step]
	_skipping_label.text = "skipping" + ".".repeat(dot_count)
	var progress := clampf(_skip_hold_time / SKIP_HOLD_DURATION, 0.0, 1.0)
	_skipping_label.modulate = SKIP_DIM_MODULATE.lerp(SKIP_VIBRANT_MODULATE, progress)


func _reset_skip_state() -> void:
	_is_skip_held = false
	_is_mouse_held = false
	_mouse_press_time = 0.0
	_skip_hold_time = 0.0
	_skip_dot_timer = 0.0
	if _skipping_label:
		_skipping_label.visible = false
		_skipping_label.text = "skipping"
		_skipping_label.modulate = SKIP_DIM_MODULATE


func _skip_scene() -> void:
	if _scene_skipped:
		return
	_scene_skipped = true
	if _tween:
		_tween.kill()
	_reset_skip_state()
	_finish()
	_start_button.pressed.emit()


func _skip() -> void:
	if _tween:
		_tween.kill()
	if is_instance_valid(_click_sfx_player):
		_click_sfx_player.play()
	if _index >= PARAGRAPHS.size() - 1:
		_finish()
	else:
		_show_paragraph(_index + 1)


func _show_paragraph(index: int) -> void:
	_index = index
	_story.text = PARAGRAPHS[index]
	_story.modulate.a = 0.0

	_tween = create_tween()
	_tween.tween_property(_story, "modulate:a", 1.0, FADE_IN)

	if index >= PARAGRAPHS.size() - 1:
		_tween.tween_interval(BUTTON_DELAY)
		_tween.tween_callback(_finish)
		return

	var hold := clampf(HOLD_MIN + PARAGRAPHS[index].length() / 200.0, HOLD_MIN, HOLD_MAX)
	_tween.tween_interval(hold)
	_tween.tween_property(_story, "modulate:a", 0.0, FADE_OUT)
	_tween.tween_callback(_show_paragraph.bind(index + 1))


func _finish() -> void:
	if _finished:
		return
	_finished = true
	_index = PARAGRAPHS.size() - 1
	_story.text = PARAGRAPHS[_index]
	_story.modulate.a = 1.0

	_start_button.visible = true
	_start_button.grab_focus()
	_tween = create_tween()
	_tween.tween_property(_start_button, "modulate:a", 1.0, BUTTON_FADE)
