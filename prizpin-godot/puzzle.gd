class_name Puzzle
extends Node3D
## Bulmaca motoru: küp (2x2, 3x3, 4x4, 5x5, Kule, Floppy), Piramit ve Skewb.
## Bu düğüm, bulmacanın bütün parçalarını taşır. Yerel koordinatlar bu düğümünkidir.
##
## Hamle = {"axis": eksen, "layer": katman, "turns": tur sayısı (+1/-1/+2)}
## Artı yön: eksenin ucundan bakınca saat yönünün tersi.

signal step_played

const KEYS := ["+x", "-x", "+y", "-y", "+z", "-z"]
const NOTE := {
	"R": [0, 1, -1], "L": [0, -1, 1], "U": [1, 1, -1], "D": [1, -1, 1],
	"F": [2, 1, -1], "B": [2, -1, 1], "E": [1, 0, 1],
}

static var DEFAULT_FACE: Array = [
	Color("d62839"), Color("ff7b1c"), Color("f5f5ef"),
	Color("ffd400"), Color("1fa65a"), Color("1f5fd6"),
]
static var DEFAULT_PYRA: Array = [Color("e5352b"), Color("f6c915"), Color("22a559"), Color("2b66dd")]
static var face_colors: Array = DEFAULT_FACE.duplicate()
static var pyra_colors: Array = DEFAULT_PYRA.duplicate()
static var sticker_mats: Array = []
static var pyra_mats: Array = []
static var body_mat: StandardMaterial3D = null
static var prism_mat: StandardMaterial3D = null
static var defs: Dictionary = {}

const ORDER := ["c2", "c3", "c4", "c5", "p", "sk", "tw", "fl"]

# ---- bu bulmacanın durumu ----
var def: Dictionary = {}
var kind := "cube"
var pieces: Array = []
var axes: Array = []
var layers_of: Array = []        # küp: her eksenin katman konumları
var layers: Array = []           # küp: x ekseninin katmanları (ders çevirmesi için)
var axes_ok: Array = []
var fit_r := 4.0
var vpos: Array = []             # piramit/skewb köşe noktaları (harfler için)
var slots: Array = []
var slot_face: Array = []
var _off: Array = []

var turn = null                  # şu an ayrılmış katman (Dictionary) ya da null
var anim = null                  # çalışan dönüş animasyonu
var queue: Array = []            # sırada bekleyen hamleler


static func get_def(id: String) -> Dictionary:
	if defs.is_empty():
		_make_defs()
	return defs[id]


static func _make_defs() -> void:
	defs = {
		"c2": {"id": "c2", "kind": "cube", "n": 2, "d": [2, 2, 2], "name": "2×2", "std": 13, "base": 4, "max": 9, "time": 60, "bonus": 15},
		"c3": {"id": "c3", "kind": "cube", "n": 3, "d": [3, 3, 3], "name": "3×3", "std": 25, "base": 4, "max": 8, "time": 120, "bonus": 30},
		"c4": {"id": "c4", "kind": "cube", "n": 4, "d": [4, 4, 4], "name": "4×4", "std": 42, "base": 4, "max": 6, "time": 240, "bonus": 60},
		"c5": {"id": "c5", "kind": "cube", "n": 5, "d": [5, 5, 5], "name": "5×5", "std": 60, "base": 3, "max": 4, "time": 420, "bonus": 90},
		"p": {"id": "p", "kind": "pyra", "name": "Piramit", "std": 16, "base": 4, "max": 8, "time": 90, "bonus": 20},
		"sk": {"id": "sk", "kind": "skewb", "name": "Skewb", "std": 14, "base": 4, "max": 8, "time": 90, "bonus": 20},
		"tw": {"id": "tw", "kind": "cube", "d": [2, 3, 2], "steps": [PI, PI / 2.0, PI], "name": "Kule", "std": 20, "base": 4, "max": 8, "time": 120, "bonus": 25},
		"fl": {"id": "fl", "kind": "cube", "d": [3, 3, 1], "steps": [PI, PI, PI], "only": [[-1, 1], [-1, 1], []], "name": "Floppy", "std": 14, "base": 3, "max": 6, "time": 90, "bonus": 20},
	}


