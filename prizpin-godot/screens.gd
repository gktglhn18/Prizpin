class_name Screens
extends RefCounted
## Bütün ekranların çizimi: başlık, paneller, kazanma kartı, ayarlar penceresi, dil listesi.
## Her durum değişikliğinde ilgili parça baştan kurulur (render_*). Oyun mantığı game.gd içinde.

const MODE_ICONS := {"learn": "learn", "std": "std", "daily": "daily", "levels": "levels", "timeMenu": "clock", "time": "clock", "watch": "watch"}

var g: Game
var ui_layer: CanvasLayer
var root: Control
var confetti_ctl: Ui.Confetti
var vlabel_box: Control
var vlabels: Array = []
var zoom_box: VBoxContainer
var header_box: HBoxContainer
var win_holder: Control
var flash_panel: PanelContainer
var flash_label: Label
var flash_id := 0
var count_label: Label
var bottom_box: VBoxContainer
var hint_label: Label
var scroll: ScrollContainer
var panel_box: VBoxContainer
var lang_holder: Control
var modal_holder: Control
var modal_name := ""
var howto_idx := 0
var lang_open := false
var fit_frames := 0
var last_screen := ""

# oyun panelindeki canlı parçalar
var v1: Label = null
var task_label: Label = null
var chip_nodes: Array = []


func _init(game: Game) -> void:
	g = game


# ---------------------------------------------------------------- kurulum

func vp_size() -> Vector2:
	return g.get_viewport().get_visible_rect().size


func top_inset() -> float:
	var safe := DisplayServer.get_display_safe_area()
	var win := DisplayServer.window_get_size()
	if win.x <= 0 or safe.size.x <= 0:
		return 0.0
	return clampf(float(safe.position.y) * vp_size().x / float(win.x), 0.0, 120.0)


func bottom_inset() -> float:
	var safe := DisplayServer.get_display_safe_area()
	var win := DisplayServer.window_get_size()
	if win.y <= 0 or safe.size.y <= 0:
		return 0.0
	var below := float(win.y) - float(safe.position.y + safe.size.y)
	return clampf(below * vp_size().x / float(win.x), 0.0, 120.0)


func stage_top() -> float:
	return top_inset() + 30.0 + 104.0 + 10.0


func panel_top() -> float:
	if bottom_box == null:
		return vp_size().y * 0.6
	var y := bottom_box.global_position.y
	if bottom_box.size.y < 5.0:
		return vp_size().y * 0.6
	return y


func build() -> void:
	ui_layer = CanvasLayer.new()
	ui_layer.layer = 10
	g.add_child(ui_layer)
	root = Control.new()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.theme = Ui.theme
	ui_layer.add_child(root)
	_build_static()


func _full(c: Control) -> void:
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _build_static() -> void:
	confetti_ctl = Ui.Confetti.new()
	_full(confetti_ctl)
	root.add_child(confetti_ctl)

	vlabel_box = Control.new()
	_full(vlabel_box)
	root.add_child(vlabel_box)
	vlabels = []

	header_box = HBoxContainer.new()
	header_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header_box.anchor_right = 1.0
	header_box.offset_left = 36
	header_box.offset_right = -36
	header_box.offset_top = top_inset() + 30.0
	header_box.offset_bottom = top_inset() + 30.0 + 104.0
	header_box.add_theme_constant_override("separation", 18)
	root.add_child(header_box)

	zoom_box = VBoxContainer.new()
	zoom_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	zoom_box.anchor_left = 1.0
	zoom_box.anchor_right = 1.0
	zoom_box.offset_left = -36 - 92
	zoom_box.offset_right = -36
	zoom_box.offset_top = stage_top() + 10.0
	zoom_box.add_theme_constant_override("separation", 18)
	root.add_child(zoom_box)

	win_holder = Control.new()
	_full(win_holder)
	root.add_child(win_holder)

	flash_panel = PanelContainer.new()
	flash_panel.visible = false
	flash_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash_panel.add_theme_stylebox_override("panel", _flash_style())
	flash_label = Ui.lbl("", 40, "on_fg", true, HORIZONTAL_ALIGNMENT_CENTER)
	flash_panel.add_child(flash_label)
	flash_panel.anchor_left = 0.5
	flash_panel.anchor_right = 0.5
	flash_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	flash_panel.offset_top = stage_top() + 20.0
	root.add_child(flash_panel)

	count_label = Ui.lbl("3", 396, "accent", true, HORIZONTAL_ALIGNMENT_CENTER)
	count_label.visible = false
	count_label.anchor_left = 0.0
	count_label.anchor_right = 1.0
	count_label.anchor_top = 0.25
	count_label.anchor_bottom = 0.25
	count_label.grow_vertical = Control.GROW_DIRECTION_BOTH
	root.add_child(count_label)

	bottom_box = VBoxContainer.new()
	bottom_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom_box.anchor_left = 0.0
	bottom_box.anchor_right = 1.0
	bottom_box.anchor_top = 1.0
	bottom_box.anchor_bottom = 1.0
	bottom_box.offset_left = 0
	bottom_box.offset_right = 0
	bottom_box.offset_bottom = -(bottom_inset() + 24.0)
	bottom_box.grow_vertical = Control.GROW_DIRECTION_BEGIN
	bottom_box.add_theme_constant_override("separation", 14)
	root.add_child(bottom_box)

	hint_label = Ui.lbl("", 35, "muted", false, HORIZONTAL_ALIGNMENT_CENTER, true)
	var hm := MarginContainer.new()
	hm.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hm.add_theme_constant_override("margin_left", 60)
	hm.add_theme_constant_override("margin_right", 60)
	hm.add_child(hint_label)
	bottom_box.add_child(hm)

	scroll = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.mouse_filter = Control.MOUSE_FILTER_PASS
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom_box.add_child(scroll)
	var inner := MarginContainer.new()
	inner.mouse_filter = Control.MOUSE_FILTER_PASS
	inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inner.add_theme_constant_override("margin_left", 36)
	inner.add_theme_constant_override("margin_right", 36)
	scroll.add_child(inner)
	panel_box = VBoxContainer.new()
	panel_box.mouse_filter = Control.MOUSE_FILTER_PASS
	panel_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel_box.add_theme_constant_override("separation", 22)
	inner.add_child(panel_box)

	lang_holder = Control.new()
	_full(lang_holder)
	root.add_child(lang_holder)
	modal_holder = Control.new()
	_full(modal_holder)
	root.add_child(modal_holder)


