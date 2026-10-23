extends Node2D
class_name Bunker

## Bunker sekarang hanya mengurus "panggung": karakter berjalan masuk / keluar
## jendela, tombol Terima / Tolak, dan teks SOP. Semua dialog, alat pemindai,
## ID Card, dan alur shift ada di gameplay.gd.

## Karakter selesai berjalan masuk dan berhenti di tengah jendela.
signal character_arrived
## Karakter selesai berjalan keluar (diterima = ke kanan, ditolak = ke kiri).
signal character_left(accepted: bool)
## Pemain menekan Terima (true) atau Tolak (false).
signal decision_made(is_accepted: bool)

# ----------------------------------------------------------------------------
# PENGATURAN
# ----------------------------------------------------------------------------
## Folder gambar karakter. Taruh char1.png, char2.png di sini.
const CHARACTER_DIR := "res://assets/character/"
## Tinggi karakter di dalam jendela (piksel, sebelum skala bgpanel).
const CHARACTER_HEIGHT := 640.0
## Posisi atas gambar relatif ke jendela. Makin kecil = karakter makin naik.
const TOP_MARGIN := -20.0
## Jarak ekstra di luar jendela agar karakter benar-benar hilang dari pandangan.
const EXIT_MARGIN := 40.0

const WALK_IN_TIME := 2.4
const WALK_OUT_TIME := 2.0
## Durasi satu "langkah" (naik atau turun) pada animasi jalan.
const STEP_TIME := 0.22
const BOB_HEIGHT := 7.0
const SWAY_DEGREES := 1.2
## Warna sosok The Empty yang ditolak (menggelap dari dalam).
const EMPTY_DARK_COLOR := Color(0.1, 0.1, 0.14, 1.0)
const STEP_SFX: AudioStream = preload("res://assets/bgm/step.wav")
const REJECT_SFX: AudioStream = preload("res://assets/bgm/reject.wav")
const BUTTON_SFX: AudioStream = preload("res://assets/bgm/button.mp3")

@onready var sop_label: Label = $Label
@onready var window_clip: Control = $bgpanel/WindowClip
@onready var character_holder: Node2D = $bgpanel/WindowClip/CharacterHolder
@onready var accept_button: TextureButton = $TerimaButton
@onready var reject_button: TextureButton = $TolakButton

var _move_tween: Tween
var _bob_tween: Tween
var _settle_tween: Tween
var _fade_tween: Tween
var _step_player: AudioStreamPlayer
var _reject_player: AudioStreamPlayer
var _accept_player: AudioStreamPlayer

var _pivot: Node2D
var _body: Sprite2D
var _half_width := 150.0
var _stand_y := 0.0


func _ready() -> void:
	accept_button.pressed.connect(_on_decision_pressed.bind(true))
	reject_button.pressed.connect(_on_decision_pressed.bind(false))
	set_decision_enabled(false)

	_step_player = AudioStreamPlayer.new()
	_step_player.stream = STEP_SFX
	_step_player.volume_db = 12.0
	_step_player.finished.connect(func():
		if _bob_tween and _bob_tween.is_running():
			_step_player.play()
	)
	add_child(_step_player)

	_reject_player = AudioStreamPlayer.new()
	_reject_player.stream = REJECT_SFX
	_reject_player.volume_db = -3.0
	add_child(_reject_player)

	_accept_player = AudioStreamPlayer.new()
	_accept_player.stream = BUTTON_SFX
	_accept_player.volume_db = -3.0
	add_child(_accept_player)


## Teks SOP di kiri atas.
func set_sop_text(text: String) -> void:
	sop_label.text = text


## Aktif / nonaktifkan tombol Terima dan Tolak.
func set_decision_enabled(enabled: bool) -> void:
	accept_button.disabled = not enabled
	reject_button.disabled = not enabled
	accept_button.modulate.a = 1.0 if enabled else 0.45
	reject_button.modulate.a = 1.0 if enabled else 0.45