# ---------------------------------------------------------------- malzemeler

static func _mat(col: Color, double_sided: bool) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness = 0.45
	if double_sided:
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


static func init_mats() -> void:
	if body_mat != null:
		return
	body_mat = _mat(Color("16181d"), false)
	body_mat.roughness = 0.6
	prism_mat = _mat(Color("16181d"), true)
	prism_mat.roughness = 0.6
	for i in range(6):
		sticker_mats.append(_mat(face_colors[i], true))
	for j in range(4):
		pyra_mats.append(_mat(pyra_colors[j], true))


## useDefault true ise kayıtlı renkler yerine varsayılanlar gösterilir (öğretici).
static func apply_colors(use_default: bool) -> void:
	init_mats()
	for i in range(6):
		sticker_mats[i].albedo_color = DEFAULT_FACE[i] if use_default else face_colors[i]
	for j in range(4):
		pyra_mats[j].albedo_color = DEFAULT_PYRA[j] if use_default else pyra_colors[j]


static func pulse(kind_name: String, idx: int, on: bool) -> void:
	var m: StandardMaterial3D = sticker_mats[idx] if kind_name == "cube" else pyra_mats[idx]
	m.emission_enabled = on
	m.emission = Color(0.47, 0.47, 0.47)


# ---------------------------------------------------------------- yardımcılar

static func dominant_axis(v: Vector3) -> int:
	var ax := absf(v.x)
	var ay := absf(v.y)
	var az := absf(v.z)
	if ax >= ay and ax >= az:
		return 0
	return 1 if ay >= az else 2


static func round_half(v: float) -> float:
	return roundf(v * 2.0) / 2.0


static func _ease_out(p: float) -> float:
	return 1.0 - pow(1.0 - p, 3.0)


static func _ease_inout(p: float) -> float:
	return 4.0 * p * p * p if p < 0.5 else 1.0 - pow(-2.0 * p + 2.0, 3.0) / 2.0


## Düz, dışbükey bir çokgen (isteğe bağlı kalınlıkla). Döndürür: {"mesh", "tris"}
static func _poly(rel: Array, nrm: Vector3, sc: float, lift: float, thick: float) -> Dictionary:
	var t: Array = []
	for v in rel:
		t.append(v * sc + nrm * lift)
	var cen := Vector3.ZERO
	for v in t:
		cen += v
	cen /= float(t.size())
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var tris := PackedVector3Array()
	st.set_normal(nrm)
	for i in range(1, t.size() - 1):
		st.add_vertex(t[0])
		st.add_vertex(t[i])
		st.add_vertex(t[i + 1])
		tris.append(t[0])
		tris.append(t[i])
		tris.append(t[i + 1])
	if thick > 0.0:
		var b: Array = []
		for v in t:
			b.append(v - nrm * thick)
		st.set_normal(-nrm)
		for i in range(1, b.size() - 1):
			st.add_vertex(b[0])
			st.add_vertex(b[i + 1])
			st.add_vertex(b[i])
			tris.append(b[0])
			tris.append(b[i + 1])
			tris.append(b[i])
		for i in range(t.size()):
			var j := (i + 1) % t.size()
			var mid: Vector3 = (t[i] + t[j]) * 0.5
			var sn: Vector3 = ((t[j] - t[i]) as Vector3).cross(nrm).normalized()
			if sn.dot(mid - cen) < 0.0:
				sn = -sn
			st.set_normal(sn)
			st.add_vertex(t[i])
			st.add_vertex(b[i])
			st.add_vertex(b[j])
			st.add_vertex(t[i])
			st.add_vertex(b[j])
			st.add_vertex(t[j])
			tris.append(t[i])
			tris.append(b[i])
			tris.append(b[j])
			tris.append(t[i])
			tris.append(b[j])
			tris.append(t[j])
	return {"mesh": st.commit(), "tris": tris}