func _flash_style() -> StyleBoxFlat:
	var s := Ui.sb(Ui.c("fg"), Ui.c("fg"), 40, 0)
	s.content_margin_left = 44
	s.content_margin_right = 44
	s.content_margin_top = 22
	s.content_margin_bottom = 22
	return s


func rebuild() -> void:
	var open := modal_name
	for c in root.get_children():
		root.remove_child(c)
		c.queue_free()
	modal_name = ""
	lang_open = false
	_build_static()
	render_all()
	g.set_hint(g.hint_key, g.hint_vars)
	if g.win_state != null:
		show_win()
	if open != "":
		open_modal(open)


func render_all() -> void:
	render_header()
	render_zoom()
	render_panel()


# ---------------------------------------------------------------- başlık

func tag_text() -> String:
	var def: Dictionary = g.puz.def
	var name := Loc.pname(def)
	match g.screen_name:
		"game":
			if g.S_mode == "time":
				var rec := Store.num_get("time-" + g.S_puz)
				return "%s · %s %s" % [name, Loc.t("tag.record"), str(int(rec)) if rec > 0.0 else "—"]
			if g.S_mode == "daily":
				var db := Store.daily_best(g.S_puz)
				return "%s · %s · %s %s" % [name, Loc.t("tag.daily"), Loc.t("tag.best"), Ui.fmt_ms(db) if db > 0.0 else "—"]
			if g.S_mode == "watch":
				var wb := Store.num_get("watch-" + g.S_puz)
				return "%s · %s %s" % [name, Loc.t("tag.best"), Ui.fmt_ms(wb) if wb > 0.0 else "—"]
			if g.S_mode == "level":
				return "%s · %s" % [name, Loc.t("tag.level", {"n": g.S_level})]
			return name
		"levels":
			return "%s · %s" % [name, Loc.t("mode.levels")]
		"learn":
			return "%s · %s" % [name, Loc.t("learn.tag")]
		"colors":
			return Loc.t("tag.colors")
	return ""


func _clear(node: Node) -> void:
	for c in node.get_children():
		node.remove_child(c)
		c.queue_free()


func render_header() -> void:
	_clear(header_box)
	var sc: String = g.screen_name
	if sc != "home":
		var back := Ui.IconBtn.new("back", 104)
		back.pressed.connect(func() -> void:
			g.snd.click()
			g.on_back())
		header_box.add_child(back)
	var title := Ui.lbl(Loc.t("app.title"), 62, "fg", true)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	header_box.add_child(title)
	var tag := Ui.mono(tag_text(), 32, "muted", HORIZONTAL_ALIGNMENT_RIGHT)
	tag.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if tag.text != "":
		header_box.add_child(tag)
	if sc == "home" or sc == "menu":
		var gear := Ui.IconBtn.new("gear", 104)
		gear.pressed.connect(func() -> void:
			g.snd.click()
			open_modal("settings"))
		header_box.add_child(gear)
		var globe := Ui.IconBtn.new("globe", 104)
		globe.pressed.connect(func() -> void:
			g.snd.click()
			toggle_lang_sheet())
		header_box.add_child(globe)
	var sb := Ui.IconBtn.new("sound" if g.snd.on else "sound_off", 104)
	sb.pressed.connect(func() -> void: g.toggle_sound())
	header_box.add_child(sb)


func render_zoom() -> void:
	_clear(zoom_box)
	var p := Ui.IconBtn.new("plus", 92)
	p.pressed.connect(func() -> void: g.zoom_by(1.25))
	zoom_box.add_child(p)
	var m := Ui.IconBtn.new("minus", 92)
	m.pressed.connect(func() -> void: g.zoom_by(0.8))
	zoom_box.add_child(m)
	if g.screen_name == "game" or g.screen_name == "learn":
		var o := Ui.IconBtn.new("orbit", 92)
		o.active = g.orbit_only
		o.pressed.connect(func() -> void: g.toggle_orbit())
		zoom_box.add_child(o)


# ---------------------------------------------------------------- küçük yapı taşları

func section_title(text: String) -> Label:
	return Ui.lbl(text.to_upper(), 32, "muted", true)


func _stat_box(label_text: String, value_text: String, align: int, num_size: int = 104) -> VBoxContainer:
	var vb := VBoxContainer.new()
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_theme_constant_override("separation", 0)
	vb.add_child(Ui.lbl(label_text.to_upper(), 32, "muted", true, align))
	vb.add_child(Ui.mono(value_text, num_size, "fg", align))
	return vb


class ModeIcon extends Control:
	var kind := "std"

	func _init(k: String = "std") -> void:
		kind = k
		custom_minimum_size = Vector2(70, 70)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var u := size.x / 32.0
		var col := Ui.c("accent")
		var w := 2.2 * u
		match kind:
			"learn":
				draw_polyline(_p([Vector2(4, 7), Vector2(10, 5.5), Vector2(16, 8), Vector2(16, 27), Vector2(10, 25.5), Vector2(4, 27), Vector2(4, 7)], u), col, w, true)
				draw_polyline(_p([Vector2(16, 8), Vector2(22, 5.5), Vector2(28, 7), Vector2(28, 27), Vector2(22, 25.5), Vector2(16, 27)], u), col, w, true)
			"std":
				draw_polyline(_p([Vector2(16, 4), Vector2(27, 10), Vector2(27, 22), Vector2(16, 28), Vector2(5, 22), Vector2(5, 10), Vector2(16, 4)], u), col, w, true)
				draw_polyline(_p([Vector2(5, 10), Vector2(16, 16), Vector2(27, 10)], u), col, w, true)
				draw_line(Vector2(16, 16) * u, Vector2(16, 28) * u, col, w, true)
			"daily":
				draw_rect(Rect2(Vector2(4, 6) * u, Vector2(24, 22) * u), col, false, w)
				draw_line(Vector2(4, 12) * u, Vector2(28, 12) * u, col, w, true)
				draw_line(Vector2(10, 3) * u, Vector2(10, 8) * u, col, w, true)
				draw_line(Vector2(22, 3) * u, Vector2(22, 8) * u, col, w, true)
				draw_circle(Vector2(16, 20) * u, 2.2 * u, col)
			"levels":
				var pts := PackedVector2Array()
				for k in range(11):
					var a := -PI / 2.0 + k * PI / 5.0
					var rr := 12.5 if k % 2 == 0 else 5.4
					pts.append(Vector2(16 + cos(a) * rr, 17 + sin(a) * rr) * u)
				draw_polyline(pts, col, w, true)
			"clock":
				draw_arc(Vector2(16, 17) * u, 10 * u, 0.0, TAU, 32, col, w, true)
				draw_polyline(_p([Vector2(16, 11), Vector2(16, 17), Vector2(20, 20)], u), col, w, true)
				draw_line(Vector2(12, 4) * u, Vector2(20, 4) * u, col, w, true)
			"watch":
				draw_arc(Vector2(16, 18) * u, 10 * u, 0.0, TAU, 32, col, w, true)
				draw_line(Vector2(16, 18) * u, Vector2(21, 13) * u, col, w, true)
				draw_line(Vector2(13, 4) * u, Vector2(19, 4) * u, col, w, true)
				draw_line(Vector2(16, 4) * u, Vector2(16, 8) * u, col, w, true)

	func _p(pts: Array, u: float) -> PackedVector2Array:
		var out := PackedVector2Array()
		for p in pts:
			out.append(p * u)
		return out


