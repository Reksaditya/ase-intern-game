extends Node2D
class_name Bunker

## Dipancarkan setelah karakter selesai berjalan masuk dan berhenti di jendela.
signal character_arrived(index: int)
## Dipancarkan setelah karakter selesai berjalan keluar (diterima / ditolak).
signal character_left(accepted: bool)

## Folder gambar karakter. Taruh char1.png, char2.png di sini.
const CHARACTER_DIR := "res://assets/"
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

const TYPE_SPEED := 0.025        ## detik per huruf
const MAX_BLOCK_TIME := 7.0      ## teks panjang dipercepat agar tidak lebih lama dari ini
const LINE_PAUSE := 0.7          ## jeda antar blok dialog
const HOLD_AFTER_TEXT := 0.9     ## jeda setelah teks keputusan sebelum karakter jalan
const PLAYER_NAME := "KAMU"
## Kehalusan scroll dialog. Makin besar = makin cepat menyusul teks, makin kecil = makin licin/lambat.
const SCROLL_SMOOTHING := 6.0
## Seberapa jauh (dalam baris) scroll "mengintip" ke depan teks yang sedang diketik.
const SCROLL_LOOKAHEAD_LINES := 1.0
## Default aturan harian (diganti oleh apply_day_rules() dari tempo_gameplay.gd).
const DEFAULT_SCAN_UNLOCK_QUESTIONS := 2

