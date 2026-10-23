extends Control

const START_DELAY := 1.0
const FADE_IN := 1.2
const FADE_OUT := 0.8
const HOLD_MIN := 2.0
const HOLD_MAX := 3.0
const BUTTON_DELAY := 1.0
const BUTTON_FADE := 0.8

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
var _tween: Tween

@onready var _story: Label = $Story
@onready var _hint: Label = $SkipHint
@onready var _start_button: Button = $ContinueButton
@onready var click_sound: AudioStreamPlayer = $ClickSound

func _ready() -> void:
	_story.modulate.a = 0.0
	_start_button.visible = false
	_start_button.modulate.a = 0.0
	_tween = create_tween()
	_tween.tween_interval(START_DELAY)
	_tween.tween_callback(_show_paragraph.bind(0))


func _unhandled_input(event: InputEvent) -> void:
	var is_click := event is InputEventMouseButton \
			and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT \
			and (event as InputEventMouseButton).pressed
	if not (is_click or event.is_action_pressed("ui_accept")):
		return
	if _finished:
		return
	get_viewport().set_input_as_handled()
	_skip()


func _skip() -> void:
	if _tween:
		_tween.kill()
	click_sound.play()
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
	_hint.hide()

	_start_button.visible = true
	_tween = create_tween()
	_tween.tween_property(_start_button, "modulate:a", 1.0, BUTTON_FADE)