func mode_card(mode: String, title: String, desc: String, meta: String, cb: Callable) -> Control:
	var hb := HBoxContainer.new()
	hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hb.add_theme_constant_override("separation", 30)
	var ic := ModeIcon.new(MODE_ICONS[mode])
	ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hb.add_child(ic)
	var vb := VBoxContainer.new()
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.add_theme_constant_override("separation", 4)
	vb.add_child(Ui.lbl(title, 45, "fg", true))
	vb.add_child(Ui.lbl(desc, 36, "muted", false, HORIZONTAL_ALIGNMENT_LEFT, true))
	hb.add_child(vb)
	if meta != "":
		var m := Ui.mono(meta, 34, "muted", HORIZONTAL_ALIGNMENT_RIGHT)
		m.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		hb.add_child(m)
	var card := Ui.Card.new(hb, 26)
	card.pressed.connect(func() -> void:
		g.snd.click()
		cb.call())
	return card


# ---------------------------------------------------------------- panel

func render_panel() -> void:
	v1 = null
	task_label = null
	chip_nodes = []
	_clear(panel_box)
	var sc: String = g.screen_name
	match sc:
		"home":
			_panel_home()
		"menu":
			_panel_menu()
		"levels":
			_panel_levels()
		"game":
			_panel_game()
		"learn":
			if g.L == null:
				_panel_lesson_list()
			else:
				_panel_lesson()
		"colors":
			_panel_colors()
	fit_frames = 4
	if last_screen != sc:
		last_screen = sc
		panel_box.modulate.a = 0.0
		var tw := g.create_tween()
		tw.tween_property(panel_box, "modulate:a", 1.0, 0.25)


func fit_panel() -> void:
	var need := panel_box.get_combined_minimum_size().y + 16.0
	var maxh := vp_size().y * (0.62 if g.screen_name != "game" else 0.4)
	scroll.custom_minimum_size.y = minf(need, maxh)


func _panel_home() -> void:
	var sp := Control.new()
	sp.custom_minimum_size = Vector2(0, 10)
	sp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel_box.add_child(sp)
	var t := Ui.lbl(Loc.t("app.title"), 121, "fg", true, HORIZONTAL_ALIGNMENT_CENTER)
	panel_box.add_child(t)
	panel_box.add_child(Ui.lbl(Loc.t("app.sub"), 40, "muted", false, HORIZONTAL_ALIGNMENT_CENTER, true))
	var play := Ui.btn(Loc.t("btn.play"), "primary", 133, 56)
	play.pressed.connect(func() -> void:
		g.snd.click()
		g.go_modes())
	panel_box.add_child(play)
	var col := Ui.btn(Loc.t("btn.colors"), "normal", 125, 50)
	col.pressed.connect(func() -> void:
		g.snd.click()
		g.open_colors())
	panel_box.add_child(col)
	var n := Store.streak_now()
	var pb := Ui.btn(Loc.t("home.progressStreak", {"n": n}) if n > 0 else Loc.t("home.progress"), "normal", 109, 43)
	pb.pressed.connect(func() -> void:
		g.snd.click()
		open_modal("progress"))
	panel_box.add_child(pb)


func _panel_menu() -> void:
	panel_box.add_child(section_title(Loc.t("menu.puzzle")))
	var grid := GridContainer.new()
	grid.columns = 4
	grid.mouse_filter = Control.MOUSE_FILTER_PASS
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 16)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel_box.add_child(grid)
	var segs := [["c2", "2×2", "seg.c2"], ["c3", "3×3", "seg.c3"], ["c4", "4×4", "seg.c4"], ["c5", "5×5", "seg.c5"],
		["p", "", "seg.p"], ["sk", "", "seg.sk"], ["tw", "", ""], ["fl", "", ""]]
	for s in segs:
		var id: String = s[0]
		var active := id == g.S_puz
		var name: String = s[1] if s[1] != "" else Loc.pname(Puzzle.get_def(id))
		var sub: String = Loc.t(s[2]) if s[2] != "" else ("2×2×3" if id == "tw" else "3×3×1")
		var vb := VBoxContainer.new()
		vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vb.add_theme_constant_override("separation", 2)
		var tc := "on_fg" if active else "fg"
		var sc2 := "on_fg" if active else "muted"
		var l1 := Ui.lbl(name, 37, tc, true, HORIZONTAL_ALIGNMENT_CENTER)
		l1.clip_text = true
		var l2 := Ui.lbl(sub, 30, sc2, false, HORIZONTAL_ALIGNMENT_CENTER)
		l2.clip_text = true
		vb.add_child(l1)
		vb.add_child(l2)
		var card := Ui.Card.new(vb, 18, active)
		card.custom_minimum_size = Vector2(0, 108)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.pressed.connect(func() -> void:
			g.snd.click()
			g.select_puzzle(id))
		grid.add_child(card)
	panel_box.add_child(section_title(Loc.t("mode.time") if g.sub_open else Loc.t("menu.mode")))
	var p: String = g.S_puz
	if not g.sub_open:
		var lessons := Loc.lessons_for(p)
		var done: Array = Store.learn_done(p)
		panel_box.add_child(mode_card("learn", Loc.t("mode.learn"), Loc.t("mode.learn.d"), "%d/%d" % [done.size(), lessons.size()] if lessons.size() > 0 else "", func() -> void: g.enter_mode("learn")))
		panel_box.add_child(mode_card("std", Loc.t("mode.std"), Loc.t("mode.std.d"), "", func() -> void: g.enter_mode("std")))
		var db := Store.daily_best(p)
		var dmeta := ""
		if db > 0.0:
			dmeta = Loc.t("meta.best", {"n": Ui.fmt_ms(db)})
		elif Store.streak_now() > 0:
			dmeta = Loc.t("meta.streak", {"n": Store.streak_now()})
		panel_box.add_child(mode_card("daily", Loc.t("mode.daily"), Loc.t("mode.daily.d"), dmeta, func() -> void: g.enter_mode("daily")))
		var stt := Store.total_stars(p)
		panel_box.add_child(mode_card("levels", Loc.t("mode.levels"), Loc.t("mode.levels.d"), Loc.t("meta.stars", {"n": stt}) if stt > 0 else "", func() -> void: g.open_levels()))
		panel_box.add_child(mode_card("timeMenu", Loc.t("mode.time"), Loc.t("mode.time.d"), "›", func() -> void: g.set_sub(true)))
	else:
		var rt := Store.num_get("time-" + p)
		panel_box.add_child(mode_card("time", Loc.t("mode.count"), Loc.t("mode.count.d"), Loc.t("meta.record", {"n": int(rt)}) if rt > 0.0 else "", func() -> void: g.enter_mode("time")))
		var w := Store.num_get("watch-" + p)
		panel_box.add_child(mode_card("watch", Loc.t("mode.watch"), Loc.t("mode.watch.d"), Loc.t("meta.best", {"n": Ui.fmt_ms(w)}) if w > 0.0 else "", func() -> void: g.enter_mode("watch")))