const CHARACTERS: Array[Dictionary] = [
	{
		"name": "KIARA",
		"texture": "char1.png",
		"offset_y": 0.0,
		"is_empty": true,
		"appear": "Seorang wanita berdiri di balik kaca, rambut merah pendeknya berantakan tertiup angin dari luar. Jaket kulitnya terbuka, satu kaki mengetuk-ngetuk lantai gak sabaran, tatapannya lompat-lompat dari kamera ke sekitar lalu balik lagi — kayak lagi nahan diri buat gak ngomong duluan. Sepasang anting kuning kecil berkilau samar kena cahaya gerbang.",
		"id_card": [
			"— ID CARD TERDETEKSI —",
			"Nama: Kiara",
			"Nomor ID: SR-04-091",
			"Usia: 20",
			"Latar: Pengendara Motor / Bekas Kurir Reruntuhan",
			"(Catatan: ID dapat dipalsukan. Verifikasi tetap diperlukan.)",
		],
		"dialogs": {
			"emotional": [
				{"q": "Kenapa kamu masih di sini? Banyak yang udah nyerah duluan.",
				 "a": "(ketawa pendek, sinis) Nyerah? Itu kata buat orang yang masih nunggu ada yang jemput. (nada naik tiba-tiba) Gue gak gitu. Motor gue masih idup, ban masih bundar, ya gue jalan aja terus— (berhenti, narik napas) ...lo nanya alasan? Gak ada. Gue cuma belum capek."},
			],
			"factual": [
				{"q": "Sepanjang jalan ke sini, kamu lewat mana aja?",
				 "a": "Dari check point lama di sisi timur, (langsung cepet) turun lewat jalur rel yang relnya udah copot separo, terus motong ke bekas SPBU yang tangkinya masih ada sisa bensin dikit-dikit, gue selalu mampir situ buat isi ulang— (terus ngoceh, makin detail, gak ada jeda sekalipun) —abis itu lewat jembatan gantung yang miring 15 derajat, banyak orang takut lewat situ, padahal asal lo jaga kecepatan konstan itu jalur paling aman, terus turun ke terowongan bawah tanah yang pintu masuknya ketutup papan iklan, belok kiri di percabangan kedua, lurus 400 meter sampai ketemu tangga besi, naik, lewat lorong servis, keluar di belakang pasar lama, nyebrang lapangan, nyusur tembok pagar sisi utara sampai ketemu pos jaga yang atapnya udah ambruk, dari situ tinggal ikutin jalan aspal retak sampai kelihatan gerbang ini, totalnya sembilan belas titik belok dan gue hafal semuanya urut tanpa salah sedikit pun—"},
			],
			"trap": [
				{"q": "Kalau tiba-tiba gerbang ini gak pernah dibuka buat kamu, apa yang bakal kamu lakuin?",
				 "a": "(diam sebentar, senyum miring) Ya gas lagi aja lah. Dunia luas, gerbang ini kagak satu-satunya. (nada ngelirih) ...atau kalo emang abis semua opsi, ya gue liat aja sampe bensin gue abis. (ketawa kecil, gak nyambung sama nada sebelumnya) Bercanda. Mungkin. Gatau juga sih."},
			],
			"clarification": [
				{"q": "Ada yang mau kamu sampaikan sebelum aku putuskan?",
				 "a": "Kagak, buruan aja— (kepalanya nengok cepet ke arah luar) —itu ada suara motor lain gak sih barusan?? Atau perasaan gue doang— (buru-buru balik badan) ...lupain, gapapa. Intinya kalo di dalem ada muffin nganggur, gue gak nolak. Udah."},
			],
		},
		"pupil": {
			"system": "PUPIL: STATIS. Tidak ada respons terhadap cahaya.",
			"reply": "(gak mundur, gak berkedip) ...oke itu emang perlu ya.",
		},
		"biometric": {
			"system": [
				"BPM: 60 — Flat.",
				"SUHU: 26.9°C — Dingin, di bawah ambang manusia normal.",
			],
		},
		"accept": {
			"narration_before": "Gerbang berderit terbuka.",
			"line": "...Yaudah. Makasih. (garuk leher) —ah lupain, makasih aja.",
			"narration_after": "Dia melangkah masuk. Motor bututnya ditinggal di luar.",
		},
		"reject": {
			"narration_before": "Gerbang tetap tertutup.",
			"line": "(ketawa yang gak nyampe mata) ...Fine. Motor gue masih nyala— (berhenti total)",
			"narration_after": "Senyum sinisnya masih nempel sepersekian detik — lalu putus sekaligus. Wajahnya gelap dari dalam, anting kuning yang tadi dipakai jatuh berdenting pelan ke lantai saat wujudnya berubah. Ia berjalan pergi tanpa noleh.",
		},
		"accept_effects": {"suspicion": 20, "infiltration": 25},
		"reject_effects": {"suspicion": -5},
	},
	{
		"name": "NADIA",
		"texture": "char2.png",
		"offset_y": -25.0,
		"is_empty": false,
		"appear": "Seorang wanita berambut cokelat panjang berdiri di balik kaca. Kepalanya sedikit tertunduk, tersenyum malu-malu, kedua tangannya disembunyikan di belakang punggung.",
		"greeting": "Permisi... maaf mengganggu. Boleh aku masuk? Aku sendirian.",
		"id_card": [
			"— ID CARD TERDETEKSI —",
			"Nama: Nadia Safira",
			"Nomor ID: SR-02-317",
			"Usia: 27",
			"Latar: Perawat Klinik",
			"(Catatan: ID dapat dipalsukan. Verifikasi tetap diperlukan.)",
		],
		"dialogs": {
			"emotional": [
				{"q": "Apa yang membuatmu bertahan sampai sekarang?",
				 "a": "Aku ingin melihat matahari yang bersih sekali lagi. Itu saja."},
				{"q": "Kamu terlihat tenang. Apa kamu tidak takut?",
				 "a": "Takut. Tapi kalau aku menangis di sini, apa gerbangnya akan dibuka?"},
			],
			"factual": [
				{"q": "Siapa namamu dan apa pekerjaanmu dulu?",
				 "a": "Nadia Safira. Dulu aku perawat di klinik kecil."},
				{"q": "Sudah berapa lama kamu di luar sana?",
				 "a": "Sekitar dua minggu. Aku menghitungnya dengan menggores dinding."},
				{"q": "Apa kamu terluka atau sakit?",
				 "a": "Hanya lelah. Silakan periksa kalau perlu."},
			],
			"trap": [
				{"q": "Katamu sendirian, tapi kartu ini punya catatan dua pemilik. Jelaskan.",
				 "a": "Itu kartu temanku. Dia memintaku membawanya."},
				{"q": "Dua minggu di luar, tapi kulit tanganmu tidak melepuh. Kenapa?",
				 "a": "Aku pakai sarung tangan. Lalu hilang. Mungkin aku cuma beruntung."},
				{"q": "Tadi kamu bilang dua minggu, sekarang sebulan. Mana yang benar?",
				 "a": "Sebulan? ...Ya. Dua minggu. Aku lupa menghitung."},
			],
			"clarification": [
				{"q": "Teman yang kamu maksud, siapa namanya dan di mana dia sekarang?",
				 "a": "Namanya Rin. Dia tidak ikut sampai sini."},
				{"q": "Maksudmu 'hanya lelah'? Jelaskan gejalanya.",
				 "a": "Pusing sedikit. Dan sulit tidur. Seperti semua orang di luar sana."},
				{"q": "Bisa dijelaskan lagi bagian tentang klinik itu?",
				 "a": "Klinik kecil di dekat pasar. Kami merawat orang-orang yang batuk karena kabut."},
			],
		},
		"pupil": {
			"system": "PUPIL: RESPONSIF. Mengecil normal terhadap cahaya.",
			"reply": "(menyipit) Silau...",
		},
		"biometric": {
			"system": [
				"BPM: 84 — Normal, sedikit cepat.",
				"SUHU: 36.5°C — Normal.",
			],
		},
		"accept": {
			"narration_before": "Gerbang berderit terbuka.",
			"line": "Terima kasih... sungguh. Terima kasih.",
			"narration_after": "Dia melangkah masuk dengan bahu yang akhirnya turun lega.",
		},
		"reject": {
			"narration_before": "Gerbang tetap tertutup.",
			"line": "Oh. ...Begitu ya. Aku mengerti.",
			"narration_after": "Dia mengangguk pelan, lalu berjalan pergi tanpa menoleh.",
		},
		"accept_effects": {},
		"reject_effects": {},
	},
]

