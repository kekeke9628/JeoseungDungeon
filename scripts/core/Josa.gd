class_name Josa
## Korean particle helper: picks the grammatically correct particle from
## whether the last syllable of a word ends in a final consonant (batchim).

static func _has_batchim(word: String) -> bool:
	if word.is_empty():
		return false
	var code: int = word.unicode_at(word.length() - 1)
	if code < 0xAC00 or code > 0xD7A3:
		return false
	return (code - 0xAC00) % 28 != 0

static func eul_reul(word: String) -> String:
	return word + ("을" if _has_batchim(word) else "를")

static func i_ga(word: String) -> String:
	return word + ("이" if _has_batchim(word) else "가")