func _panel_levels() -> void:
	panel_box.add_child(section_title(Loc.t("levels.title")))
	var stars := Store.lv_stars(g.S_puz)
	var grid := GridContainer.new()
	grid.columns = 5
	grid.mouse_filter = Control.MOUSE_FILTER_PASS
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 16)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel_box.add_child(grid)
	for n in range(1, Store.LV_COUNT + 1):
		var open: bool = n == 1 or int(stars[n - 2]) > 0
		var vb := VBoxContainer.new()
		vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vb.add_theme_constant_override("separation", 6)
		vb.alignment = BoxContainer.ALIGNMENT_CENTER
		var num := Ui.lbl(str(n), 52, "fg" if open else "muted", true, HORIZONTAL_ALIGNMENT_CENTER)
		vb.add_child(num)
		if open:
			var sc := Ui.StarsCtl.new(int(stars[n - 1]), 32.0)
			sc.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			vb.add_child(sc)
		else:
			vb.add_child(Ui.lbl("—", 34, "muted", false, HORIZONTAL_ALIGNMENT_CENTER))
		var card := Ui.Card.new(vb, 16, false, open and int(stars[n - 1]) == 0 and n > 1)
		card.custom_minimum_size = Vector2(0, 136)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if open:
			card.pressed.connect(func() -> void:
				g.snd.click()
				g.enter_level(n))
		else:
			card.modulate.a = 0.5
		grid.add_child(card)
	panel_box.add_child(Ui.lbl(Loc.t("levels.note"), 36, "muted", false, HORIZONTAL_ALIGNMENT_CENTER, true))


func _panel_game() -> void:
	var mode: String = g.S_mode
	var gs: String = g.gs
	var race := g.is_race(mode)
	var lvl := mode == "level"
	var scr_busy := gs == "scrambling" or gs == "countdown"
	if race or lvl:
		var row := HBoxContainer.new()
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var l1_text := ""
		var v1_text := ""
		var l3_text := Loc.t("stat.moves")
		var v3_text := str(g.moves)
		if mode == "time":
			l1_text = Loc.t("stat.left")
			v1_text = Ui.fmt_ms(g.remaining)
		elif g.is_watch_like(mode):
			l1_text = Loc.t("stat.time")
			var ms := 0.0
			if gs == "solved":
				ms = g.elapsed_final
			elif gs == "playing":
				ms = g.now_ms() - g.t0
			v1_text = Ui.fmt_ms(ms)
		else:
			l1_text = Loc.t("stat.moves")
			v1_text = str(g.moves)
			l3_text = Loc.t("stat.par")
			v3_text = str(g.level_par)
		var b1 := _stat_box(l1_text, v1_text, HORIZONTAL_ALIGNMENT_LEFT, 90)
		b1.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		v1 = b1.get_child(1) as Label
		if mode == "time" and gs == "playing" and g.remaining < 10000.0:
			v1.add_theme_color_override("font_color", Ui.c("accent"))
		row.add_child(b1)
		if mode == "time":
			var b2 := _stat_box(Loc.t("stat.solved"), str(g.solved_count), HORIZONTAL_ALIGNMENT_CENTER, 90)
			b2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(b2)
		var b3 := _stat_box(l3_text, v3_text, HORIZONTAL_ALIGNMENT_RIGHT, 90)
		b3.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(b3)
		panel_box.add_child(row)
	var acts := HBoxContainer.new()
	acts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	acts.add_theme_constant_override("separation", 20)
	var a1 := Ui.btn(Loc.t("btn.undo"), "normal", 117, 43)
	a1.disabled = not g.can_undo() or scr_busy
	a1.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	a1.pressed.connect(func() -> void:
		g.snd.click()
		g.undo())
	acts.add_child(a1)
	var a2 := Ui.btn(Loc.t("btn.restart") if race else Loc.t("btn.hint"), "normal", 117, 43)
	a2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if race:
		a2.disabled = scr_busy or gs == "idle"
	else:
		a2.disabled = not g.can_hint()
	a2.pressed.connect(func() -> void:
		g.snd.click()
		g.on_action2())
	acts.add_child(a2)
	var a3_key := "btn.shuffle"
	if mode == "time":
		a3_key = "btn.finish" if gs == "playing" else "btn.start"
	elif g.is_watch_like(mode):
		a3_key = "btn.giveup" if (gs == "ready" or gs == "playing") else "btn.start"
	elif lvl:
		a3_key = "btn.restart"
	var a3 := Ui.btn(Loc.t(a3_key), "primary", 117, 44)
	a3.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	a3.size_flags_stretch_ratio = 1.4
	a3.disabled = scr_busy or (race and gs == "over")
	a3.pressed.connect(func() -> void:
		g.snd.click()
		g.on_action3())
	acts.add_child(a3)
	panel_box.add_child(acts)


