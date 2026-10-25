class_name Store
extends RefCounted
## Kayıtlar (dil, tema, rekorlar, seri, seviye yıldızları, ders ilerlemesi).
## Hepsi tek bir JSON dosyasında: user://prizpin_save.json

const PATH := "user://prizpin_save.json"

static var data: Dictionary = {}
static var _loaded := false


static func load_all() -> void:
	if _loaded:
		return
	_loaded = true
	var f := FileAccess.open(PATH, FileAccess.READ)
	if f != null:
		var d = JSON.parse_string(f.get_as_text())
		if d is Dictionary:
			data = d


static func get_val(key: String, default = null):
	return data.get(key, default)


static func set_val(key: String, value) -> void:
	data[key] = value
	save()


static func save() -> void:
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(data))


static func num_get(key: String) -> float:
	var v = data.get(key, 0.0)
	if v is float or v is int:
		return float(v) if float(v) > 0.0 else 0.0
	return 0.0


# ---- tarih ----

static func _days_from_civil(y: int, m: int, d: int) -> int:
	var yy := y - (1 if m <= 2 else 0)
	var era := (yy if yy >= 0 else yy - 399) / 400
	var yoe := yy - era * 400
	var mp := (m + 9) % 12
	var doy := (153 * mp + 2) / 5 + d - 1
	var doe := yoe * 365 + yoe / 4 - yoe / 100 + doy
	return era * 146097 + doe - 719468


static func _civil_from_days(z0: int) -> Array:
	var z := z0 + 719468
	var era := (z if z >= 0 else z - 146096) / 146097
	var doe := z - era * 146097
	var yoe := (doe - doe / 1460 + doe / 36524 - doe / 146096) / 365
	var y := yoe + era * 400
	var doy := doe - (365 * yoe + yoe / 4 - yoe / 100)
	var mp := (5 * doy + 2) / 153
	var d := doy - (153 * mp + 2) / 5 + 1
	var m := mp + (3 if mp < 10 else -9)
	return [y + (1 if m <= 2 else 0), m, d]


static func _key_of_days(n: int) -> String:
	var c := _civil_from_days(n)
	return "%04d-%02d-%02d" % [c[0], c[1], c[2]]


static func today_days() -> int:
	var d := Time.get_date_dict_from_system()
	return _days_from_civil(d["year"], d["month"], d["day"])


static func date_key() -> String:
	return _key_of_days(today_days())


# ---- oynama günleri, seri, çözülen sayısı ----

static func stats() -> Dictionary:
	var o = data.get("stats")
	var solves := 0
	var days: Array = []
	if o is Dictionary:
		solves = int(o.get("solves", 0))
		var dd = o.get("days", [])
		if dd is Array:
			days = dd
	return {"solves": solves, "days": days}


static func record_play(solved: bool) -> void:
	var s := stats()
	if solved:
		s["solves"] = int(s["solves"]) + 1
	var d := date_key()
	if not s["days"].has(d):
		s["days"].append(d)
	if s["days"].size() > 400:
		s["days"] = s["days"].slice(s["days"].size() - 400)
	set_val("stats", s)


## Üst üste kaç gün oynandı. Bugün henüz oynanmadıysa ama dün oynandıysa seri sürer.
static func streak_now() -> int:
	var days: Array = stats()["days"]
	var day := today_days()
	if not days.has(_key_of_days(day)):
		day -= 1
		if not days.has(_key_of_days(day)):
			return 0
	var n := 0
	while days.has(_key_of_days(day)):
		n += 1
		day -= 1
	return n


# ---- günlük karışım ----

static func daily_seed(puz: String) -> int:
	return Rng.hash_str("kup-daily|" + date_key() + "|" + puz)


static func daily_best(puz: String) -> float:
	var o = data.get("daily-" + puz)
	if o is Dictionary and o.get("d", "") == date_key() and float(o.get("best", 0.0)) > 0.0:
		return float(o["best"])
	return 0.0


static func save_daily(puz: String, ms: float) -> void:
	set_val("daily-" + puz, {"d": date_key(), "best": ms})


# ---- seviyeler ----

const LV_COUNT := 20


static func lv_stars(puz: String) -> Array:
	var out: Array = []
	var a = data.get("lv-" + puz, [])
	if not (a is Array):
		a = []
	for i in range(LV_COUNT):
		var v := 0
		if i < a.size():
			v = int(a[i])
		out.append(clampi(v, 0, 3))
	return out


static func total_stars(puz: String) -> int:
	var n := 0
	for v in lv_stars(puz):
		n += int(v)
	return n


## Seviyenin önceki yıldız sayısını döndürür.
static func save_level_stars(puz: String, n: int, stars: int) -> int:
	var a := lv_stars(puz)
	var old: int = a[n - 1]
	if stars > old:
		a[n - 1] = stars
		set_val("lv-" + puz, a)
	return old


static func lv_par(n: int) -> int:
	return 1 + int(ceil(n / 2.0))


static func stars_for(m: int, par: int) -> int:
	if m <= par:
		return 3
	return 2 if m <= int(ceil(par * 1.6)) else 1


# ---- ders ilerlemesi ----

static func learn_done(puz: String) -> Array:
	var m = data.get("learn", {})
	if m is Dictionary:
		var a = m.get(puz, [])
		if a is Array:
			return a
	return []


static func mark_lesson(puz: String, id: String) -> void:
	var m = data.get("learn", {})
	if not (m is Dictionary):
		m = {}
	var a: Array = m.get(puz, [])
	if not a.has(id):
		a.append(id)
	m[puz] = a
	set_val("learn", m)