@onready var sop_label: Label = $Label
@onready var dialog_scroll: ScrollContainer = $DialogScroll
@onready var dialog_label: Label = $DialogScroll/Dialog
@onready var window_clip: Control = $bgpanel/WindowClip
@onready var character_holder: Node2D = $bgpanel/WindowClip/CharacterHolder
@onready var accept_button: TextureButton = $TerimaButton
@onready var reject_button: TextureButton = $TolakButton
@onready var scanner_row: HBoxContainer = $ScannerRow
@onready var pupil_button: Button = $ScannerRow/PupilButton
@onready var biometric_button: Button = $ScannerRow/BiometricButton

var current_tween: Tween
var _move_tween: Tween
var _bob_tween: Tween
var _settle_tween: Tween

var _pivot: Node2D
var _body: Sprite2D
var _half_width := 150.0
var _stand_y := 0.0
var _character_index := -1
var _interview_open := false
var _asked: Dictionary = {}      # kategori -> indeks yang sudah dipakai
var _answered: Dictionary = {}   # pertanyaan unik yang sudah dijawab
var _scanner_unlocked := false
var _scroll_pos := 0.0
var _scroll_target := 0.0
var _following := false
## Jumlah pertanyaan berbeda yang harus dijawab sebelum alat pemindai terbuka.
var scan_unlock_questions := DEFAULT_SCAN_UNLOCK_QUESTIONS


func _ready() -> void:
	dialog_label.modulate.a = 1.0
	dialog_label.text = ""
	accept_button.pressed.connect(_on_decision.bind(true))
	reject_button.pressed.connect(_on_decision.bind(false))
	pupil_button.pressed.connect(use_pupil_light)
	biometric_button.pressed.connect(use_biometric)
	dialog_scroll.gui_input.connect(_on_dialog_gui_input)
	scanner_row.visible = false
	_set_decision_enabled(false)