static func _rounded_square(w: float, r: float) -> ArrayMesh:
	var h := w / 2.0
	var pts: Array = []
	var corners := [Vector2(h - r, h - r), Vector2(-h + r, h - r), Vector2(-h + r, -h + r), Vector2(h - r, -h + r)]
	for c in range(4):
		for k in range(7):
			var a: float = (c * 90.0 + k * 15.0) * PI / 180.0
			pts.append(Vector3(corners[c].x + cos(a) * r, corners[c].y + sin(a) * r, 0.0))
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_normal(Vector3(0, 0, 1))
	for i in range(pts.size()):
		var j := (i + 1) % pts.size()
		st.add_vertex(Vector3.ZERO)
		st.add_vertex(pts[i])
		st.add_vertex(pts[j])
	return st.commit()


# ---------------------------------------------------------------- kurulum

func clear() -> void:
	for p in pieces:
		p.queue_free()
	pieces.clear()
	turn = null
	anim = null
	queue.clear()
	axes = []
	vpos = []
	slots = []
	slot_face = []
	layers_of = []
	layers = []
	axes_ok = []


func load_puzzle(id: String) -> void:
	init_mats()
	clear()
	def = get_def(id)
	kind = def["kind"]
	if kind == "cube":
		_build_cube()
	elif kind == "pyra":
		_build_pyra()
	else:
		_build_skewb()


func _build_cube() -> void:
	var d: Array = def["d"]
	_off = []
	for n in d:
		_off.append((n - 1) / 2.0)
	layers_of = [[], [], []]
	for a in range(3):
		if def.has("only"):
			for v in def["only"][a]:
				layers_of[a].append(float(v))
		else:
			for i in range(d[a]):
				layers_of[a].append(i - _off[a])
	axes_ok = []
	for k in range(3):
		if layers_of[k].size() > 0:
			axes_ok.append(k)
	layers = layers_of[0]
	axes = [Vector3(1, 0, 0), Vector3(0, 1, 0), Vector3(0, 0, 1)]
	var body_mesh := BoxMesh.new()
	body_mesh.size = Vector3.ONE * 0.97
	var sticker_mesh := _rounded_square(0.84, 0.14)
	for xi in range(d[0]):
		for yi in range(d[1]):
			for zi in range(d[2]):
				var pos := Vector3(xi - _off[0], yi - _off[1], zi - _off[2])
				var c := Node3D.new()
				c.position = pos
				var body := MeshInstance3D.new()
				body.mesh = body_mesh
				body.material_override = body_mat
				c.add_child(body)
				var sticks: Array = []
				for i in range(6):
					var n: Vector3 = _normals()[i]
					var ax := dominant_axis(n)
					if absf(n[ax] * pos[ax] - _off[ax]) > 0.000001:
						continue
					var s := MeshInstance3D.new()
					s.mesh = sticker_mesh
					s.material_override = sticker_mats[i]
					var up := Vector3.FORWARD if absf(n.y) > 0.5 else Vector3.UP
					s.transform = Transform3D(Basis.looking_at(-n, up), n * 0.488)
					c.add_child(s)
					sticks.append({"local": n, "color": i})
				c.set_meta("sticks", sticks)
				add_child(c)
				pieces.append(c)
	fit_r = 0.72 * sqrt(float(d[0] * d[0] + d[1] * d[1] + d[2] * d[2]))


static func _normals() -> Array:
	return [Vector3(1, 0, 0), Vector3(-1, 0, 0), Vector3(0, 1, 0), Vector3(0, -1, 0), Vector3(0, 0, 1), Vector3(0, 0, -1)]


