extends Node2D

## Dipancarkan setelah semua karakter hari ini selesai diputuskan.
## main.gd mendengarkan sinyal ini untuk lanjut ke Evaluasi Malam.
signal shift_finished

const NEXT_CHARACTER_DELAY := 0.8

@onready var television: Sprite2D = $Television
@onready var bunker: Bunker = $Bunker

## Diisi oleh main.gd sebelum scene masuk tree.
var day := 1

## Aturan per hari. Hari yang belum ditulis memakai aturan hari terakhir yang ada.
## scan_unlock_questions = jumlah pertanyaan Interogasi sebelum alat pemindai terbuka.
const DAY_RULES := {
	1: {
		"sop": "SOP DASAR — Cek ID Card & Suhu Referensi. Belum ada threshold penolakan ketat hari ini.",
		"scan_unlock_questions": 2,
	},
}

var _next_index := 0
## Hasil keputusan per karakter, bisa dipakai untuk Evaluasi Malam.
var results: Array[Dictionary] = []
## Statistik kumulatif dari keputusan hari ini (persen).
var suspicion := 0
var infiltration := 0


func _ready() -> void:
	bunker.apply_day_rules(_rules_for_day(day))
	television.category_selected.connect(_on_category_selected)
	television.id_card_requested.connect(bunker.show_id_card)
	bunker.character_left.connect(_on_character_left)
	await get_tree().create_timer(0.6).timeout
	bunker.spawn_character(_next_index)


func _rules_for_day(d: int) -> Dictionary:
	var best := 1
	for key in DAY_RULES.keys():
		if int(key) <= d and int(key) > best:
			best = int(key)
	return DAY_RULES.get(best, {})


func _on_category_selected(category: String) -> void:
	bunker.show_question(category)


func _on_character_left(accepted: bool) -> void:
	var effects := bunker.get_effects(_next_index, accepted)
	suspicion += int(effects.get("suspicion", 0))
	infiltration += int(effects.get("infiltration", 0))
	results.append({
		"index": _next_index,
		"name": bunker.get_character_name(_next_index),
		"accepted": accepted,
	})
	_next_index += 1
	if _next_index >= bunker.get_character_count():
		shift_finished.emit()
		return
	await get_tree().create_timer(NEXT_CHARACTER_DELAY).timeout
	bunker.spawn_character(_next_index)
