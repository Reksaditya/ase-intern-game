extends Control

## Layar ending. Data (judul, daftar event, kutipan penutup) dikirim main.gd lewat
## set_ending_data() sebelum scene masuk tree; isinya dari res://data/endings.json.
## Tiap event muncul memudar (fade in), ditahan sebentar sesuai panjang teks,
## lalu memudar keluar (fade out) sebelum event berikutnya muncul — seperti
## ending film, tetapi tanpa animasi scroll. Klik / Enter melewati event aktif.
## Setelah judul dan kutipan penutup tampil, klik berikutnya dibiarkan lewat ke
## main.gd yang lalu menyimpan progres dan kembali ke menu utama.

const FADE_IN_TIME := 1.2
const FADE_OUT_TIME := 1.0
## Waktu tahan minimum, ditambah waktu baca per karakter.
const MIN_HOLD_TIME := 2.5
const HOLD_PER_CHARACTER := 0.045
const MAX_HOLD_TIME := 12.0
## Jeda gelap antar event.
const GAP_TIME := 0.6
const START_DELAY := 1.0
const TITLE_FADE_TIME := 1.6
const TITLE_GAP := 0.9
const FINAL_PROMPT_TEXT := "[ KLIK UNTUK KEMBALI KE MENU ]"

enum Stage { INTRO, SHOWING, FADING, TITLE, DONE }

@onready var _output: RichTextLabel = $Output
@onready var _title: Label = $EndingTitle
@onready var _quote: Label = $EndingQuote
@onready var _prompt: Label = $Prompt

var _ending: Dictionary = {}
var _events: Array = []
var _event_index := -1
var _stage: Stage = Stage.INTRO
var _tween: Tween


## Dipanggil main.gd sebelum add_child().
func set_ending_data(data: Dictionary) -> void:
	_ending = data
	var events: Variant = data.get("events", [])
	_events = events if events is Array else []


func _ready() -> void:
	_output.modulate.a = 0.0
	_title.modulate.a = 0.0
	_quote.modulate.a = 0.0
	_prompt.modulate.a = 0.0
	_title.text = str(_ending.get("title", ""))
	_quote.text = str(_ending.get("quote", ""))
	if _events.is_empty():
		push_error("Ending data is empty. Check res://data/endings.json.")
		_stage = Stage.DONE
		return
	_tween = create_tween()
	_tween.tween_interval(START_DELAY)
	_tween.tween_callback(_next_event)


func _input(event: InputEvent) -> void:
	if _stage == Stage.DONE:
		return
	var pressed := false
	if event is InputEventKey:
		var key_event := event as InputEventKey
		pressed = key_event.pressed and not key_event.echo and (
			key_event.keycode == KEY_ENTER
			or key_event.keycode == KEY_KP_ENTER
			or key_event.keycode == KEY_SPACE
		)
	elif event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		pressed = mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed
	if not pressed:
		return
	# Semua klik dipakai di sini sampai urutan selesai, supaya main.gd
	# tidak melompati ending.
	get_viewport().set_input_as_handled()
	match _stage:
		Stage.SHOWING:
			_fade_out_event()
		Stage.TITLE:
			_skip_title()


func _next_event() -> void:
	_event_index += 1
	if _event_index >= _events.size():
		_show_title()
		return
	var event: Variant = _events[_event_index]
	if not event is Dictionary:
		_next_event()
		return

	_output.clear()
	_append_event(event)
	_output.modulate.a = 0.0
	_stage = Stage.SHOWING

	var hold := clampf(
		_output.get_total_character_count() * HOLD_PER_CHARACTER,
		MIN_HOLD_TIME,
		MAX_HOLD_TIME
	)
	_tween = create_tween()
	_tween.tween_property(_output, "modulate:a", 1.0, FADE_IN_TIME)
	_tween.tween_interval(hold)
	_tween.tween_callback(_fade_out_event)


func _append_event(event: Dictionary) -> void:
	var text := str(event.get("text", ""))
	if str(event.get("type", "narration")) == "narration":
		_output.push_italics()
		_output.add_text(text)
		_output.pop()
		return
	var speaker := str(event.get("speaker", ""))
	if not speaker.is_empty():
		_output.push_bold()
		_output.add_text(speaker)
		_output.pop()
		var note := str(event.get("note", ""))
		if not note.is_empty():
			_output.add_text("  ")
			_output.push_italics()
			_output.add_text("(%s)" % note)
			_output.pop()
		_output.newline()
	_output.add_text(text)


func _fade_out_event() -> void:
	if _stage == Stage.FADING:
		return
	_stage = Stage.FADING
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(_output, "modulate:a", 0.0, FADE_OUT_TIME)
	_tween.tween_interval(GAP_TIME)
	_tween.tween_callback(_next_event)


func _show_title() -> void:
	_stage = Stage.TITLE
	_tween = create_tween()
	_tween.tween_property(_title, "modulate:a", 1.0, TITLE_FADE_TIME)
	_tween.tween_interval(TITLE_GAP)
	_tween.tween_property(_quote, "modulate:a", 1.0, TITLE_FADE_TIME)
	_tween.tween_interval(TITLE_GAP)
	_tween.tween_callback(_on_title_done)


func _skip_title() -> void:
	if _tween:
		_tween.kill()
	_title.modulate.a = 1.0
	_quote.modulate.a = 1.0
	_on_title_done()


func _on_title_done() -> void:
	_stage = Stage.DONE
	_prompt.text = FINAL_PROMPT_TEXT
	_tween = create_tween()
	_tween.tween_property(_prompt, "modulate:a", 1.0, 0.5)