func _add_poly_piece(rel: Array, nrm: Vector3, g: Vector3, thick: float, sc_prism: float, sc_st: float, mat: StandardMaterial3D, color_idx: int) -> void:
	var grp := Node3D.new()
	grp.position = g
	var pr := _poly(rel, nrm, sc_prism, 0.0, thick)
	var prism := MeshInstance3D.new()
	prism.mesh = pr["mesh"]
	prism.material_override = prism_mat
	grp.add_child(prism)
	var st := _poly(rel, nrm, sc_st, 0.004, 0.0)
	var sm := MeshInstance3D.new()
	sm.mesh = st["mesh"]
	sm.material_override = mat
	grp.add_child(sm)
	grp.set_meta("tris", pr["tris"])
	grp.set_meta("color", color_idx)
	grp.set_meta("slot", slots.size())
	slots.append(g)
	add_child(grp)
	pieces.append(grp)


func _build_pyra() -> void:
	var s := 1.3
	var vs: Array = []
	for a in [[1, 1, 1], [1, -1, -1], [-1, 1, -1], [-1, -1, 1]]:
		vs.append(Vector3(a[0], a[1], a[2]) * s)
	var v2: float = vs[0].length_squared()
	for j in range(4):
		var idx: Array = []
		for k in range(4):
			if k != j:
				idx.append(k)
		var pa: Vector3 = vs[idx[0]]
		var pb: Vector3 = vs[idx[1]]
		var pc: Vector3 = vs[idx[2]]
		var nrm: Vector3 = -(vs[j] as Vector3).normalized()
		var tris: Array = []
		for a in range(3):
			for b in range(3 - a):
				tris.append([[a + 1, b, 2 - a - b], [a, b + 1, 2 - a - b], [a, b, 3 - a - b]])
		for a in range(2):
			for b in range(2 - a):
				tris.append([[a, b + 1, 2 - a - b], [a + 1, b, 2 - a - b], [a + 1, b + 1, 1 - a - b]])
		for tri in tris:
			var p3: Array = []
			for g in tri:
				p3.append(pa * (g[0] / 3.0) + pb * (g[1] / 3.0) + pc * (g[2] / 3.0))
			var g0: Vector3 = (p3[0] + p3[1] + p3[2]) / 3.0
			var rel: Array = []
			for p in p3:
				rel.append(p - g0)
			slot_face.append(j)
			_add_poly_piece(rel, nrm, g0, 0.14, 0.985, 0.78, pyra_mats[j], j)
	axes = []
	vpos = []
	for v in vs:
		axes.append((v as Vector3).normalized())
		vpos.append(v)
	fit_r = 3.5
	set_meta("v2", v2)
	set_meta("vs", vs)


func _build_skewb() -> void:
	var h := 1.5
	axes = []
	for a in [[1, 1, 1], [1, -1, -1], [-1, 1, -1], [-1, -1, 1]]:
		axes.append(Vector3(a[0], a[1], a[2]).normalized())
	var ax_basis := [Vector3(1, 0, 0), Vector3(0, 1, 0), Vector3(0, 0, 1)]
	var nl := _normals()
	for fi in range(6):
		var n: Vector3 = nl[fi]
		var ai := dominant_axis(n)
		var u: Vector3 = ax_basis[(ai + 1) % 3]
		var v := n.cross(u)
		var polys: Array = [[[h, 0.0], [0.0, h], [-h, 0.0], [0.0, -h]]]
		for c in [[1, 1], [1, -1], [-1, 1], [-1, -1]]:
			polys.append([[c[0] * h, c[1] * h], [c[0] * h, 0.0], [0.0, c[1] * h]])
		for poly in polys:
			var pts: Array = []
			for q in poly:
				pts.append(n * h + u * q[0] + v * q[1])
			var g := Vector3.ZERO
			for p in pts:
				g += p
			g /= float(pts.size())
			var rel: Array = []
			for p in pts:
				rel.append(p - g)
			slot_face.append(fi)
			_add_poly_piece(rel, n, g, 0.4, 0.985, 0.86, sticker_mats[fi], fi)
	vpos = []
	for a in axes:
		vpos.append(a * h * sqrt(3.0))
	fit_r = 3.8