## Terapkan aturan hari ini: teks SOP di kiri atas dan syarat akses alat.
## rules: {"sop": String, "scan_unlock_questions": int}
func apply_day_rules(rules: Dictionary) -> void:
	if rules.has("sop"):
		sop_label.text = str(rules["sop"])
	scan_unlock_questions = int(rules.get("scan_unlock_questions", DEFAULT_SCAN_UNLOCK_QUESTIONS))


func get_character_count() -> int:
	return CHARACTERS.size()


func get_character_name(index: int) -> String:
	if index < 0 or index >= CHARACTERS.size():
		return ""
	return str(CHARACTERS[index]["name"])


## Perubahan statistik untuk keputusan terima / tolak karakter ini.
func get_effects(index: int, accepted: bool) -> Dictionary:
	if index < 0 or index >= CHARACTERS.size():
		return {}
	return CHARACTERS[index]["accept_effects" if accepted else "reject_effects"]


## Karakter berjalan dari kiri jendela ke tengah.
func spawn_character(index: int) -> void:
	if index < 0 or index >= CHARACTERS.size():
		return
	_clear_character()
	_character_index = index
	_asked.clear()
	_answered.clear()
	_scanner_unlocked = scan_unlock_questions <= 0
	scanner_row.visible = _scanner_unlocked
	_interview_open = false
	_set_decision_enabled(false)
	_set_dialog_text("")

	var data: Dictionary = CHARACTERS[index]
	_pivot = Node2D.new()
	_body = Sprite2D.new()
	var texture := _load_character_texture(str(data["texture"]))
	_body.texture = texture
	if texture:
		var s := CHARACTER_HEIGHT / float(texture.get_height())
		_body.scale = Vector2(s, s)
		_half_width = texture.get_width() * s * 0.5
	else:
		_half_width = 150.0
	_pivot.add_child(_body)
	character_holder.add_child(_pivot)

	_stand_y = TOP_MARGIN + CHARACTER_HEIGHT * 0.5 + float(data.get("offset_y", 0.0))
	_pivot.position = Vector2(-_half_width - EXIT_MARGIN, _stand_y)

	_walk_to(window_clip.size.x * 0.5, WALK_IN_TIME, Tween.EASE_OUT, _on_arrived)


## Dipanggil dari luar (television.category_selected -> tempo_gameplay).
func show_question(category: String) -> void:
	if not _interview_open:
		return
	var picked := _pick_entry(category)
	if picked.is_empty():
		return
	var entry: Dictionary = picked["entry"]
	var lines: Array[String] = [
		"%s: %s" % [PLAYER_NAME, str(entry["q"])],
		"%s: %s" % [get_character_name(_character_index), str(entry["a"])],
	]
	_answered["%s:%d" % [category, int(picked["index"])]] = true
	if not _scanner_unlocked and _answered.size() >= scan_unlock_questions:
		_unlock_scanner()
		lines.append(_system("Alat Pemindai Terbuka."))
	_type_lines(lines)


## Dipanggil dari luar (television.idcard_requested -> tempo_gameplay).
func show_id_card() -> void:
	if not _interview_open:
		return
	var card: Array = CHARACTERS[_character_index]["id_card"]
	_type_lines([_system("\n".join(PackedStringArray(card)))])


func use_pupil_light() -> void:
	if not _interview_open or not _scanner_unlocked:
		return
	var data: Dictionary = CHARACTERS[_character_index]
	var pupil: Dictionary = data["pupil"]
	var lines: Array[String] = [_system(str(pupil["system"]))]
	if pupil.has("reply"):
		lines.append("%s: %s" % [str(data["name"]), str(pupil["reply"])])
	_type_lines(lines)


func use_biometric() -> void:
	if not _interview_open or not _scanner_unlocked:
		return
	var bio: Dictionary = CHARACTERS[_character_index]["biometric"]
	var system_lines: Array = bio["system"]
	var text_lines: Array[String] = []
	for l in system_lines:
		text_lines.append(_system(str(l)))
	_type_lines([("\n".join(PackedStringArray(text_lines)))])


# --- Alur karakter ----------------------------------------------------------

