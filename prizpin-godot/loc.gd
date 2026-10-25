class_name Loc
extends RefCounted
## Çeviriler. Metinler data/i18n.json içinde, dersler data/lessons.json içinde.

static var lang := "tr"
static var langs: Array = []          # [[kod, ad], ...]
static var strs: Dictionary = {}      # anahtar -> {dil: metin}
static var lessons: Dictionary = {}   # bulmaca -> [ders, ...]
static var lesson_txt: Dictionary = {}
static var _loaded := false


static func load_data() -> void:
	if _loaded:
		return
	_loaded = true
	var d = _read_json("res://data/i18n.json")
	if d is Dictionary:
		langs = d.get("langs", [])
		strs = d.get("str", {})
	var l = _read_json("res://data/lessons.json")
	if l is Dictionary:
		lessons = l.get("lessons", {})
		lesson_txt = l.get("txt", {})


static func _read_json(path: String):
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("Dosya açılamadı: " + path)
		return null
	return JSON.parse_string(f.get_as_text())


static func has_lang(id: String) -> bool:
	for l in langs:
		if l[0] == id:
			return true
	return false


static func detect() -> String:
	var os_lang := OS.get_locale_language()
	if has_lang(os_lang):
		return os_lang
	return "en" if has_lang("en") else "tr"


static func t(key: String, vars: Dictionary = {}) -> String:
	var r = strs.get(key)
	var s: String = key
	if r != null:
		s = str(r.get(lang, r.get("tr", key)))
	for k in vars:
		s = s.replace("{" + str(k) + "}", str(vars[k]))
	return s


static func has_key(key: String) -> bool:
	return strs.has(key)


## Bulmaca adı: küplerde "3×3", diğerlerinde çevrilmiş ad.
static func pname(def: Dictionary) -> String:
	if def["kind"] == "cube" and def.has("n"):
		return def["name"]
	var k := "pz." + str(def["id"])
	return t(k) if strs.has(k) else def["name"]


# ---- dersler ----

static func lessons_for(puz: String) -> Array:
	return lessons.get(puz, [])


static func _lesson_tr(puz: String, li: int):
	if lang == "tr":
		return null
	var by_lang = lesson_txt.get(lang)
	if by_lang == null:
		return null
	var arr = by_lang.get(puz)
	if arr == null or li >= arr.size():
		return null
	return arr[li]


static func lesson_title(puz: String, li: int) -> String:
	var x = _lesson_tr(puz, li)
	if x != null:
		return str(x[0])
	return str(lessons_for(puz)[li]["tr"][0])


static func lesson_sum(puz: String, li: int) -> String:
	var x = _lesson_tr(puz, li)
	if x != null:
		return str(x[1])
	return str(lessons_for(puz)[li]["tr"][1])


static func step_text(puz: String, li: int, k: int) -> String:
	var x = _lesson_tr(puz, li)
	if x != null and k < x[2].size():
		return str(x[2][k])
	return str(lessons_for(puz)[li]["tr"][2][k])