# ---------------------------------------------------------------- bulmaca kuralları

func step_of(axis: int) -> float:
	if kind == "cube":
		return def["steps"][axis] if def.has("steps") else PI / 2.0
	return PI * 2.0 / 3.0


func max_of(axis: int) -> int:
	if kind == "cube":
		return 1 if step_of(axis) > PI - 0.000001 else 2
	return 1


func _bary(p: Vector3, i: int) -> float:
	var vs: Array = get_meta("vs")
	return (3.0 * p.dot(vs[i]) / float(get_meta("v2")) + 1.0) / 4.0


func in_layer(p: Node3D, axis: int, layer) -> bool:
	if kind == "cube":
		return absf(p.position[axis] - float(layer)) < 0.25
	if kind == "pyra":
		return _bary(p.position, axis) > 1.0 - float(layer) / 3.0
	return float(layer) * p.position.dot(axes[axis]) > 0.0


func snap(p: Node3D) -> void:
	if kind == "cube":
		var pos := p.position
		pos = Vector3(round_half(pos.x), round_half(pos.y), round_half(pos.z))
		var b := p.basis
		p.transform = Transform3D(Basis(b.x.round(), b.y.round(), b.z.round()), pos)
	else:
		var best := 0
		var bd := 1e9
		for i in range(slots.size()):
			var dd := p.position.distance_squared_to(slots[i])
			if dd < bd:
				bd = dd
				best = i
		p.transform = Transform3D(p.basis.orthonormalized(), slots[best])
		p.set_meta("slot", best)


func candidates(hit: Dictionary) -> Array:
	var piece: Node3D = hit["piece"]
	var out: Array = []
	if kind == "cube":
		var na := dominant_axis(hit["normal"])
		for i in range(3):
			if i == na:
				continue
			var l := round_half(piece.position[i])
			for x in layers_of[i]:
				if absf(x - l) < 0.001:
					out.append({"axis": i, "layer": l})
					break
	elif kind == "pyra":
		for i in range(4):
			var b := _bary(piece.position, i)
			if b > 2.0 / 3.0:
				out.append({"axis": i, "layer": 1})
			elif b > 1.0 / 3.0:
				out.append({"axis": i, "layer": 2})
	else:
		for i in range(4):
			var d := piece.position.dot(axes[i])
			if absf(d) > 0.001:
				out.append({"axis": i, "layer": 1 if d > 0.0 else -1})
	return out


func random_move(rng: Rng, prev) -> Dictionary:
	var m: Dictionary
	while true:
		if kind == "cube":
			var ax: int = axes_ok[int(floor(rng.next() * axes_ok.size()))]
			var ls: Array = layers_of[ax]
			m = {"axis": ax, "layer": ls[int(floor(rng.next() * ls.size()))], "turns": 1 if rng.next() < 0.5 else -1}
			if prev == null or axes_ok.size() <= 1 or prev["axis"] != m["axis"]:
				break
		elif kind == "pyra":
			m = {"axis": int(floor(rng.next() * 4.0)), "layer": 2 if rng.next() < 0.65 else 1, "turns": 1 if rng.next() < 0.5 else -1}
			if prev == null or prev["axis"] != m["axis"]:
				break
		else:
			m = {"axis": int(floor(rng.next() * 4.0)), "layer": 1 if rng.next() < 0.5 else -1, "turns": 1 if rng.next() < 0.5 else -1}
			if prev == null or prev["axis"] != m["axis"]:
				break
	return m


func scramble_list(count: int, rng: Rng) -> Array:
	var list: Array = []
	var prev = null
	while list.size() < count:
		prev = random_move(rng, prev)
		list.append(prev)
	return list