func _panel_lesson_list() -> void:
	var p: String = g.S_puz
	var lessons := Loc.lessons_for(p)
	var done: Array = Store.learn_done(p)
	if lessons.is_empty():
		panel_box.add_child(Ui.lbl(Loc.t("learn.noLessons", {"name": Loc.pname(g.puz.def)}), 38, "muted", false, HORIZONTAL_ALIGNMENT_CENTER, true))
	for i in range(lessons.size()):
		var hb := HBoxContainer.new()
		hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var vb := VBoxContainer.new()
		vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		vb.add_theme_constant_override("separation", 2)
		vb.add_child(Ui.lbl(Loc.lesson_title(p, i), 48, "fg", true))
		vb.add_child(Ui.lbl(Loc.lesson_sum(p, i), 34, "muted", false, HORIZONTAL_ALIGNMENT_LEFT, true))
		hb.add_child(vb)
		var is_done: bool = done.has(lessons[i]["id"])
		if is_done:
			var m := Ui.lbl(Loc.t("learn.done"), 34, "good", true, HORIZONTAL_ALIGNMENT_RIGHT)
			m.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			hb.add_child(m)
		var card := Ui.Card.new(hb, 26, false, false)
		var idx := i
		card.pressed.connect(func() -> void:
			g.snd.click()
			g.learn_open_lesson(idx))
		panel_box.add_child(card)


func _panel_lesson() -> void:
	var p: String = g.S_puz
	var li: int = g.L["i"]
	var k: int = g.L["k"]
	var ls: Dictionary = Loc.lessons_for(p)[li]
	var st: Dictionary = ls["steps"][k]
	var head := HBoxContainer.new()
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tl := Ui.lbl(Loc.lesson_title(p, li), 54, "fg", true)
	tl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(tl)
	head.add_child(Ui.mono(Loc.t("learn.step", {"k": k + 1, "n": ls["steps"].size()}), 32, "muted", HORIZONTAL_ALIGNMENT_RIGHT))
	panel_box.add_child(head)
	panel_box.add_child(Ui.lbl(Loc.step_text(p, li, k), 40, "fg", false, HORIZONTAL_ALIGNMENT_LEFT, true))
	if st["alg"] != "":
		var flow := HFlowContainer.new()
		flow.mouse_filter = Control.MOUSE_FILTER_IGNORE
		flow.add_theme_constant_override("h_separation", 14)
		flow.add_theme_constant_override("v_separation", 14)
		for tk in str(st["alg"]).split(" ", false):
			flow.add_child(_chip(tk))
		if int(st.get("reps", 1)) > 1:
			flow.add_child(_chip("×" + str(int(st["reps"]))))
		panel_box.add_child(flow)
	task_label = Ui.lbl("", 37, "muted", true, HORIZONTAL_ALIGNMENT_LEFT, true)
	panel_box.add_child(task_label)
	set_task_text()
	if st["alg"] != "":
		var r := HBoxContainer.new()
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		r.add_theme_constant_override("separation", 20)
		var show := Ui.btn(Loc.t("learn.show"), "normal", 101, 41)
		show.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		show.pressed.connect(func() -> void:
			g.snd.click()
			g.play_demo())
		r.add_child(show)
		var tr := Ui.btn(Loc.t("learn.try"), "normal", 101, 41)
		tr.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tr.pressed.connect(func() -> void:
			g.snd.click()
			g.try_it())
		r.add_child(tr)
		panel_box.add_child(r)
	var nav := HBoxContainer.new()
	nav.mouse_filter = Control.MOUSE_FILTER_IGNORE
	nav.add_theme_constant_override("separation", 20)
	var prev := Ui.btn(Loc.t("learn.prev"), "normal", 101, 41)
	prev.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	prev.disabled = k == 0
	prev.pressed.connect(func() -> void:
		g.snd.click()
		g.learn_prev())
	nav.add_child(prev)
	var nxt := Ui.btn(Loc.t("btn.finish") if k == ls["steps"].size() - 1 else Loc.t("learn.next"), "primary", 101, 41)
	nxt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nxt.pressed.connect(func() -> void:
		g.snd.click()
		g.learn_next())
	nav.add_child(nxt)
	panel_box.add_child(nav)
	update_chips()


func _chip(text: String) -> PanelContainer:
	var pc := PanelContainer.new()
	pc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var m := MarginContainer.new()
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	m.add_theme_constant_override("margin_left", 26)
	m.add_theme_constant_override("margin_right", 26)
	m.add_theme_constant_override("margin_top", 12)
	m.add_theme_constant_override("margin_bottom", 12)
	m.add_child(Ui.mono(text, 42, "fg"))
	pc.add_child(m)
	chip_nodes.append(pc)
	return pc


func update_chips() -> void:
	if g.L == null:
		return
	var lit: int = g.L["lit"]
	var base: int = g.L["base"]
	for i in range(chip_nodes.size()):
		var pc: PanelContainer = chip_nodes[i]
		var on := false
		var past := false
		if i < base:
			on = lit >= 0 and i == lit % base
			past = lit >= 0 and i < lit % base
		var bg := Ui.c("panel")
		var bd := Ui.c("line")
		if on:
			bg = Ui.c("accent_soft")
			bd = Ui.c("accent")
		pc.add_theme_stylebox_override("panel", Ui.sb(bg, bd, 24, 2))
		pc.modulate.a = 0.45 if past else 1.0


func set_task_text() -> void:
	if task_label == null:
		return
	var ts: Dictionary = g.task_state
	task_label.text = Loc.t(ts["k"], ts["v"]) if ts["k"] != "" else ""
	task_label.add_theme_color_override("font_color", Ui.c("good") if ts["ok"] else Ui.c("muted"))


