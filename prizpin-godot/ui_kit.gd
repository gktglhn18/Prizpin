class_name Ui
extends RefCounted
## Arayüz araçları: renkler (açık/koyu tema), düğme stilleri, ikonlar, kartlar, yıldızlar, konfeti.
## Boyutlar 1080 piksel genişliğe göre (telefon ekranı bu genişliğe ölçeklenir).

static var dark := false
static var bold_font: Font = null
static var mono_font: Font = null
static var base_font: Font = null
static var theme: Theme = null
static var _light: Dictionary = {}
static var _dark: Dictionary = {}


static func init_once() -> void:
	if not _light.is_empty():
		return
	_light = {
		"bg": Color("e6e2dc"), "bg2": Color("faf5ef"), "fg": Color("171b22"), "muted": Color("5b6472"),
		"line": Color("cdc6bc"), "panel": Color("faf5ef"), "accent": Color("c2410c"),
		"accent_soft": Color("fbe5da"), "good": Color("187a43"), "on_fg": Color("faf5ef"),
	}
	_dark = {
		"bg": Color("12151b"), "bg2": Color("232a36"), "fg": Color("eef1f6"), "muted": Color("9aa3b2"),
		"line": Color("313846"), "panel": Color("1a1f28"), "accent": Color("ff9a62"),
		"accent_soft": Color("3a2619"), "good": Color("5fd08c"), "on_fg": Color("12151b"),
	}
	# Oyunun yazı tipi: fonts klasöründeki font (CrimsonText, yoksa Righteous). Her telefonda aynı görünsün diye oyunla birlikte gelir.
	# Bu fontta olmayan harfler (Rusça, Çince, Hintçe) telefonun kendi fontuyla çizilir.
	for path in ["res://fonts/CrimsonText-Regular.ttf", "res://fonts/Righteous-Regular.ttf"]:
		if base_font == null and ResourceLoader.exists(path):
			var ff = load(path)
			if ff is FontFile:
				(ff as FontFile).allow_system_fallback = true
				base_font = ff
	# Crimson Text'te olmayan harfler için oyunla gelen yedek fontlar (tarayıcıda telefonun fontu kullanılamıyor):
	# FreeSerif = Rusça ve Hintçe harfler, Noto Serif SC = Çince harfler (yalnızca oyundaki karakterler).
	if base_font is FontFile:
		var fbs: Array[Font] = []
		for fp in ["res://fonts/FreeSerif-subset.ttf", "res://fonts/NotoSerifSC-subset.otf"]:
			if ResourceLoader.exists(fp):
				var fb = load(fp)
				if fb is Font:
					fbs.append(fb)
		(base_font as FontFile).fallbacks = fbs
	if base_font == null:
		var fv := FontVariation.new()
		fv.base_font = ThemeDB.fallback_font
		fv.variation_embolden = 0.55
		base_font = fv
	# Kalın yazılar için aynı fontun biraz kalınlaştırılmış hali.
	var bv := FontVariation.new()
	bv.base_font = base_font
	bv.variation_embolden = 0.6
	bold_font = bv
	mono_font = bv
	theme = Theme.new()
	theme.default_font = base_font


static func c(name: String) -> Color:
	init_once()
	return (_dark if dark else _light)[name]