func solved() -> bool:
	var map := {}
	if kind == "cube":
		for c in pieces:
			for s in c.get_meta("sticks"):
				var nv: Vector3 = c.basis * s["local"]
				var ai := dominant_axis(nv)
				var key := (1 if nv[ai] > 0.0 else -1) * (ai + 1)
				if not map.has(key):
					map[key] = s["color"]
				elif map[key] != s["color"]:
					return false
		return true
	for p in pieces:
		var f: int = slot_face[p.get_meta("slot")]
		var c: int = p.get_meta("color")
		if not map.has(f):
			map[f] = c
		elif map[f] != c:
			return false
	return true


# ---------------------------------------------------------------- dönüş ve animasyon

func busy() -> bool:
	return turn != null or anim != null or queue.size() > 0


func begin_turn(axis: int, layer) -> Dictionary:
	var grp: Array = []
	var bases: Array = []
	for p in pieces:
		if in_layer(p, axis, layer):
			grp.append(p)
			bases.append(p.transform)
	return {"axis": axis, "layer": layer, "group": grp, "bases": bases, "angle": 0.0}


func set_angle(t: Dictionary, a: float) -> void:
	t["angle"] = a
	var rot := Transform3D(Basis(axes[t["axis"]], a), Vector3.ZERO)
	var g: Array = t["group"]
	var b: Array = t["bases"]
	for i in range(g.size()):
		g[i].transform = rot * b[i]


func end_turn(t: Dictionary) -> void:
	for p in t["group"]:
		snap(p)


func animate_turn(t: Dictionary, to: float, dur_ms: float, done: Callable, inout: bool) -> void:
	anim = {"t": t, "from": t["angle"], "to": to, "t0": float(Time.get_ticks_msec()), "dur": maxf(1.0, dur_ms), "done": done, "inout": inout}


func step(now_ms: float) -> void:
	if anim == null:
		return
	var a: Dictionary = anim
	var p := clampf((now_ms - a["t0"]) / a["dur"], 0.0, 1.0)
	var e := _ease_inout(p) if a["inout"] else _ease_out(p)
	set_angle(a["t"], a["from"] + (a["to"] - a["from"]) * e)
	if p >= 1.0:
		anim = null
		end_turn(a["t"])
		turn = null
		if not (a["done"] as Callable).is_null():
			(a["done"] as Callable).call()


func _pump() -> void:
	if turn != null or anim != null or queue.is_empty():
		return
	var q: Dictionary = queue.pop_front()
	var m: Dictionary = q["m"]
	turn = begin_turn(m["axis"], m["layer"])
	animate_turn(turn, float(m["turns"]) * step_of(m["axis"]), q["dur"], func() -> void:
		step_played.emit()
		if not (q["done"] as Callable).is_null():
			(q["done"] as Callable).call()
		_pump(), true)


func enqueue(m: Dictionary, dur_ms: float, done: Callable = Callable()) -> void:
	queue.append({"m": m, "dur": dur_ms, "done": done})
	_pump()


func apply_instant(moves: Array) -> void:
	for m in moves:
		var t := begin_turn(m["axis"], m["layer"])
		set_angle(t, float(m["turns"]) * step_of(m["axis"]))
		end_turn(t)


static func invert_moves(list: Array) -> Array:
	var out: Array = []
	for i in range(list.size() - 1, -1, -1):
		var m: Dictionary = list[i]
		out.append({"axis": m["axis"], "layer": m["layer"], "turns": -int(m["turns"])})
	return out


# ---------------------------------------------------------------- yazım (R U R' U' ...)