func _panel_colors() -> void:
	var fam := HBoxContainer.new()
	fam.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fam.add_theme_constant_override("separation", 16)
	for f in [["cube", Loc.t("fam.cube")], ["pyra", Loc.t("pz.p")]]:
		var fid: String = f[0]
		var b := Ui.btn(f[1], "on" if g.color_fam == fid else "normal", 94, 43)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(func() -> void:
			g.snd.click()
			g.set_color_fam(fid))
		fam.add_child(b)
	panel_box.add_child(fam)
	var chips := HFlowContainer.new()
	chips.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chips.add_theme_constant_override("h_separation", 14)
	chips.add_theme_constant_override("v_separation", 14)
	var names: Array = []
	if g.color_fam == "cube":
		for i in range(6):
			names.append([i, Loc.t("face." + Puzzle.KEYS[i])])
	else:
		for j in range(4):
			names.append([j, Loc.t("face.n", {"n": "ABCD".substr(j, 1)})])
	var order := [2, 3, 4, 5, 0, 1] if g.color_fam == "cube" else [0, 1, 2, 3]
	for oi in order:
		var item: Array = names[oi]
		var idx: int = item[0]
		var active: bool = idx == g.color_sel
		var hb := HBoxContainer.new()
		hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hb.add_theme_constant_override("separation", 14)
		var dot := ColorRect.new()
		dot.custom_minimum_size = Vector2(44, 44)
		dot.color = Puzzle.face_colors[idx] if g.color_fam == "cube" else Puzzle.pyra_colors[idx]
		dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hb.add_child(dot)
		hb.add_child(Ui.lbl(item[1], 35, "on_fg" if active else "fg", true))
		var card := Ui.Card.new(hb, 22, active)
		card.pressed.connect(func() -> void:
			g.snd.click()
			g.select_face(idx))
		chips.add_child(card)
	panel_box.add_child(chips)
	var sw := GridContainer.new()
	sw.columns = 8
	sw.mouse_filter = Control.MOUSE_FILTER_PASS
	sw.add_theme_constant_override("h_separation", 12)
	sw.add_theme_constant_override("v_separation", 12)
	sw.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var cur := g.cur_color().to_html(false)
	for col in _swatches():
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(0, 84)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var is_cur: bool = (col as Color).to_html(false) == cur
		var norm := Ui.sb(col, Ui.c("fg") if is_cur else Ui.c("line"), 22, 6 if is_cur else 2)
		b.add_theme_stylebox_override("normal", norm)
		b.add_theme_stylebox_override("hover", norm)
		b.add_theme_stylebox_override("pressed", norm)
		b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		var cc: Color = col
		b.pressed.connect(func() -> void:
			g.snd.click()
			g.set_color(cc))
		sw.add_child(b)
	panel_box.add_child(sw)
	var custom := Ui.btn(Loc.t("colors.custom"), "normal", 94, 41)
	custom.pressed.connect(func() -> void:
		g.snd.click()
		open_modal("picker"))
	panel_box.add_child(custom)
	var r := HBoxContainer.new()
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.add_theme_constant_override("separation", 20)
	var reset := Ui.btn(Loc.t("colors.reset"), "normal", 101, 39)
	reset.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	reset.pressed.connect(func() -> void:
		g.snd.click()
		g.reset_colors())
	r.add_child(reset)
	var done := Ui.btn(Loc.t("colors.done"), "primary", 101, 43)
	done.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	done.pressed.connect(func() -> void:
		g.snd.click()
		g.go_home())
	r.add_child(done)
	panel_box.add_child(r)


func _swatches() -> Array:
	var list: Array = [Color.WHITE, Color("f5f5ef"), Color("b8bdc6"), Color("6c7480"), Color("262a31"), Color("8a5a35"), Color("ffb3c7"), Color("7fe0c8")]
	for l in [0.48, 0.68]:
		for h in range(0, 360, 30):
			var c := Color.from_hsv(float(h) / 360.0, 0.78, 0.55 + (l - 0.48) * 1.1)
			list.append(c)
	return list


# ---------------------------------------------------------------- üst katman: ipucu, mesaj, sayaç, konfeti

func set_hint_text(s: String) -> void:
	if hint_label != null:
		hint_label.text = s
		hint_label.visible = s != ""
		fit_frames = 4


func flash(s: String) -> void:
	flash_label.text = s
	flash_panel.visible = true
	flash_panel.modulate.a = 1.0
	flash_id += 1
	var id := flash_id
	g.get_tree().create_timer(1.4).timeout.connect(func() -> void:
		if id == flash_id:
			flash_panel.visible = false)


func show_count(s: String) -> void:
	count_label.text = s
	count_label.visible = true
	count_label.pivot_offset = Vector2(vp_size().x / 2.0, 200)
	count_label.scale = Vector2(1.5, 1.5)
	count_label.modulate.a = 0.0
	var tw := g.create_tween()
	tw.set_parallel(true)
	tw.tween_property(count_label, "scale", Vector2.ONE, 0.3)
	tw.tween_property(count_label, "modulate:a", 1.0, 0.2)


func hide_count() -> void:
	if count_label != null:
		count_label.visible = false


func set_timer(text: String, warn: bool) -> void:
	if v1 != null and is_instance_valid(v1):
		v1.text = text
		v1.add_theme_color_override("font_color", Ui.c("accent") if warn else Ui.c("fg"))


func confetti(n: int) -> void:
	var vp := vp_size()
	var origin := Vector2(vp.x / 2.0, (stage_top() + panel_top()) * 0.45)
	confetti_ctl.burst(n, origin, vp.x / 360.0)


# ---------------------------------------------------------------- her kare

func update_overlay() -> void:
	if fit_frames > 0:
		fit_frames -= 1
		fit_panel()
	# köşe harfleri (piramit ve skewb dersleri)
	var want: bool = g.screen_name == "learn" and g.L != null and not g.puz.vpos.is_empty()
	if not want:
		if not vlabels.is_empty():
			_clear(vlabel_box)
			vlabels = []
		return
	if vlabels.size() != g.puz.vpos.size():
		_clear(vlabel_box)
		vlabels = []
		for i in range(g.puz.vpos.size()):
			var vl := Ui.VLabel.new("ABCD".substr(i, 1))
			vlabel_box.add_child(vl)
			vlabels.append(vl)
	for i in range(vlabels.size()):
		var v: Vector3 = g.puz.vpos[i]
		var sp: Vector2 = g.camera.unproject_position(g.puz.to_global(v * 1.14))
		var wz: float = g.puz.to_global(v).z
		var vl: Ui.VLabel = vlabels[i]
		vl.position = sp - vl.size / 2.0
		vl.alpha = 1.0 if wz > -0.3 else 0.3
		vl.queue_redraw()


# ---------------------------------------------------------------- kazanma kartı

func hide_win() -> void:
	if win_holder != null:
		_clear(win_holder)


