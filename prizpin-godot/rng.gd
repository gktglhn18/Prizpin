class_name Rng
extends RefCounted
## Rastgele sayı üreteci. Tohum verilirse hep aynı diziyi üretir (günlük karışım, seviyeler).
## Tohum -1 ise her seferinde farklı sayılar verir.

var _a := 0
var _seeded := false
var _gen := RandomNumberGenerator.new()


func _init(seed_value: int = -1) -> void:
	if seed_value >= 0:
		_seeded = true
		_a = seed_value & 0xFFFFFFFF
	else:
		_gen.randomize()


## 0 ile 1 arasında bir sayı (mulberry32).
func next() -> float:
	if not _seeded:
		return _gen.randf()
	_a = (_a + 0x6D2B79F5) & 0xFFFFFFFF
	var t := _a
	t = ((t ^ (t >> 15)) * (t | 1)) & 0xFFFFFFFF
	t = (t ^ (t + (((t ^ (t >> 7)) * (t | 61)) & 0xFFFFFFFF))) & 0xFFFFFFFF
	return float((t ^ (t >> 14)) & 0xFFFFFFFF) / 4294967296.0


static func hash_str(s: String) -> int:
	var h := 2166136261
	for i in range(s.length()):
		h = h ^ s.unicode_at(i)
		h = (h * 16777619) & 0xFFFFFFFF
	return h
