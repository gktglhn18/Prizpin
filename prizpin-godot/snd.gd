class_name Snd
extends Node
## Sesler. Hiçbir ses dosyası yok: hepsi kodla üretilir (yumuşak "tık" sesleri ve nota sesleri).
## Zamana karşı modlarında (race) sesler daha canlı ve notalı, diğer ekranlarda yumuşaktır.

const RATE := 22050
const WARM := ["click", "tick0", "tick1", "tick2", "thresh", "settle", "plus", "win0", "win1", "over", "whoosh", "beep0", "beep1", "warn0", "warn1", "sndon"]

var on := true
var race := false
var cache := {}
var players: Array = []
var _warm_i := 0
var _last_tick := 0
var _noise := RandomNumberGenerator.new()


func _ready() -> void:
	_noise.seed = 7
	for i in range(8):
		var p := AudioStreamPlayer.new()
		add_child(p)
		players.append(p)


func _process(_delta: float) -> void:
	# Açılışta sesleri her karede birer tane önceden hazırla (takılma olmasın).
	if _warm_i < WARM.size() * 2:
		var k: String = WARM[_warm_i % WARM.size()]
		var r := _warm_i >= WARM.size()
		_wave(k, r)
		_warm_i += 1


# ---------------------------------------------------------------- üretim

func _new_buf(sec: float) -> PackedFloat32Array:
	var b := PackedFloat32Array()
	b.resize(int(sec * RATE))
	return b


func _add_tone(buf: PackedFloat32Array, f: float, t: float, d: float, v: float, f2: float = 0.0) -> void:
	var s0 := int(t * RATE)
	var n := int(d * RATE)
	var att := 0.008
	var ph := 0.0
	for i in range(n):
		var idx := s0 + i
		if idx >= buf.size():
			break
		var tt := float(i) / RATE
		var fr := f
		if f2 > 0.0:
			fr = f * pow(f2 / f, tt / d)
		ph += TAU * fr / RATE
		var g: float
		if tt < att:
			g = 0.0001 * pow(v / 0.0001, tt / att)
		else:
			g = v * pow(0.0001 / v, (tt - att) / maxf(0.001, d - att))
		buf[idx] += sin(ph) * g


## Filtrelenmiş gürültü: kind 0 = alçak geçiren, 1 = band geçiren. f0'dan f1'e kayabilir.
func _add_noise(buf: PackedFloat32Array, kind: int, t: float, d: float, v: float, f0: float, f1: float, q: float, att_frac: float) -> void:
	var s0 := int(t * RATE)
	var n := int(d * RATE)
	var low := 0.0
	var band := 0.0
	var q1 := 1.0 / q
	var att := maxf(0.003, d * att_frac)
	for i in range(n):
		var idx := s0 + i
		if idx >= buf.size():
			break
		var tt := float(i) / RATE
		var fc := f0 * pow(f1 / f0, tt / d)
		var f := 2.0 * sin(PI * minf(fc, 3600.0) / RATE)
		var x := _noise.randf() * 2.0 - 1.0
		var high := x - low - q1 * band
		band += f * high
		low += f * band
		var y := low if kind == 0 else band * q1
		var g: float
		if tt < att:
			g = 0.0001 * pow(v / 0.0001, tt / att)
		else:
			g = v * pow(0.0001 / v, (tt - att) / maxf(0.001, d - att))
		buf[idx] += y * g


func _burst(buf: PackedFloat32Array, t: float, d: float, v: float, kind: int, f: float, q: float) -> void:
	_add_noise(buf, kind, t, d, v, f, f, q, 0.003 / d)