func _on_arrived() -> void:
	_interview_open = true
	_set_decision_enabled(true)
	var data: Dictionary = CHARACTERS[_character_index]
	var lines: Array[String] = []
	if data.has("appear"):
		lines.append(_narration(str(data["appear"])))
	if data.has("greeting"):
		lines.append("%s: %s" % [str(data["name"]), str(data["greeting"])])
	# Syarat akses alat ditampilkan setelah deskripsi karakter.
	if scan_unlock_questions > 0:
		lines.append(_system(
			"Alat Pemindai Terkunci. Ajukan minimal %d pertanyaan Interogasi untuk membuka akses."
			% scan_unlock_questions))
	if not lines.is_empty():
		_type_lines(lines)
	character_arrived.emit(_character_index)


func _on_decision(accepted: bool) -> void:
	if not _interview_open:
		return
	_interview_open = false
	_set_decision_enabled(false)
	scanner_row.visible = false

	var data: Dictionary = CHARACTERS[_character_index]
	var block: Dictionary = data["accept" if accepted else "reject"]
	var lines: Array[String] = []
	if block.has("narration_before"):
		lines.append(_narration(str(block["narration_before"])))
	lines.append("%s: %s" % [str(data["name"]), str(block["line"])])
	if block.has("narration_after"):
		lines.append(_narration(str(block["narration_after"])))
	_type_lines(lines)

	# Tunggu teks keputusan selesai dibaca, baru karakter bergerak.
	await _wait_typing()
	if not is_instance_valid(_pivot):
		return

	# The Empty yang ditolak: sosoknya menggelap dari dalam.
	if not accepted and bool(data.get("is_empty", false)):
		create_tween().tween_property(_body, "modulate", Color(0.1, 0.1, 0.14, 1.0), 0.8)

	# Diterima: lanjut berjalan ke kanan. Ditolak: bergeser kembali ke kiri.
	var target_x := window_clip.size.x + _half_width + EXIT_MARGIN
	if not accepted:
		target_x = -_half_width - EXIT_MARGIN
	_walk_to(target_x, WALK_OUT_TIME, Tween.EASE_IN, _on_exited.bind(accepted))


func _on_exited(accepted: bool) -> void:
	_clear_character()
	_set_dialog_text("")
	character_left.emit(accepted)


func _wait_typing() -> void:
	if current_tween and current_tween.is_running():
		await current_tween.finished
	await get_tree().create_timer(HOLD_AFTER_TEXT).timeout


func _clear_character() -> void:
	if _move_tween:
		_move_tween.kill()
	if _bob_tween:
		_bob_tween.kill()
	if _settle_tween:
		_settle_tween.kill()
	if is_instance_valid(_pivot):
		_pivot.queue_free()
	_pivot = null
	_body = null


func _load_character_texture(file_name: String) -> Texture2D:
	var path := CHARACTER_DIR + file_name
	if ResourceLoader.exists(path):
		return load(path) as Texture2D
	push_warning("Gambar karakter tidak ditemukan: %s" % path)
	return null


func _set_decision_enabled(enabled: bool) -> void:
	accept_button.disabled = not enabled
	reject_button.disabled = not enabled
	accept_button.modulate.a = 1.0 if enabled else 0.45
	reject_button.modulate.a = 1.0 if enabled else 0.45


func _unlock_scanner() -> void:
	_scanner_unlocked = true
	scanner_row.visible = true
	scanner_row.modulate.a = 0.0
	create_tween().tween_property(scanner_row, "modulate:a", 1.0, 0.4)


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
	if not is_instance_valid(_body):
		return
	_settle_tween = create_tween()
	_settle_tween.set_parallel(true)
	_settle_tween.tween_property(_body, "position:y", 0.0, 0.12)
	_settle_tween.tween_property(_body, "rotation", 0.0, 0.12)


# --- Dialog -----------------------------------------------------------------

func _narration(text: String) -> String:
	return "> " + text


func _system(text: String) -> String:
	return "[SISTEM] " + text