func show_win() -> void:
	_clear(win_holder)
	var ws: Dictionary = g.win_state
	if ws == null:
		return
	var vb := VBoxContainer.new()
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_theme_constant_override("separation", 26)
	var head := HBoxContainer.new()
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_theme_constant_override("separation", 24)
	var title := Ui.lbl(Loc.t(ws["title"]), 74, "fg", true)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	if ws["badge"]:
		var bp := PanelContainer.new()
		bp.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bp.add_theme_stylebox_override("panel", Ui.sb(Ui.c("accent_soft"), Ui.c("accent"), 30, 2))
		var bm := MarginContainer.new()
		bm.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bm.add_theme_constant_override("margin_left", 26)
		bm.add_theme_constant_override("margin_right", 26)
		bm.add_theme_constant_override("margin_top", 10)
		bm.add_theme_constant_override("margin_bottom", 10)
		bm.add_child(Ui.lbl(Loc.t("win.record"), 36, "accent", true))
		bp.add_child(bm)
		bp.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		head.add_child(bp)
	vb.add_child(head)
	var stats := HBoxContainer.new()
	stats.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stats.add_theme_constant_override("separation", 30)
	for s in ws["stats"]:
		var sbx := VBoxContainer.new()
		sbx.mouse_filter = Control.MOUSE_FILTER_IGNORE
		sbx.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		sbx.add_child(Ui.lbl(Loc.t(s[0]).to_upper(), 30, "muted", true))
		if s[1] is Dictionary:
			var sc := Ui.StarsCtl.new(int(s[1]["stars"]), 44.0)
			sbx.add_child(sc)
		else:
			sbx.add_child(Ui.mono(str(s[1]), 52, "fg"))
		stats.add_child(sbx)
	if ws["stats"].size() > 0:
		vb.add_child(stats)
	var btns := HBoxContainer.new()
	btns.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btns.add_theme_constant_override("separation", 20)
	var menu := Ui.btn(Loc.t("win.menu"), "normal", 109, 44)
	menu.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	menu.pressed.connect(func() -> void:
		g.snd.click()
		g.win_menu())
	btns.add_child(menu)
	var again := Ui.btn(Loc.t(ws["again"]), "primary", 109, 44)
	again.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	again.size_flags_stretch_ratio = 1.3
	again.pressed.connect(func() -> void:
		g.snd.click()
		g.win_again())
	btns.add_child(again)
	vb.add_child(btns)
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", Ui.sb(Ui.c("panel"), Ui.c("line"), 44, 2))
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	var m := MarginContainer.new()
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		m.add_theme_constant_override(side, 44)
	m.add_child(vb)
	card.add_child(m)
	card.anchor_left = 0.0
	card.anchor_right = 1.0
	card.offset_left = 60
	card.offset_right = -60
	card.offset_top = stage_top() + 30.0
	win_holder.add_child(card)
	card.modulate.a = 0.0
	var tw := g.create_tween()
	tw.tween_property(card, "modulate:a", 1.0, 0.3)


# ---------------------------------------------------------------- pencereler

func modal_open() -> bool:
	return modal_name != "" or lang_open


func close_modals_silent() -> void:
	_clear(modal_holder)
	_clear(lang_holder)
	modal_name = ""
	lang_open = false


func close_modals() -> void:
	var was := modal_name
	close_modals_silent()
	if was == "howto":
		g.howto_done()
	if was == "picker":
		g._save_colors()
		render_all()


func refresh_modals() -> void:
	if modal_name != "":
		open_modal(modal_name)
	if lang_open:
		toggle_lang_sheet()
		toggle_lang_sheet()