## Karakter berjalan dari kiri jendela ke tengah.
## texture_name: nama file di CHARACTER_DIR (mis. "char1.png").
func spawn_character(texture_name: String, offset_y: float = 0.0) -> void:
	_clear_character()

	_pivot = Node2D.new()
	_body = Sprite2D.new()
	var texture := _load_character_texture(texture_name)
	_body.texture = texture
	if texture:
		var s := CHARACTER_HEIGHT / float(texture.get_height())
		_body.scale = Vector2(s, s)
		_half_width = texture.get_width() * s * 0.5
	else:
		_half_width = 150.0
	_pivot.add_child(_body)
	character_holder.add_child(_pivot)

	_stand_y = TOP_MARGIN + CHARACTER_HEIGHT * 0.5 + offset_y
	_pivot.position = Vector2(-_half_width - EXIT_MARGIN, _stand_y)

	_walk_to(window_clip.size.x * 0.5, WALK_IN_TIME, Tween.EASE_OUT, func(): character_arrived.emit())


## Karakter berjalan keluar. Diterima: ke kanan. Ditolak: bergeser kembali ke kiri.
## darken = true membuat sosoknya menggelap lebih dulu (The Empty yang ditolak).
func dismiss_character(accepted: bool, darken: bool = false) -> void:
	if not is_instance_valid(_pivot):
		character_left.emit(accepted)
		return

	if darken:
		_fade_tween = create_tween()
		_fade_tween.tween_property(_body, "modulate", EMPTY_DARK_COLOR, 0.8)

	var target_x := window_clip.size.x + _half_width + EXIT_MARGIN
	if not accepted:
		target_x = -_half_width - EXIT_MARGIN
	_walk_to(target_x, WALK_OUT_TIME, Tween.EASE_IN, _on_exited.bind(accepted))


func _on_decision_pressed(accepted: bool) -> void:
	if accepted:
		if _accept_player:
			_accept_player.play()
	elif _reject_player:
		_reject_player.play()
	decision_made.emit(accepted)


func _on_exited(accepted: bool) -> void:
	_clear_character()
	character_left.emit(accepted)


func _clear_character() -> void:
	for t in [_move_tween, _bob_tween, _settle_tween, _fade_tween]:
		if t:
			t.kill()
	if _step_player and _step_player.playing:
		_step_player.stop()
	if is_instance_valid(_pivot):
		_pivot.queue_free()
	_pivot = null
	_body = null


func _load_character_texture(file_or_path: String) -> Texture2D:
	if file_or_path.is_empty():
		push_warning("Path gambar karakter kosong.")
		return null
	var path := file_or_path if file_or_path.begins_with("res://") else CHARACTER_DIR + file_or_path
	if ResourceLoader.exists(path):
		return load(path) as Texture2D
	push_warning("Gambar karakter tidak ditemukan: %s" % path)
	return null


# --- Animasi jalan ----------------------------------------------------------

func _walk_to(target_x: float, duration: float, ease_type: Tween.EaseType, on_done: Callable) -> void:
	_start_walk_bob()
	if _move_tween:
		_move_tween.kill()
	_move_tween = create_tween()
	_move_tween.set_trans(Tween.TRANS_SINE).set_ease(ease_type)
	_move_tween.tween_property(_pivot, "position:x", target_x, duration)
	_move_tween.tween_callback(func():
		_stop_walk_bob()
		on_done.call()
	)


## Efek berjalan: badan naik-turun tiap langkah + sedikit goyang kiri-kanan.
func _start_walk_bob() -> void:
	if _bob_tween:
		_bob_tween.kill()
	if _settle_tween:
		_settle_tween.kill()
	if _step_player and not _step_player.playing:
		_step_player.play()
	_bob_tween = create_tween().set_loops()
	_bob_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	var steps := [
		[-BOB_HEIGHT, SWAY_DEGREES],
		[0.0, 0.0],
		[-BOB_HEIGHT, -SWAY_DEGREES],
		[0.0, 0.0],
	]
	for step in steps:
		_bob_tween.tween_property(_body, "position:y", step[0], STEP_TIME)
		_bob_tween.parallel().tween_property(_body, "rotation", deg_to_rad(step[1]), STEP_TIME)


func _stop_walk_bob() -> void:
	if _bob_tween:
		_bob_tween.kill()
	if _step_player and _step_player.playing:
		_step_player.stop()
	if not is_instance_valid(_body):
		return
	_settle_tween = create_tween()
	_settle_tween.set_parallel(true)
	_settle_tween.tween_property(_body, "position:y", 0.0, 0.12)
	_settle_tween.tween_property(_body, "rotation", 0.0, 0.12)
