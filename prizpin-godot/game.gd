class_name Game
extends Node3D
## Prizpin: ana oyun. Sahne, kamera, dokunma, oyun modları, dersler ve renkler burada.
## Arayüz (menüler, düğmeler) screens.gd içinde çizilir.

const ZMIN := 0.55
const ZMAX := 2.6
const THRESH := 0.35
const GAIN := 1.25

var puz: Puzzle
var camera: Camera3D
var rig: Node3D
var world_root: Node3D
var env: Environment
var bg_rect: TextureRect
var snd: Snd
var scr: Screens

# kamera
var zoom := 1.0
var zoom_target := 1.0
var base_dist := 10.0
var stage_bottom := 1500.0
var orbit_only := false
var spin := false
var intro = null

# oyun durumu
var S_puz := "c3"
var S_mode := ""
var S_level := 1
var gs := "home"             # home | menu | idle | countdown | scrambling | ready | playing | solved | over | learn | colors
var screen_name := "home"    # home | menu | levels | game | learn | colors
var run_id := 0
var moves := 0
var history: Array = []
var t0 := 0.0
var remaining := 0.0
var solved_count := 0
var elapsed_final := 0.0
var hint_count := 0
var last_scramble: Array = []
var level_par := 0
var sub_open := false
var last_warn_sec := -1
var hint_key := ""
var hint_vars: Dictionary = {}
var win_state = null
var how_seen := false
var theme_pref := "auto"
var haptics_on := true

# dersler
var L = null
var task_state := {"k": "", "ok": false, "v": {}}

# renkler
var color_fam := "cube"
var color_sel := 2

# dokunma
var dragging := false
var d_mode := ""             # orbit | pending | layer | none
var d_press := Vector2.ZERO
var d_last := Vector2.ZERO
var d_hit: Dictionary = {}
var d_u := Vector2.RIGHT
var d_len := 100.0
var d_samples: Array = []
var d_past := false
var touches := {}
var pinch_d0 := 1.0
var pinch_z0 := 1.0


func _ready() -> void:
	randomize()
	get_tree().set_quit_on_go_back(false)
	Loc.load_data()
	Store.load_all()
	Ui.init_once()
	var sl: String = str(Store.get_val("lang", ""))
	Loc.lang = sl if Loc.has_lang(sl) else Loc.detect()
	theme_pref = str(Store.get_val("theme", "light"))
	haptics_on = bool(Store.get_val("haptics", true))
	how_seen = false
	_load_colors()
	_apply_theme_flag()
	_build_world()
	snd = Snd.new()
	add_child(snd)
	snd.on = bool(Store.get_val("sound", true))
	puz.step_played.connect(snd.tick)
	scr = Screens.new(self)
	scr.build()
	get_viewport().size_changed.connect(func() -> void: scr.render_all())
	go_home()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		# Android geri tuşu: önce açık pencereyi kapat, sonra bir önceki ekrana dön, ana ekranda oyundan çık.
		if scr != null and scr.modal_open():
			scr.close_modals()
		elif screen_name == "home":
			get_tree().quit()
		else:
			on_back()
		return
	if what == NOTIFICATION_APPLICATION_FOCUS_IN and theme_pref == "auto" and scr != null:
		var was := Ui.dark
		_apply_theme_flag()
		if was != Ui.dark:
			_theme_changed()


func now_ms() -> float:
	return float(Time.get_ticks_msec())


# ---------------------------------------------------------------- sahne

func _build_world() -> void:
	env = Environment.new()
	env.background_mode = Environment.BG_CANVAS
	env.background_canvas_max_layer = -1
	env.background_color = Ui.c("bg")
	# Arka plan: web'deki gibi ortası (küpün arkası) daha açık, kenarlara doğru gri.
	var bg_layer := CanvasLayer.new()
	bg_layer.layer = -1
	add_child(bg_layer)
	bg_rect = TextureRect.new()
	bg_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg_rect.stretch_mode = TextureRect.STRETCH_SCALE
	bg_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg_layer.add_child(bg_rect)
	_paint_bg()
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(1, 1, 1)
	env.ambient_light_energy = 0.6
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, -30, 0)
	sun.light_energy = 0.85
	add_child(sun)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(35, 140, 0)
	fill.light_energy = 0.22
	add_child(fill)

	camera = Camera3D.new()
	camera.keep_aspect = Camera3D.KEEP_WIDTH
	camera.fov = 31.0
	camera.position = Vector3(0, 0, 10)
	add_child(camera)
	camera.current = true

	rig = Node3D.new()
	add_child(rig)
	world_root = Node3D.new()
	world_root.basis = Basis(Vector3.UP, -0.72) * Basis(Vector3.RIGHT, 0.52)
	rig.add_child(world_root)
	puz = Puzzle.new()
	world_root.add_child(puz)