func open_modal(name: String) -> void:
	_clear(modal_holder)
	_clear(lang_holder)
	lang_open = false
	modal_name = name
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.5)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.gui_input.connect(func(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and (ev as InputEventMouseButton).pressed:
			close_modals())
	modal_holder.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	modal_holder.add_child(center)
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", Ui.sb(Ui.c("panel"), Ui.c("line"), 48, 2))
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	card.custom_minimum_size = Vector2(minf(vp_size().x - 100.0, 960.0), 0)
	var m := MarginContainer.new()
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		m.add_theme_constant_override(side, 48)
	var vb := VBoxContainer.new()
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_theme_constant_override("separation", 28)
	m.add_child(vb)
	card.add_child(m)
	center.add_child(card)
	match name:
		"settings":
			_modal_settings(vb)
		"progress":
			_modal_progress(vb)
		"howto":
			_modal_howto(vb)
		"picker":
			_modal_picker(vb)


func _close_btn(text_key: String = "btn.close") -> Button:
	var b := Ui.btn(Loc.t(text_key), "primary", 109, 44)
	b.pressed.connect(func() -> void:
		g.snd.click()
		close_modals())
	return b


func _modal_settings(vb: VBoxContainer) -> void:
	vb.add_child(Ui.lbl(Loc.t("set.title"), 62, "fg", true))
	vb.add_child(section_title(Loc.t("set.theme")))
	var seg := HBoxContainer.new()
	seg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	seg.add_theme_constant_override("separation", 14)
	for o in [["auto", "set.themeAuto"], ["light", "set.themeLight"], ["dark", "set.themeDark"]]:
		var oid: String = o[0]
		var b := Ui.btn(Loc.t(o[1]), "on" if g.theme_pref == oid else "normal", 94, 39)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(func() -> void:
			g.snd.click()
			g.set_theme_pref(oid))
		seg.add_child(b)
	vb.add_child(seg)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var hl := Ui.lbl(Loc.t("set.haptics"), 42, "fg", true)
	hl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(hl)
	var hb := Ui.btn(Loc.t("set.on") if g.haptics_on else Loc.t("set.off"), "on" if g.haptics_on else "normal", 94, 39)
	hb.custom_minimum_size.x = 260
	hb.pressed.connect(func() -> void:
		g.snd.click()
		g.set_haptics(not g.haptics_on)
		open_modal("settings"))
	row.add_child(hb)
	vb.add_child(row)
	var how := Ui.btn(Loc.t("set.howto"), "normal", 109, 43)
	how.pressed.connect(func() -> void:
		g.snd.click()
		howto_idx = 0
		open_modal("howto"))
	vb.add_child(how)
	vb.add_child(_close_btn())


func _kv(label_text: String, value_text: String) -> Control:
	var hb := HBoxContainer.new()
	hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l := Ui.lbl(label_text, 37, "muted")
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(l)
	hb.add_child(Ui.lbl(value_text, 42, "fg", true, HORIZONTAL_ALIGNMENT_RIGHT))
	return hb


func _modal_progress(vb: VBoxContainer) -> void:
	vb.add_child(Ui.lbl(Loc.t("prog.title"), 62, "fg", true))
	vb.add_child(_kv(Loc.t("prog.streak"), str(Store.streak_now())))
	vb.add_child(_kv(Loc.t("prog.solves"), str(Store.stats()["solves"])))
	var done := 0
	var total := 0
	var st := 0
	var mx := 0
	var day_done := 0
	for id in Puzzle.ORDER:
		var ls := Loc.lessons_for(id)
		total += ls.size()
		var dn: Array = Store.learn_done(id)
		for l in ls:
			if dn.has(l["id"]):
				done += 1
		st += Store.total_stars(id)
		mx += Store.LV_COUNT * 3
		if Store.daily_best(id) > 0.0:
			day_done += 1
	vb.add_child(_kv(Loc.t("prog.lessons"), "%d/%d" % [done, total]))
	vb.add_child(_kv(Loc.t("prog.stars"), "%d/%d" % [st, mx]))
	vb.add_child(_kv(Loc.t("prog.daily"), (Loc.t("prog.dailyDone") + " · " + str(day_done)) if day_done > 0 else Loc.t("prog.dailyNot")))
	var any := false
	for id in Puzzle.ORDER:
		if Store.num_get("watch-" + id) > 0.0:
			any = true
	if any:
		vb.add_child(section_title(Loc.t("prog.best")))
		for id in Puzzle.ORDER:
			var v := Store.num_get("watch-" + id)
			if v > 0.0:
				vb.add_child(_kv(Loc.pname(Puzzle.get_def(id)), Ui.fmt_ms(v)))
	vb.add_child(_close_btn())


func _modal_howto(vb: VBoxContainer) -> void:
	vb.add_child(Ui.HowArt.new(howto_idx))
	vb.add_child(Ui.lbl(Loc.t("howto.%d.t" % (howto_idx + 1)), 59, "fg", true, HORIZONTAL_ALIGNMENT_CENTER, true))
	vb.add_child(Ui.lbl(Loc.t("howto.%d.d" % (howto_idx + 1)), 37, "muted", false, HORIZONTAL_ALIGNMENT_CENTER, true))
	var dots := HBoxContainer.new()
	dots.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dots.alignment = BoxContainer.ALIGNMENT_CENTER
	dots.add_theme_constant_override("separation", 18)
	for i in range(3):
		var d := ColorRect.new()
		d.custom_minimum_size = Vector2(22, 22)
		d.color = Ui.c("accent") if i == howto_idx else Ui.c("line")
		d.mouse_filter = Control.MOUSE_FILTER_IGNORE
		dots.add_child(d)
	vb.add_child(dots)
	var r := HBoxContainer.new()
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.add_theme_constant_override("separation", 20)
	if howto_idx < 2:
		var skip := Ui.btn(Loc.t("howto.skip"), "normal", 109, 43)
		skip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		skip.pressed.connect(func() -> void:
			g.snd.click()
			close_modals())
		r.add_child(skip)
	var nxt := Ui.btn(Loc.t("howto.next") if howto_idx < 2 else Loc.t("howto.start"), "primary", 109, 44)
	nxt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nxt.pressed.connect(func() -> void:
		g.snd.click()
		if howto_idx < 2:
			howto_idx += 1
			open_modal("howto")
		else:
			close_modals())
	r.add_child(nxt)
	vb.add_child(r)


func _modal_picker(vb: VBoxContainer) -> void:
	vb.add_child(Ui.lbl(Loc.t("colors.custom"), 57, "fg", true))
	var preview := ColorRect.new()
	preview.custom_minimum_size = Vector2(0, 110)
	preview.color = g.cur_color()
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(preview)
	var hsv := [g.cur_color().h, g.cur_color().s, g.cur_color().v]
	var names := ["H", "S", "V"]
	for i in range(3):
		var row := HBoxContainer.new()
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_theme_constant_override("separation", 20)
		row.add_child(Ui.lbl(names[i], 42, "muted", true))
		var sl := HSlider.new()
		sl.min_value = 0.0
		sl.max_value = 1.0
		sl.step = 0.005
		sl.value = hsv[i]
		sl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		sl.custom_minimum_size = Vector2(0, 90)
		_style_slider(sl)
		var idx := i
		sl.value_changed.connect(func(v: float) -> void:
			hsv[idx] = v
			var c := Color.from_hsv(hsv[0], hsv[1], hsv[2])
			preview.color = c
			g.set_color_live(c))
		row.add_child(sl)
		vb.add_child(row)
	vb.add_child(_close_btn("colors.done"))


func _style_slider(sl: HSlider) -> void:
	var track := Ui.sb(Ui.c("line"), Ui.c("line"), 12, 0)
	track.content_margin_top = 12
	track.content_margin_bottom = 12
	sl.add_theme_stylebox_override("slider", track)
	var fill := Ui.sb(Ui.c("accent"), Ui.c("accent"), 12, 0)
	fill.content_margin_top = 12
	fill.content_margin_bottom = 12
	sl.add_theme_stylebox_override("grabber_area", fill)
	sl.add_theme_stylebox_override("grabber_area_highlight", fill)
	var img := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for y in range(64):
		for x in range(64):
			if Vector2(x - 31.5, y - 31.5).length() < 30.0:
				img.set_pixel(x, y, Ui.c("fg"))
	var tex := ImageTexture.create_from_image(img)
	sl.add_theme_icon_override("grabber", tex)
	sl.add_theme_icon_override("grabber_highlight", tex)
	sl.add_theme_icon_override("grabber_disabled", tex)


func toggle_lang_sheet() -> void:
	_clear(lang_holder)
	if lang_open:
		lang_open = false
		return
	_clear(modal_holder)
	modal_name = ""
	lang_open = true
	var dim := Control.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.gui_input.connect(func(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and (ev as InputEventMouseButton).pressed:
			close_modals_silent())
	lang_holder.add_child(dim)
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", Ui.sb(Ui.c("panel"), Ui.c("line"), 40, 2))
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	card.anchor_left = 1.0
	card.anchor_right = 1.0
	card.offset_left = -36 - 520
	card.offset_right = -36
	card.offset_top = top_inset() + 30.0 + 104.0 + 14.0
	var m := MarginContainer.new()
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		m.add_theme_constant_override(side, 16)
	var vb := VBoxContainer.new()
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_theme_constant_override("separation", 8)
	for l in Loc.langs:
		var lid: String = l[0]
		var b := Ui.btn(l[1], "on" if lid == Loc.lang else "normal", 86, 41)
		b.pressed.connect(func() -> void:
			g.snd.click()
			close_modals_silent()
			g.set_lang(lid))
		vb.add_child(b)
	m.add_child(vb)
	card.add_child(m)
	lang_holder.add_child(card)