func _finish(buf: PackedFloat32Array) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(buf.size() * 2)
	var lp := 0.0
	var a := 1.0 - exp(-TAU * 3500.0 / RATE)
	for i in range(buf.size()):
		lp += a * (buf[i] * 0.8 - lp)
		data.encode_s16(i * 2, int(clampf(lp, -1.0, 1.0) * 32000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = data
	return w


func _wave(key: String, r: bool) -> AudioStreamWAV:
	var ck := key + ("_r" if r else "")
	if cache.has(ck):
		return cache[ck]
	var w := _make(key, r)
	cache[ck] = w
	return w


func _make(key: String, r: bool) -> AudioStreamWAV:
	var b: PackedFloat32Array
	match key:
		"click":
			b = _new_buf(0.06)
			_burst(b, 0.0, 0.02, 0.3, 1, 1800.0, 1.0)
		"tick0", "tick1", "tick2":
			b = _new_buf(0.08)
			var f := 1300.0 + 250.0 * float(key.substr(4).to_int())
			_burst(b, 0.0, 0.03, 0.5, 1, f, 1.2)
		"thresh":
			b = _new_buf(0.06)
			_burst(b, 0.0, 0.025, 0.35, 1, 1500.0 if r else 1000.0, 1.1)
		"settle":
			b = _new_buf(0.12)
			_burst(b, 0.0, 0.045, 0.55, 1, 1300.0 if r else 950.0, 0.9)
			if r:
				_add_tone(b, 520.0, 0.0, 0.07, 0.12, 440.0)
		"beep0", "beep1":
			var go := key == "beep1"
			b = _new_buf(0.6)
			if r:
				if go:
					_add_tone(b, 587.0, 0.0, 0.45, 0.34)
					_add_tone(b, 880.0, 0.0, 0.45, 0.2)
				else:
					_add_tone(b, 392.0, 0.0, 0.18, 0.32)
			else:
				_burst(b, 0.0, 0.07, 0.7, 0, 650.0, 0.8)
				if go:
					_burst(b, 0.16, 0.09, 0.8, 0, 520.0, 0.7)
		"warn0", "warn1":
			var late := key == "warn1"
			b = _new_buf(0.3)
			if r:
				_burst(b, 0.0, 0.04, 0.5, 1, 1700.0, 1.2)
				_add_tone(b, 880.0 if late else 660.0, 0.0, 0.09, 0.2)
				if late:
					_add_tone(b, 880.0, 0.13, 0.09, 0.18)
			else:
				_burst(b, 0.0, 0.05, 0.4, 0, 900.0, 0.8)
		"plus":
			b = _new_buf(0.55)
			if r:
				_add_tone(b, 523.0, 0.0, 0.14, 0.26)
				_add_tone(b, 784.0, 0.09, 0.22, 0.26)
				_add_tone(b, 1047.0, 0.18, 0.3, 0.16)
			else:
				_burst(b, 0.0, 0.04, 0.5, 1, 1200.0, 1.0)
				_burst(b, 0.09, 0.05, 0.45, 1, 1500.0, 1.0)
		"win0", "win1":
			var rec := key == "win1"
			b = _new_buf(1.5)
			if r:
				var notes := [392.0, 523.0, 659.0, 784.0]
				if rec:
					notes.append(1047.0)
				for i in range(notes.size()):
					_add_tone(b, notes[i], i * 0.09, 0.4, 0.26)
			else:
				_add_noise(b, 1, 0.0, 1.2 if rec else 0.9, 0.16, 250.0, 900.0, 0.9, 0.4)
				var ts := [0.5, 0.65, 0.8]
				for i in range(3 if rec else 2):
					_burst(b, ts[i], 0.06, 0.6, 0, 600.0, 0.8)
		"over":
			b = _new_buf(0.8)
			if r:
				_add_tone(b, 392.0, 0.0, 0.25, 0.28)
				_add_tone(b, 294.0, 0.2, 0.45, 0.28)
			else:
				_burst(b, 0.0, 0.2, 0.8, 0, 320.0, 0.7)
		"whoosh":
			b = _new_buf(0.9)
			_add_noise(b, 1, 0.0, 0.8, 0.1, 150.0, 700.0, 0.9, 0.4)
		_:
			b = _new_buf(0.1)
			_burst(b, 0.0, 0.05, 0.5, 0, 800.0, 0.8)
	return _finish(b)


# ---------------------------------------------------------------- çalma

func _play(key: String, r: bool = false) -> void:
	if not on or players.is_empty():
		return
	var w := _wave(key, r)
	var pl: AudioStreamPlayer = null
	for p in players:
		if not p.playing:
			pl = p
			break
	if pl == null:
		pl = players[0]
	pl.stream = w
	pl.play()


func set_race(b: bool) -> void:
	race = b


func click() -> void:
	_play("click")


func tick() -> void:
	var n := Time.get_ticks_msec()
	if n - _last_tick < 40:
		return
	_last_tick = n
	_play("tick%d" % (n % 3))


func thresh() -> void:
	_play("thresh", race)


func settle() -> void:
	_play("settle", race)


func beep(go: bool) -> void:
	_play("beep1" if go else "beep0", race)


func warn(sec: int) -> void:
	_play("warn1" if sec <= 3 else "warn0", race)


func plus() -> void:
	_play("plus", race)


func win(record: bool) -> void:
	_play("win1" if record else "win0", race)


func over() -> void:
	_play("over", race)


func whoosh() -> void:
	_play("whoosh")


func set_on(v: bool) -> void:
	on = v
	if on:
		_play("sndon")