func _pick_entry(category: String) -> Dictionary:
	var dialogs: Dictionary = CHARACTERS[_character_index]["dialogs"]
	var pool: Array = dialogs.get(category, [])
	if pool.is_empty():
		return {}
	var used: Array = _asked.get(category, [])
	var candidates: Array[int] = []
	for i in pool.size():
		if not used.has(i):
			candidates.append(i)
	if candidates.is_empty():
		used.clear()
		for i in pool.size():
			candidates.append(i)
	var pick: int = candidates.pick_random()
	used.append(pick)
	_asked[category] = used
	return {"entry": pool[pick], "index": pick}


## Setiap frame: scroll bergerak halus (exponential smoothing) menuju target.
## Saat tidak mengikuti teks, scroll dibiarkan bebas agar pemain bisa
## menggulung manual dengan mouse wheel.
func _process(delta: float) -> void:
	if _following:
		_scroll_pos = lerpf(_scroll_pos, _scroll_target, 1.0 - exp(-SCROLL_SMOOTHING * delta))
		dialog_scroll.scroll_vertical = roundi(_scroll_pos)
		var typing := current_tween != null and current_tween.is_running()
		if not typing and absf(_scroll_pos - _scroll_target) < 0.5:
			_following = false
	else:
		_scroll_pos = float(dialog_scroll.scroll_vertical)


func _reset_scroll() -> void:
	_following = false
	_scroll_pos = 0.0
	_scroll_target = 0.0
	dialog_scroll.scroll_vertical = 0


func _set_dialog_text(text: String) -> void:
	if current_tween:
		current_tween.kill()
	dialog_label.text = text
	dialog_label.visible_characters = -1
	_reset_scroll()


## Menampilkan beberapa blok dialog dengan efek mengetik, blok demi blok.
## Jika teks lebih panjang dari kotak dialog, kotak otomatis ter-scroll
## mengikuti teks yang sedang diketik. Pemain juga bisa scroll manual
## dengan mouse wheel setelah selesai.
func _type_lines(lines: Array[String]) -> void:
	if current_tween:
		current_tween.kill()
	dialog_label.text = "\n\n".join(lines)
	dialog_label.visible_characters = 0
	_reset_scroll()
	_following = true
	current_tween = create_tween()
	var shown := 0
	for line in lines:
		var start := shown
		var end := shown + line.length()
		var duration := clampf(line.length() * TYPE_SPEED, 0.05, MAX_BLOCK_TIME)
		current_tween.tween_method(_set_visible_chars, float(start), float(end), duration)
		current_tween.tween_interval(LINE_PAUSE)
		shown = end + 2  # +2 untuk "\n\n"
	current_tween.tween_callback(_finish_typing)


func _set_visible_chars(value: float) -> void:
	dialog_label.visible_characters = int(value)
	_follow_text(value)


## Hanya menghitung target; pergerakan sebenarnya dihaluskan di _process().
func _follow_text(value: float) -> void:
	var max_scroll := _max_scroll()
	if max_scroll <= 0.0:
		return
	var total := maxi(dialog_label.text.length(), 1)
	var content_h := _content_height()
	var line_h := dialog_label.get_line_height() + dialog_label.get_theme_constant("line_spacing")
	var target := (value / float(total)) * content_h - dialog_scroll.size.y + line_h * (1.0 + SCROLL_LOOKAHEAD_LINES)
	_scroll_target = clampf(target, 0.0, max_scroll)
	_following = true


func _content_height() -> float:
	return maxf(dialog_label.size.y, dialog_label.get_minimum_size().y)


func _max_scroll() -> float:
	return maxf(_content_height() - dialog_scroll.size.y, 0.0)


func _finish_typing() -> void:
	dialog_label.visible_characters = -1
	# Geser halus sampai ujung teks, lalu serahkan kendali ke pemain.
	_scroll_target = _max_scroll()
	_following = true


## Klik di kotak dialog saat sedang mengetik = langsung tampilkan semua teks.
func _on_dialog_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed:
			if current_tween and current_tween.is_running():
				current_tween.custom_step(1000.0)