func _paint_bg() -> void:
	if bg_rect == null:
		return
	var gr := Gradient.new()
	gr.set_color(0, Ui.c("bg2"))
	gr.set_color(1, Ui.c("bg"))
	gr.set_offset(1, 1.0)
	var tex := GradientTexture2D.new()
	tex.gradient = gr
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.38)
	tex.fill_to = Vector2(1.08, 0.38)
	tex.width = 256
	tex.height = 512
	bg_rect.texture = tex


func _apply_theme_flag() -> void:
	if theme_pref == "dark":
		Ui.dark = true
	elif theme_pref == "light":
		Ui.dark = false
	else:
		Ui.dark = DisplayServer.is_dark_mode_supported() and DisplayServer.is_dark_mode()
	if env != null:
		env.background_color = Ui.c("bg")


func _theme_changed() -> void:
	if env != null:
		env.background_color = Ui.c("bg")
	_paint_bg()
	scr.rebuild()


func set_theme_pref(v: String) -> void:
	theme_pref = v
	Store.set_val("theme", v)
	_apply_theme_flag()
	_theme_changed()


func set_haptics(v: bool) -> void:
	haptics_on = v
	Store.set_val("haptics", v)
	buzz(25)


func buzz(ms: int) -> void:
	if haptics_on:
		Input.vibrate_handheld(ms)


func load_puzzle(id: String) -> void:
	puz.load_puzzle(id)
	d_mode = "none"
	dragging = false


# ---------------------------------------------------------------- kare döngüsü

func _process(delta: float) -> void:
	var now := now_ms()
	var dt := minf(64.0, delta * 1000.0)
	puz.step(now)
	zoom += (zoom_target - zoom) * (1.0 - exp(-dt / 70.0))
	var target_bottom: float = scr.panel_top()
	stage_bottom += (target_bottom - stage_bottom) * (1.0 - exp(-dt / 90.0))
	_update_camera()
	if intro != null:
		var ip := clampf((now - float(intro["t0"])) / float(intro["dur"]), 0.0, 1.0)
		var ie := 1.0 - pow(1.0 - ip, 3.0)
		if intro["spin"]:
			_spin_y((ie - float(intro["prev"])) * TAU)
		intro["prev"] = ie
		if ip >= 1.0:
			var cb: Callable = intro["done"]
			intro = null
			if not cb.is_null():
				cb.call()
	elif spin and not dragging and touches.size() < 2:
		_spin_y(dt * 0.0003)
	_tick(now, dt)
	scr.update_overlay()


func _update_camera() -> void:
	var vp := get_viewport().get_visible_rect().size
	var top: float = scr.stage_top()
	var sh := maxf(260.0, stage_bottom - top)
	var tan_h := tan(deg_to_rad(camera.fov) * 0.5)
	var ang_w := atan(tan_h)
	var ang_h := atan(tan_h * sh / vp.x)
	base_dist = puz.fit_r / sin(minf(ang_w, ang_h))
	var dist := base_dist / zoom
	camera.position = Vector3(0, 0, dist)
	var upp := 2.0 * dist * tan_h / vp.x
	var cy := (top + stage_bottom) * 0.5
	rig.position = Vector3(0.0, (vp.y * 0.5 - cy) * upp, 0.0)


func _spin_y(angle: float) -> void:
	world_root.basis = (Basis(Vector3.UP, angle) * world_root.basis).orthonormalized()


func _sf() -> float:
	return get_viewport().get_visible_rect().size.x / 360.0


func play_intro(do_spin: bool, done: Callable = Callable()) -> void:
	zoom = 0.4 if do_spin else 0.8
	zoom_target = 1.1 if do_spin else 1.0
	intro = {"t0": now_ms(), "dur": 950.0 if do_spin else 1.0, "prev": 0.0, "spin": do_spin, "done": done}
	if do_spin:
		get_tree().create_timer(0.48).timeout.connect(func() -> void: zoom_target = 1.0)
		snd.whoosh()


func zoom_by(f: float) -> void:
	zoom_target = clampf(zoom_target * f, ZMIN, ZMAX)


# ---------------------------------------------------------------- dokunma ve sürükleme

func _input(event: InputEvent) -> void:
	_handle_touch(event)
	if not dragging or touches.size() >= 2:
		return
	if event is InputEventMouseMotion:
		_drag_move((event as InputEventMouseMotion).position)
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and not mb.pressed:
			_drag_end()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			if touches.size() < 2 and not scr.modal_open():
				_drag_start(mb.position)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			zoom_by(1.1)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			zoom_by(1.0 / 1.1)