## "R" sağ dış katman, "2R" sağdan ikinci katman, "R'" ters, "R2" yarım tur.
## Piramit ve Skewb'de ekrandaki köşe harfleri A B C D kullanılır.
## Hata olursa boş liste döner ve push_error yazar.
func parse_alg(text: String) -> Array:
	var out: Array = []
	var toks := text.strip_edges().split(" ", false)
	if kind == "pyra" or kind == "skewb":
		var re := RegEx.new()
		re.compile("^([A-Da-d])(')?$")
		for tk in toks:
			var m := re.search(tk)
			if m == null:
				push_error("Bozuk hamle: " + tk)
				return []
			var ch := m.get_string(1)
			var up := ch == ch.to_upper()
			if kind == "skewb" and not up:
				push_error("Bozuk hamle: " + tk)
				return []
			out.append({"axis": "ABCDabcd".find(ch) % 4, "layer": (2 if up else 1) if kind == "pyra" else 1, "turns": 1 if m.get_string(2) != "" else -1})
		return out
	var d: Array = def["d"]
	var re2 := RegEx.new()
	re2.compile("^(\\d?)([RLUDFBE])(2|')?$")
	for tk in toks:
		var m := re2.search(tk)
		if m == null:
			push_error("Bozuk hamle: " + tk)
			return []
		var nt: Array = NOTE[m.get_string(2)]
		var axis: int = nt[0]
		var depth := int(m.get_string(1)) if m.get_string(1) != "" else 1
		var layer := 0.0
		if nt[1] != 0:
			layer = float(nt[1]) * ((d[axis] - 1) / 2.0 - (depth - 1))
		var quarter := 0
		var suf := m.get_string(3)
		if suf == "2":
			quarter = 2
		elif suf == "'":
			quarter = -int(nt[2])
		else:
			quarter = int(nt[2])
		var stp: float = def["steps"][axis] if def.has("steps") else PI / 2.0
		var turns := float(quarter) * (PI / 2.0) / stp
		if absf(turns - roundf(turns)) > 0.000001:
			push_error("İzin verilmeyen dönüş: " + tk)
			return []
		out.append({"axis": axis, "layer": layer, "turns": int(roundf(turns))})
	return out


# ---------------------------------------------------------------- tıklama (ışın)

## Işın bu düğümün yerel koordinatlarında verilir. En yakın parçayı döndürür; yoksa boş sözlük.
func pick(o: Vector3, d: Vector3) -> Dictionary:
	var best_t := INF
	var result := {}
	if kind == "cube":
		for c in pieces:
			var ctr: Vector3 = c.position
			var t_near := -INF
			var t_far := INF
			var n_axis := -1
			var hit := true
			for i in range(3):
				if absf(d[i]) < 0.00000001:
					if absf(o[i] - ctr[i]) > 0.5:
						hit = false
						break
				else:
					var t1: float = (ctr[i] - 0.5 - o[i]) / d[i]
					var t2: float = (ctr[i] + 0.5 - o[i]) / d[i]
					var tn := minf(t1, t2)
					var tf := maxf(t1, t2)
					if tn > t_near:
						t_near = tn
						n_axis = i
					t_far = minf(t_far, tf)
			if not hit or n_axis < 0 or t_near > t_far or t_far < 0.0:
				continue
			if t_near < best_t:
				best_t = t_near
				var nrm := Vector3.ZERO
				nrm[n_axis] = -signf(d[n_axis])
				result = {"piece": c, "normal": nrm, "point": o + d * t_near}
		return result
	for p in pieces:
		var tr: Transform3D = p.transform
		var tris: PackedVector3Array = p.get_meta("tris")
		var i := 0
		while i + 2 < tris.size():
			var a: Vector3 = tr * tris[i]
			var b: Vector3 = tr * tris[i + 1]
			var c: Vector3 = tr * tris[i + 2]
			var h = Geometry3D.ray_intersects_triangle(o, d, a, b, c)
			if h != null:
				var tt := o.distance_to(h)
				if tt < best_t:
					best_t = tt
					result = {"piece": p, "normal": (b - a).cross(c - a).normalized(), "point": h}
			i += 3
	return result