static func sb(bg: Color, border: Color, radius: int, bw: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(bw)
	s.set_corner_radius_all(radius)
	s.anti_aliasing = true
	if bg.a > 0.9 and radius >= 20:
		s.shadow_color = Color(0, 0, 0, 0.07 if not dark else 0.25)
		s.shadow_size = 8
		s.shadow_offset = Vector2(0, 3)
	return s


static func lbl(text: String, size: int, color_name: String = "fg", bold: bool = false, align: int = HORIZONTAL_ALIGNMENT_LEFT, wrap: bool = false) -> Label:
	init_once()
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", c(color_name))
	if bold:
		l.add_theme_font_override("font", bold_font)
	l.horizontal_alignment = align
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if wrap:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size.x = 10
	return l


static func mono(text: String, size: int, color_name: String = "fg", align: int = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := lbl(text, size, color_name, false, align)
	l.add_theme_font_override("font", mono_font)
	return l


static func style_btn(b: Button, kind: String) -> void:
	init_once()
	var normal: StyleBoxFlat
	var pressed: StyleBoxFlat
	var disabled: StyleBoxFlat
	var fc := c("fg")
	var fdis := c("muted")
	if kind == "primary":
		normal = sb(c("fg"), c("fg"), 30, 2)
		pressed = sb(c("fg").lerp(c("bg"), 0.25), c("fg"), 30, 2)
		disabled = sb(c("line"), c("line"), 30, 2)
		fc = c("on_fg")
		fdis = c("muted")
	elif kind == "on":
		normal = sb(c("fg"), c("fg"), 30, 2)
		pressed = sb(c("fg").lerp(c("bg"), 0.25), c("fg"), 30, 2)
		disabled = normal
		fc = c("on_fg")
	elif kind == "icon":
		normal = sb(c("panel"), c("line"), 34, 2)
		pressed = sb(c("accent_soft"), c("accent"), 34, 2)
		disabled = normal
	else:
		normal = sb(c("panel"), c("line"), 30, 2)
		pressed = sb(c("accent_soft"), c("accent"), 30, 2)
		disabled = sb(c("bg2"), c("line"), 30, 2)
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", normal)
	b.add_theme_stylebox_override("pressed", pressed)
	b.add_theme_stylebox_override("disabled", disabled)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.add_theme_color_override("font_color", fc)
	b.add_theme_color_override("font_hover_color", fc)
	b.add_theme_color_override("font_pressed_color", fc if kind == "primary" or kind == "on" else c("accent"))
	b.add_theme_color_override("font_disabled_color", fdis)
	b.add_theme_font_override("font", bold_font)


static func btn(text: String, kind: String = "normal", h: int = 110, size: int = 43) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, h)
	b.add_theme_font_size_override("font_size", size)
	b.clip_text = true
	style_btn(b, kind)
	return b


## Üstte dört kenarlı bir kart. İçerik Control olarak verilir, tıklama "pressed" sinyaliyle gelir.
class Card extends PanelContainer:
	signal pressed
	var _btn: Button

	func _init(inner: Control, pad: int = 28, active: bool = false, border_accent: bool = false) -> void:
		mouse_filter = Control.MOUSE_FILTER_PASS
		var bg := Ui.c("panel")
		var bd := Ui.c("accent") if border_accent else Ui.c("line")
		if active:
			bg = Ui.c("fg")
			bd = Ui.c("fg")
		add_theme_stylebox_override("panel", Ui.sb(bg, bd, 30, 2))
		var m := MarginContainer.new()
		m.mouse_filter = Control.MOUSE_FILTER_IGNORE
		for side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
			m.add_theme_constant_override(side, pad)
		m.add_child(inner)
		add_child(m)
		_btn = Button.new()
		_btn.flat = true
		_btn.focus_mode = Control.FOCUS_NONE
		_btn.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
		_btn.add_theme_stylebox_override("hover", StyleBoxEmpty.new())
		_btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		var pr := StyleBoxFlat.new()
		pr.bg_color = Color(Ui.c("accent"), 0.14)
		pr.set_corner_radius_all(30)
		_btn.add_theme_stylebox_override("pressed", pr)
		_btn.pressed.connect(func() -> void: pressed.emit())
		add_child(_btn)


## Çizilen simgeler (SVG yerine kodla çiziliyor). 24x24'lük bir kutuya göre.
class IconBtn extends Button:
	var kind := "back"
	var active := false

	func _init(k: String = "back", s: int = 104) -> void:
		kind = k
		custom_minimum_size = Vector2(s, s)
		focus_mode = Control.FOCUS_NONE
		Ui.style_btn(self, "icon")

	func _draw() -> void:
		var u := size.x / 24.0
		var col := Ui.c("fg")
		var acc := Ui.c("accent")
		var w := 2.3 * u
		match kind:
			"back":
				draw_polyline(_p([Vector2(14.5, 5.5), Vector2(8, 12), Vector2(14.5, 18.5)], u), col, w, true)
			"plus":
				draw_line(Vector2(12, 6) * u, Vector2(12, 18) * u, col, w, true)
				draw_line(Vector2(6, 12) * u, Vector2(18, 12) * u, col, w, true)
			"minus":
				draw_line(Vector2(6, 12) * u, Vector2(18, 12) * u, col, w, true)
			"close":
				draw_line(Vector2(7, 7) * u, Vector2(17, 17) * u, col, w, true)
				draw_line(Vector2(17, 7) * u, Vector2(7, 17) * u, col, w, true)
			"globe":
				draw_arc(Vector2(12, 12) * u, 8.6 * u, 0.0, TAU, 40, col, w * 0.9, true)
				draw_line(Vector2(3.4, 12) * u, Vector2(20.6, 12) * u, col, w * 0.7, true)
				var pts := PackedVector2Array()
				for i in range(25):
					var a := TAU * i / 24.0
					pts.append(Vector2(12 + 4.4 * cos(a), 12 + 8.6 * sin(a)) * u)
				draw_polyline(pts, col, w * 0.7, true)
			"sound", "sound_off":
				var sp := _p([Vector2(4, 9.5), Vector2(4, 14.5), Vector2(7.5, 14.5), Vector2(12, 18.5), Vector2(12, 5.5), Vector2(7.5, 9.5), Vector2(4, 9.5)], u)
				draw_polyline(sp, col, w * 0.9, true)
				if kind == "sound":
					draw_arc(Vector2(11, 12) * u, 5.0 * u, -0.9, 0.9, 12, col, w * 0.9, true)
					draw_arc(Vector2(11, 12) * u, 8.4 * u, -0.8, 0.8, 14, col, w * 0.9, true)
				else:
					draw_line(Vector2(15.5, 9.5) * u, Vector2(21, 14.5) * u, col, w, true)
					draw_line(Vector2(21, 9.5) * u, Vector2(15.5, 14.5) * u, col, w, true)
			"gear":
				draw_arc(Vector2(12, 12) * u, 3.0 * u, 0.0, TAU, 24, col, w * 0.9, true)
				draw_arc(Vector2(12, 12) * u, 6.6 * u, 0.0, TAU, 36, col, w * 0.9, true)
				for i in range(8):
					var a := TAU * i / 8.0
					var d := Vector2(cos(a), sin(a))
					draw_line((Vector2(12, 12) + d * 6.6) * u, (Vector2(12, 12) + d * 9.2) * u, col, w * 1.15, true)
			"orbit":
				var oc := acc if active else col
				draw_arc(Vector2(12, 12) * u, 7.5 * u, 0.5, 5.4, 30, oc, w * 0.95, true)
				var tip := Vector2(12 + 7.5 * cos(5.4), 12 + 7.5 * sin(5.4))
				draw_polyline(_p([tip + Vector2(-0.2, -4.3), tip, tip + Vector2(4.2, -1.0)], u), oc, w * 0.95, true)
				draw_circle(Vector2(12, 12) * u, 1.9 * u, oc)

	func _p(pts: Array, u: float) -> PackedVector2Array:
		var out := PackedVector2Array()
		for p in pts:
			out.append(p * u)
		return out


## 3 yıldız (dolu ya da boş).
class StarsCtl extends Control:
	var value := 0
	var star_size := 44.0
	var dim := false

	func _init(v: int = 0, s: float = 44.0) -> void:
		value = v
		star_size = s
		custom_minimum_size = Vector2(s * 3.3, s)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var r := star_size * 0.5
		for i in range(3):
			var cx := r + i * star_size * 1.15
			var pts := PackedVector2Array()
			for k in range(10):
				var a := -PI / 2.0 + k * PI / 5.0
				var rr := r if k % 2 == 0 else r * 0.45
				pts.append(Vector2(cx + cos(a) * rr, r + sin(a) * rr))
			var on := i < value
			if on:
				draw_colored_polygon(pts, Ui.c("accent"))
			pts.append(pts[0])
			draw_polyline(pts, Ui.c("accent") if on else Ui.c("muted"), 3.0, true)


class Confetti extends Control:
	var bits: Array = []
	var colors := [Color("d62839"), Color("ff7b1c"), Color("f5f5ef"), Color("ffd400"), Color("1fa65a"), Color("1f5fd6")]

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_process(true)

	func burst(n: int, origin: Vector2, scale_f: float) -> void:
		for i in range(n):
			var a := randf() * TAU
			var sp := (0.25 + randf() * 0.7) * scale_f
			bits.append({
				"x": origin.x, "y": origin.y, "vx": cos(a) * sp, "vy": sin(a) * sp - 0.45 * scale_f,
				"r": (3.0 + randf() * 4.0) * scale_f, "rot": randf() * 6.0, "vr": (randf() - 0.5) * 0.02,
				"c": colors[i % colors.size()], "life": 1.0, "g": 0.0011 * scale_f,
			})

	func _process(delta: float) -> void:
		if bits.is_empty():
			return
		var dt := minf(64.0, delta * 1000.0)
		var alive: Array = []
		for b in bits:
			b["vy"] += b["g"] * dt
			b["x"] += b["vx"] * dt
			b["y"] += b["vy"] * dt
			b["rot"] += b["vr"] * dt
			b["life"] -= dt / 1900.0
			if b["life"] > 0.0 and b["y"] < size.y + 40.0:
				alive.append(b)
		bits = alive
		queue_redraw()

	func _draw() -> void:
		for b in bits:
			var col: Color = b["c"]
			col.a = clampf(b["life"] * 1.6, 0.0, 1.0)
			draw_set_transform(Vector2(b["x"], b["y"]), b["rot"], Vector2.ONE)
			var r: float = b["r"]
			draw_rect(Rect2(-r, -r * 0.5, r * 2.0, r), col)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Piramit ve Skewb'de köşe harfleri (A B C D).
class VLabel extends Control:
	var letter := "A"
	var alpha := 1.0

	func _init(l: String = "A") -> void:
		letter = l
		custom_minimum_size = Vector2(78, 78)
		size = Vector2(78, 78)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var col := Ui.c("fg")
		col.a = alpha
		draw_circle(size / 2.0, 39.0, col)
		var tc := Ui.c("on_fg")
		tc.a = alpha
		var f: Font = Ui.bold_font
		var fs := 44
		var w := f.get_string_size(letter, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		draw_string(f, Vector2(size.x / 2.0 - w / 2.0, size.y / 2.0 + fs * 0.35), letter, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, tc)


## "Nasıl oynanır" çizimleri (3 adım).
class HowArt extends Control:
	var idx := 0

	func _init(i: int = 0) -> void:
		idx = i
		custom_minimum_size = Vector2(0, 330)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var u := minf(size.x / 120.0, size.y / 100.0)
		var off := Vector2((size.x - 120.0 * u) / 2.0, (size.y - 100.0 * u) / 2.0)
		var col := Ui.c("fg")
		var acc := Ui.c("accent")
		var w := 3.0 * u
		var faint := Color(col, 0.5)
		if idx == 0:
			draw_rect(Rect2(off + Vector2(28, 24) * u, Vector2(64, 64) * u), col, false, w)
			for k in [45.0, 66.0]:
				draw_line(off + Vector2(28, k) * u, off + Vector2(92, k) * u, faint, w * 0.66)
			for k in [49.0, 71.0]:
				draw_line(off + Vector2(k, 24) * u, off + Vector2(k, 88) * u, faint, w * 0.66)
			draw_line(off + Vector2(14, 34) * u, off + Vector2(106, 34) * u, acc, w, true)
			draw_polyline(_pp([Vector2(98, 27), Vector2(106, 34), Vector2(98, 41)], u, off), acc, w, true)
		elif idx == 1:
			var hexp := _pp([Vector2(60, 22), Vector2(86, 36), Vector2(86, 64), Vector2(60, 78), Vector2(34, 64), Vector2(34, 36), Vector2(60, 22)], u, off)
			draw_polyline(hexp, col, w, true)
			draw_polyline(_pp([Vector2(34, 36), Vector2(60, 50), Vector2(86, 36)], u, off), faint, w * 0.66, true)
			draw_line(off + Vector2(60, 50) * u, off + Vector2(60, 78) * u, faint, w * 0.66)
			draw_arc(off + Vector2(60, 50) * u, 46.0 * u, -0.75, 0.05, 12, acc, w, true)
			draw_polyline(_pp([Vector2(106, 46), Vector2(103, 55), Vector2(95, 50)], u, off), acc, w, true)
			draw_arc(off + Vector2(60, 50) * u, 46.0 * u, 2.4, 3.2, 12, acc, w, true)
			draw_polyline(_pp([Vector2(14, 54), Vector2(17, 45), Vector2(25, 50)], u, off), acc, w, true)
		else:
			draw_arc(off + Vector2(48, 58) * u, 8.0 * u, 0.0, TAU, 24, col, w, true)
			draw_arc(off + Vector2(74, 42) * u, 8.0 * u, 0.0, TAU, 24, col, w, true)
			draw_line(off + Vector2(40, 66) * u, off + Vector2(28, 78) * u, acc, w, true)
			draw_line(off + Vector2(82, 34) * u, off + Vector2(94, 22) * u, acc, w, true)
			draw_polyline(_pp([Vector2(28, 68), Vector2(28, 78), Vector2(38, 78)], u, off), acc, w, true)
			draw_polyline(_pp([Vector2(94, 32), Vector2(94, 22), Vector2(84, 22)], u, off), acc, w, true)

	func _pp(pts: Array, u: float, off: Vector2) -> PackedVector2Array:
		var out := PackedVector2Array()
		for p in pts:
			out.append(off + p * u)
		return out


static func fmt_ms(ms: float) -> String:
	var m := int(ms / 60000.0)
	var s := int(ms / 1000.0) % 60
	var cs := int(ms / 10.0) % 100
	return "%02d:%02d.%02d" % [m, s, cs]