func _handle_touch(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		if st.pressed:
			touches[st.index] = st.position
			if touches.size() == 2:
				if dragging:
					if d_mode == "layer":
						_drag_end()
					else:
						dragging = false
						d_mode = "none"
				pinch_d0 = maxf(10.0, _touch_distance())
				pinch_z0 = zoom_target
		else:
			touches.erase(st.index)
	elif event is InputEventScreenDrag:
		var sd := event as InputEventScreenDrag
		if touches.has(sd.index):
			touches[sd.index] = sd.position
		if touches.size() >= 2:
			var d := maxf(10.0, _touch_distance())
			zoom_target = clampf(pinch_z0 * d / pinch_d0, ZMIN, ZMAX)
			zoom = zoom_target


func _touch_distance() -> float:
	var keys := touches.keys()
	var a: Vector2 = touches[keys[0]]
	var b: Vector2 = touches[keys[1]]
	return a.distance_to(b)


func can_play() -> bool:
	if puz.busy():
		return false
	if S_mode == "learn":
		return screen_name == "learn"
	return screen_name == "game" and (gs == "idle" or gs == "ready" or gs == "playing")


func _drag_start(pos: Vector2) -> void:
	dragging = true
	d_press = pos
	d_last = pos
	d_samples.clear()
	d_samples.append({"t": now_ms(), "p": pos})
	d_past = false
	d_hit = _pick(pos)
	if d_hit.is_empty() or orbit_only:
		d_mode = "orbit"
	elif can_play():
		d_mode = "pending"
	elif puz.busy():
		d_mode = "none"
	else:
		d_mode = "orbit"


func _drag_move(pos: Vector2) -> void:
	if d_mode == "orbit":
		_orbit(pos - d_last)
	elif d_mode == "pending":
		var d := pos - d_press
		var limit := 8.0 * _sf()
		if d.length_squared() > limit * limit:
			var ch := _choose_layer(d)
			if not ch.is_empty() and not puz.busy():
				d_mode = "layer"
				d_u = ch["u"]
				d_len = ch["len"]
				puz.turn = puz.begin_turn(ch["axis"], ch["layer"])
			else:
				d_mode = "none" if not ch.is_empty() else "orbit"
	if d_mode == "layer" and puz.turn != null:
		var dd := pos - d_press
		var big_l := maxf(d_len, 45.0 * _sf())
		var stp := puz.step_of(puz.turn["axis"])
		# Yarım tur (Kule, Floppy) ve 120° (Piramit, Skewb) katmanlar da çeyrek tur kadar kaydırmayla dönsün.
		var th := dd.dot(d_u) / (big_l * big_l) * GAIN * maxf(1.0, stp / (PI / 2.0))
		var mx := puz.max_of(puz.turn["axis"])
		th = clampf(th, -mx * stp, mx * stp)
		puz.set_angle(puz.turn, th)
		var past_now: bool = absf(th) / stp > THRESH
		if past_now != d_past:
			d_past = past_now
			snd.thresh()
		var now := now_ms()
		d_samples.append({"t": now, "p": pos})
		while d_samples.size() > 2 and now - float(d_samples[0]["t"]) > 110.0:
			d_samples.pop_front()
	d_last = pos


func _drag_end() -> void:
	dragging = false
	var mode := d_mode
	d_mode = "none"
	if mode == "orbit":
		if d_hit.has("piece") and d_last.distance_to(d_press) < 6.0 * _sf():
			on_tap(d_hit)
		return
	if mode != "layer" or puz.turn == null:
		return
	var t: Dictionary = puz.turn
	var th: float = t["angle"]
	var step := puz.step_of(t["axis"])
	var ar := absf(th) / step
	var vs := 0.0
	if d_samples.size() > 1:
		var a: Dictionary = d_samples[0]
		var b: Dictionary = d_samples[d_samples.size() - 1]
		var dt := maxf(1.0, float(b["t"]) - float(a["t"]))
		vs = ((b["p"] as Vector2) - (a["p"] as Vector2)).dot(d_u) / d_len / dt / _sf()
	var flick := absf(vs) > 0.7
	var turns := 0
	if ar > THRESH or (flick and ar > 0.08):
		var sgn := 1
		if flick:
			if vs < 0.0:
				sgn = -1
		elif th < 0.0:
			sgn = -1
		turns = sgn * clampi(maxi(1, roundi(ar)), 1, puz.max_of(t["axis"]))
	var target := float(turns) * step
	var dur := 90.0 + 170.0 * minf(1.0, absf(target - th) / step)
	if turns != 0:
		on_move({"axis": t["axis"], "layer": t["layer"], "turns": turns})
	puz.animate_turn(t, target, dur, func() -> void:
		if turns != 0:
			snd.settle()
			buzz(8)
			after_move(), false)


func _orbit(d: Vector2) -> void:
	var k := 0.011 / _sf()
	var rot := Basis(Vector3.UP, d.x * k) * Basis(Vector3.RIGHT, d.y * k)
	world_root.basis = (rot * world_root.basis).orthonormalized()


func _to_screen(local_p: Vector3) -> Vector2:
	return camera.unproject_position(puz.to_global(local_p))


func _pick(pos: Vector2) -> Dictionary:
	var inv := puz.global_transform.affine_inverse()
	var o := inv * camera.project_ray_origin(pos)
	var d := inv.basis * camera.project_ray_normal(pos)
	return puz.pick(o, d)


## Sürükleme yönüne en çok uyan katmanı seçer. Döndürür: {axis, layer, u, len} ya da boş.
func _choose_layer(d: Vector2) -> Dictionary:
	var p: Vector3 = d_hit["point"]
	var sp := _to_screen(p)
	var best := {}
	var best_score := 0.3
	for cand in puz.candidates(d_hit):
		var axis_vec: Vector3 = puz.axes[cand["axis"]]
		var tangent := axis_vec.cross(p) * 0.05
		var s2 := _to_screen(p + tangent)
		var u := (s2 - sp) / 0.05
		var ulen := u.length()
		if ulen < 8.0 * _sf():
			continue
		var score := absf(d.dot(u)) / (ulen * d.length())
		if score > best_score:
			best_score = score
			best = {"axis": cand["axis"], "layer": cand["layer"], "u": u, "len": ulen}
	return best


# ---------------------------------------------------------------- yardımcı: ipucu, mesaj

func set_hint(k: String = "", v: Dictionary = {}) -> void:
	hint_key = k
	hint_vars = v
	scr.set_hint_text(Loc.t(k, v) if k != "" else "")


func set_press_hint() -> void:
	if S_mode == "time":
		set_hint("hint.pressTime", {"a": puz.def["base"], "b": puz.def["max"]})
	else:
		set_hint("hint.press")


func flash(k: String, v: Dictionary = {}) -> void:
	scr.flash(Loc.t(k, v))


func is_race(m: String) -> bool:
	return m == "time" or m == "watch" or m == "daily"


func is_watch_like(m: String) -> bool:
	return m == "watch" or m == "daily"


func sync_ui() -> void:
	scr.render_all()


# ---------------------------------------------------------------- ekranlar

func show_screen(name: String) -> void:
	screen_name = name
	spin = name == "home" or name == "menu" or name == "levels"
	Puzzle.apply_colors(name == "learn")
	snd.set_race(name == "game" and is_race(S_mode))
	win_state = null
	scr.close_modals_silent()
	scr.hide_win()
	scr.hide_count()
	scr.render_all()


func to_screen2(name: String) -> void:
	sub_open = false
	L = null
	run_id += 1
	gs = name
	S_mode = ""
	moves = 0
	history = []
	load_puzzle(S_puz)
	set_hint("")
	show_screen(name)


func go_home() -> void:
	to_screen2("home")
	play_intro(true)


func go_modes() -> void:
	to_screen2("menu")
	play_intro(false)


func on_back() -> void:
	if screen_name == "menu" and sub_open:
		set_sub(false)
	elif screen_name == "menu" or screen_name == "colors":
		go_home()
	elif screen_name == "learn" and L != null:
		learn_open_list()
	elif screen_name == "game" and S_mode == "level":
		open_levels()
	else:
		go_modes()


func set_sub(open: bool) -> void:
	sub_open = open
	scr.render_all()


func select_puzzle(id: String) -> void:
	S_puz = id
	load_puzzle(id)
	scr.render_all()
	play_intro(false)


func reset_run() -> void:
	run_id += 1
	last_scramble = []
	moves = 0
	history = []
	t0 = 0.0
	solved_count = 0
	elapsed_final = 0.0
	hint_count = 0
	remaining = float(puz.def["time"]) * 1000.0
	win_state = null
	scr.hide_win()
	scr.hide_count()


func enter_mode(mode: String) -> void:
	S_mode = mode
	load_puzzle(S_puz)
	reset_run()
	if mode == "learn":
		gs = "learn"
		L = null
		show_screen("learn")
		learn_open_list()
		play_intro(true)
		return
	gs = "idle"
	show_screen("game")
	set_hint("hint.preparing")
	if mode == "level":
		level_par = Store.lv_par(S_level)
	sync_ui()
	var id := run_id
	play_intro(true, func() -> void:
		if id != run_id:
			return
		if is_race(mode):
			gs = "idle"
			set_press_hint()
			sync_ui()
		elif mode == "level":
			start_level()
		else:
			start_std())
	maybe_show_howto()


# ---------------------------------------------------------------- hamleler

func on_move(m: Dictionary) -> void:
	if gs == "ready":
		gs = "playing"
		t0 = now_ms()
	history.append(m)
	moves += 1
	set_hint("")
	if S_mode == "learn":
		learn_on_move()
	else:
		sync_ui()


func after_move() -> void:
	if S_mode == "learn":
		learn_after()
		return
	if gs == "playing" and puz.solved():
		on_solved()
	else:
		sync_ui()


func _tick(now: float, dt: float) -> void:
	if gs != "playing":
		return
	if S_mode == "time":
		remaining -= dt
		if remaining <= 0.0:
			remaining = 0.0
			game_over()
			return
		scr.set_timer(Ui.fmt_ms(remaining), remaining < 10000.0)
		if remaining < 10000.0:
			var sec := int(ceil(remaining / 1000.0))
			if sec != last_warn_sec:
				last_warn_sec = sec
				snd.warn(sec)
	elif is_watch_like(S_mode):
		scr.set_timer(Ui.fmt_ms(now - t0), false)


func can_undo() -> bool:
	return not history.is_empty() and not puz.busy() and gs != "scrambling" and gs != "countdown" and gs != "solved" and gs != "over"


func undo() -> void:
	if history.is_empty() or puz.busy():
		return
	if not (gs == "idle" or gs == "ready" or gs == "playing" or S_mode == "learn"):
		return
	var m: Dictionary = history.pop_back()
	moves = maxi(0, moves - 1)
	puz.enqueue({"axis": m["axis"], "layer": m["layer"], "turns": -int(m["turns"])}, 160.0, func() -> void: after_move())
	if S_mode != "learn":
		sync_ui()


func play_scramble(list: Array, rng: Rng, dur: float, done: Callable) -> void:
	var id := run_id
	last_scramble = last_scramble + list
	gs = "scrambling"
	set_hint("hint.shuffling")
	for i in range(list.size()):
		var cb := Callable()
		if i == list.size() - 1:
			cb = func() -> void:
				if id != run_id:
					return
				if puz.solved():
					play_scramble(puz.scramble_list(3, rng), rng, dur, done)
					return
				done.call()
		puz.enqueue(list[i], dur, cb)
	sync_ui()


func start_scramble(count: int, rng: Rng, dur: float, done: Callable) -> void:
	play_scramble(puz.scramble_list(count, rng), rng, dur, done)


func reset_puzzle() -> void:
	load_puzzle(S_puz)
	reset_run()
	gs = "idle"
	if is_race(S_mode):
		set_press_hint()
	else:
		set_hint("hint.idle")
	sync_ui()


func start_std() -> void:
	load_puzzle(S_puz)
	reset_run()
	start_scramble(int(puz.def["std"]), Rng.new(), 60.0, func() -> void:
		gs = "playing"
		set_hint("hint.shuffled")
		sync_ui())


func next_time_scramble() -> void:
	var depth := mini(int(puz.def["max"]), int(puz.def["base"]) + solved_count)
	history = []
	last_scramble = []
	start_scramble(depth, Rng.new(), 70.0, func() -> void:
		gs = "playing"
		set_hint("")
		sync_ui())


func run_countdown(done: Callable) -> void:
	var id := run_id
	for n in [3, 2, 1]:
		if id != run_id:
			return
		snd.beep(false)
		scr.show_count(str(n))
		await get_tree().create_timer(0.7).timeout
	if id != run_id:
		return
	scr.hide_count()
	snd.beep(true)
	done.call()


func start_time() -> void:
	load_puzzle(S_puz)
	reset_run()
	gs = "countdown"
	set_hint("")
	sync_ui()
	run_countdown(next_time_scramble)


func start_watch() -> void:
	load_puzzle(S_puz)
	reset_run()
	gs = "countdown"
	set_hint("")
	sync_ui()
	run_countdown(func() -> void:
		var daily := S_mode == "daily"
		var rng := Rng.new(Store.daily_seed(S_puz)) if daily else Rng.new()
		start_scramble(int(puz.def["std"]), rng, 60.0, func() -> void:
			gs = "ready"
			set_hint("hint.dailyFirst" if daily else "hint.shuffledWatch")
			sync_ui()))


func start_race() -> void:
	if is_watch_like(S_mode):
		start_watch()
	else:
		start_time()


# ---------------------------------------------------------------- sonuçlar

func show_win(title: String, stats: Array, badge: bool, again: String) -> void:
	win_state = {"title": title, "stats": stats, "badge": badge, "again": again}
	scr.show_win()
	set_hint("")


func star_value(n: int) -> Dictionary:
	return {"stars": n}


func on_solved() -> void:
	Store.record_play(true)
	buzz(60)
	if S_mode == "time":
		solved_count += 1
		remaining += float(puz.def["bonus"]) * 1000.0
		flash("flash.bonus", {"n": puz.def["bonus"]})
		snd.plus()
		scr.confetti(40)
		next_time_scramble()
		return
	if S_mode == "watch":
		elapsed_final = now_ms() - t0
		gs = "solved"
		var wbest := Store.num_get("watch-" + S_puz)
		var wrec := wbest <= 0.0 or elapsed_final < wbest
		if wrec:
			Store.set_val("watch-" + S_puz, elapsed_final)
		sync_ui()
		scr.confetti(120 if wrec else 70)
		snd.win(wrec)
		show_win("win.solved", [["stat.time", Ui.fmt_ms(elapsed_final)], ["stat.moves", str(moves)], ["stat.best", Ui.fmt_ms(elapsed_final if wrec else wbest)]], wrec, "win.playAgain")
		return
	if S_mode == "daily":
		elapsed_final = now_ms() - t0
		gs = "solved"
		var dbest := Store.daily_best(S_puz)
		var drec := dbest <= 0.0 or elapsed_final < dbest
		if drec:
			Store.save_daily(S_puz, elapsed_final)
		sync_ui()
		scr.confetti(120 if drec else 70)
		snd.win(drec)
		show_win("win.solved", [["stat.time", Ui.fmt_ms(elapsed_final)], ["stat.moves", str(moves)], ["stat.best", Ui.fmt_ms(elapsed_final if drec else dbest)], ["stat.streak", str(Store.streak_now())]], drec, "win.playAgain")
		return
	if S_mode == "level":
		gs = "solved"
		var stars := Store.stars_for(moves, level_par)
		var old := Store.save_level_stars(S_puz, S_level, stars)
		sync_ui()
		scr.confetti(30 + stars * 30)
		snd.win(stars == 3)
		show_win("win.solved", [["stat.moves", "%d / %d" % [moves, level_par]], ["stat.stars", {"stars": stars}]], stars > old, "win.next" if S_level < Store.LV_COUNT else "win.playAgain")
		return
	gs = "solved"
	sync_ui()
	scr.confetti(80)
	snd.win(false)
	var st: Array = []
	if hint_count > 0:
		st.append(["stat.hints", str(hint_count)])
	show_win("win.solved", st, false, "win.shuffleAgain")


func game_over() -> void:
	gs = "over"
	var best := Store.num_get("time-" + S_puz)
	var rec := solved_count > 0 and (best <= 0.0 or float(solved_count) > best)
	if rec:
		Store.set_val("time-" + S_puz, solved_count)
	sync_ui()
	if rec:
		scr.confetti(90)
		snd.win(true)
	else:
		snd.over()
	show_win("win.timeup", [["stat.solved", str(solved_count)], ["stat.record", str(solved_count if rec else int(best))]], rec, "win.playAgain")


func win_again() -> void:
	scr.hide_win()
	win_state = null
	if S_mode == "level":
		if S_level < Store.LV_COUNT and gs == "solved":
			S_level += 1
		start_level()
	elif is_race(S_mode):
		start_race()
	else:
		start_std()


func win_menu() -> void:
	if S_mode == "level":
		open_levels()
	else:
		go_modes()


func on_action3() -> void:
	if S_mode == "time":
		if gs == "playing":
			game_over()
		else:
			start_time()
	elif is_watch_like(S_mode):
		if gs == "ready" or gs == "playing":
			reset_puzzle()
		else:
			start_watch()
	elif S_mode == "level":
		start_level()
	else:
		start_std()


func on_action2() -> void:
	if is_race(S_mode):
		reset_puzzle()
	else:
		hint()


# ---------------------------------------------------------------- seviyeler

func level_list(n: int) -> Array:
	var rng := Rng.new(Rng.hash_str(S_puz + "#" + str(n)))
	var list := puz.scramble_list(Store.lv_par(n), rng)
	puz.apply_instant(list)
	var g := 0
	while g < 6 and puz.solved():
		var more := puz.random_move(rng, list[list.size() - 1])
		list.append(more)
		puz.apply_instant([more])
		g += 1
	puz.apply_instant(Puzzle.invert_moves(list))
	return list


func start_level() -> void:
	load_puzzle(S_puz)
	reset_run()
	var list := level_list(S_level)
	level_par = list.size()
	play_scramble(list, Rng.new(Rng.hash_str(S_puz + "!" + str(S_level))), 60.0, func() -> void:
		gs = "playing"
		set_hint("hint.levelGoal", {"n": level_par})
		sync_ui())


func open_levels() -> void:
	to_screen2("levels")
	play_intro(false)


func enter_level(n: int) -> void:
	S_level = n
	enter_mode("level")


# ---------------------------------------------------------------- ipucu

func solution_stack() -> Array:
	var st: Array = []
	for m in last_scramble + history:
		if not st.is_empty():
			var top: Dictionary = st[st.size() - 1]
			if top["axis"] == m["axis"] and top["layer"] == m["layer"] and int(top["turns"]) == -int(m["turns"]):
				st.pop_back()
				continue
		st.append(m)
	return st


func can_hint() -> bool:
	return (S_mode == "std" or S_mode == "level") and gs == "playing" and not puz.busy() and not solution_stack().is_empty()


func hint() -> void:
	if not can_hint():
		return
	var st := solution_stack()
	var top: Dictionary = st[st.size() - 1]
	var m := {"axis": top["axis"], "layer": top["layer"], "turns": -int(top["turns"])}
	hint_count += 1
	flash("flash.hint")
	on_move(m)
	puz.enqueue(m, 340.0, func() -> void:
		snd.settle()
		buzz(8)
		after_move())


# ---------------------------------------------------------------- dersler

func lessons_for() -> Array:
	return Loc.lessons_for(S_puz)


func learn_open_list() -> void:
	L = null
	load_puzzle(S_puz)
	set_hint("learn.pickLesson")
	scr.render_all()


func learn_open_lesson(i: int) -> void:
	L = {"i": i, "k": 0, "mode": "idle", "practice": false, "count": 0, "lit": -1, "base": 1}
	learn_step()


func rep_alg(st: Dictionary) -> String:
	var out: Array = []
	for r in range(int(st.get("reps", 1))):
		out.append(st["alg"])
	return " ".join(out)


func prepare(st: Dictionary, scrambled: bool) -> void:
	var ls: Dictionary = lessons_for()[L["i"]]
	run_id += 1
	load_puzzle(S_puz)
	moves = 0
	history = []
	if ls.get("flip", false) and puz.kind == "cube":
		var flip: Array = []
		for l in puz.layers:
			flip.append({"axis": 0, "layer": l, "turns": 2})
		puz.apply_instant(flip)
	if st["alg"] != "" and scrambled:
		puz.apply_instant(Puzzle.invert_moves(puz.parse_alg(rep_alg(st))))
	L["practice"] = st["alg"] != "" and scrambled
	L["count"] = 0


func current_step() -> Dictionary:
	return lessons_for()[L["i"]]["steps"][L["k"]]


func learn_step() -> void:
	var st := current_step()
	prepare(st, true)
	L["lit"] = -1
	L["base"] = maxi(1, str(st["alg"]).split(" ", false).size())
	L["mode"] = "try" if int(st.get("goal", 0)) > 0 else "idle"
	if int(st.get("goal", 0)) > 0:
		set_task("learn.goal", false, {"k": 0, "n": st["goal"]})
	else:
		set_task("", false)
	set_hint("learn.hintAlg" if st["alg"] != "" else "")
	scr.render_all()


func set_task(k: String, ok: bool, v: Dictionary = {}) -> void:
	task_state = {"k": k, "ok": ok, "v": v}
	scr.set_task_text()


func light_chips(idx: int, base: int) -> void:
	L["lit"] = idx
	L["base"] = base
	scr.update_chips()


func play_demo() -> void:
	var st := current_step()
	if st["alg"] == "":
		return
	prepare(st, true)
	L["mode"] = "demo"
	set_task("", false)
	var list := puz.parse_alg(rep_alg(st))
	var base := str(st["alg"]).split(" ", false).size()
	var id := run_id
	light_chips(-1, base)
	for i in range(list.size()):
		puz.enqueue(list[i], 460.0, func() -> void:
			if id != run_id or L == null:
				return
			light_chips(i + 1 if i + 1 < list.size() else -1, base)
			if i == list.size() - 1:
				L["mode"] = "idle"
				set_task("learn.demoDone", true))
	light_chips(0, base)


func try_it() -> void:
	var st := current_step()
	if st["alg"] == "":
		return
	prepare(st, true)
	L["mode"] = "try"
	light_chips(-1, 1)
	set_task("learn.yourTurn", false)
	set_hint("")


func learn_on_move() -> void:
	if L == null:
		return
	var st := current_step()
	var goal := int(st.get("goal", 0))
	if goal > 0 and L["mode"] == "try":
		L["count"] += 1
		if L["count"] >= goal:
			set_task("learn.goalDone", true)
			L["mode"] = "idle"
			flash("learn.great")
			snd.plus()
		else:
			set_task("learn.goal", false, {"k": L["count"], "n": goal})


func learn_after() -> void:
	if L != null and L["practice"] and L["mode"] == "try" and puz.solved():
		set_task("learn.solvedGreat", true)
		L["mode"] = "idle"
		flash("learn.great")
		snd.plus()


func learn_prev() -> void:
	if L != null and L["k"] > 0:
		L["k"] -= 1
		learn_step()


func learn_next() -> void:
	var ls: Dictionary = lessons_for()[L["i"]]
	if L["k"] < ls["steps"].size() - 1:
		L["k"] += 1
		learn_step()
	else:
		Store.mark_lesson(S_puz, ls["id"])
		Store.record_play(false)
		learn_open_list()
		flash("learn.lessonDone")
		snd.win(false)


# ---------------------------------------------------------------- renkler

func _load_colors() -> void:
	var o = Store.get_val("colors")
	if o is Dictionary:
		var cube = o.get("cube")
		if cube is Array and cube.size() == 6:
			for i in range(6):
				Puzzle.face_colors[i] = Color.html(str(cube[i]))
		var pyra = o.get("pyra")
		if pyra is Array and pyra.size() == 4:
			for j in range(4):
				Puzzle.pyra_colors[j] = Color.html(str(pyra[j]))


func _save_colors() -> void:
	var cube: Array = []
	for c in Puzzle.face_colors:
		cube.append((c as Color).to_html(false))
	var pyra: Array = []
	for c in Puzzle.pyra_colors:
		pyra.append((c as Color).to_html(false))
	Store.set_val("colors", {"cube": cube, "pyra": pyra})


func fam_puzzle() -> String:
	if color_fam == "cube":
		return "c3" if Puzzle.get_def(S_puz)["kind"] == "pyra" else S_puz
	return "p"


func cur_color() -> Color:
	return Puzzle.face_colors[color_sel] if color_fam == "cube" else Puzzle.pyra_colors[color_sel]


func open_colors() -> void:
	S_mode = ""
	color_fam = "pyra" if Puzzle.get_def(S_puz)["kind"] == "pyra" else "cube"
	color_sel = 2 if color_fam == "cube" else 0
	run_id += 1
	gs = "colors"
	load_puzzle(fam_puzzle())
	show_screen("colors")
	play_intro(false)
	set_hint("colors.hint")


func set_color_fam(f: String) -> void:
	color_fam = f
	color_sel = 2 if f == "cube" else 0
	load_puzzle(fam_puzzle())
	scr.render_all()


func select_face(idx: int) -> void:
	color_sel = idx
	scr.render_all()
	Puzzle.pulse("cube" if color_fam == "cube" else "pyra", idx, true)
	get_tree().create_timer(0.38).timeout.connect(func() -> void: Puzzle.pulse("cube" if color_fam == "cube" else "pyra", idx, false))


func set_color_live(col: Color) -> void:
	if color_fam == "cube":
		Puzzle.face_colors[color_sel] = col
	else:
		Puzzle.pyra_colors[color_sel] = col
	Puzzle.apply_colors(false)


func set_color(col: Color) -> void:
	set_color_live(col)
	_save_colors()
	scr.render_all()


func reset_colors() -> void:
	if color_fam == "cube":
		Puzzle.face_colors = Puzzle.DEFAULT_FACE.duplicate()
	else:
		Puzzle.pyra_colors = Puzzle.DEFAULT_PYRA.duplicate()
	Puzzle.apply_colors(false)
	_save_colors()
	scr.render_all()
	flash("colors.defaults")


func on_tap(hit: Dictionary) -> void:
	if screen_name != "colors" or not hit.has("piece"):
		return
	var piece: Node3D = hit["piece"]
	snd.tick()
	if puz.kind == "cube":
		if color_fam != "cube":
			return
		for s in piece.get_meta("sticks"):
			var nv: Vector3 = piece.basis * s["local"]
			if nv.dot(hit["normal"]) > 0.5:
				select_face(int(s["color"]))
				return
	else:
		var ci := int(piece.get_meta("color"))
		if color_fam == "pyra" and puz.kind == "pyra":
			select_face(ci)
		elif color_fam == "cube" and puz.kind == "skewb":
			select_face(ci)


# ---------------------------------------------------------------- ayarlar, dil, nasıl oynanır

func set_lang(id: String) -> void:
	if not Loc.has_lang(id):
		return
	Loc.lang = id
	Store.set_val("lang", id)
	set_hint(hint_key, hint_vars)
	scr.render_all()
	scr.refresh_modals()


func toggle_sound() -> void:
	snd.set_on(not snd.on)
	Store.set_val("sound", snd.on)
	flash("flash.sndOn" if snd.on else "flash.sndOff")
	scr.render_header()


func toggle_orbit() -> void:
	orbit_only = not orbit_only
	flash("flash.orbitOn" if orbit_only else "flash.orbitOff")
	scr.render_all()


func maybe_show_howto() -> void:
	if how_seen or bool(Store.get_val("howto", false)):
		return
	scr.open_modal("howto")


func howto_done() -> void:
	how_seen = true
	Store.set_val("howto", true)
