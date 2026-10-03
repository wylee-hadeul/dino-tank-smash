extends Node2D
## 아웃게임 화면: 로비(스테이지 선택), 강화 상점, 스테이지 클리어/게임 오버 결과.
## 버튼은 터치/마우스로 누르거나 키보드(←/→ 이동, J/Enter 선택, Esc 뒤로)로 조작한다.

const Stages = preload("res://scripts/stages.gd")
const Meta = preload("res://scripts/meta.gd")

const COL_PRIMARY := Color("43a047")
const COL_SECOND := Color("455a64")
const COL_SHOP := Color("ef6c00")
const COIN := Color("ffca28")

var main
var font: Font
var box := StyleBoxFlat.new()
var focus := 0
var open_t := 0.0
var toast := ""
var toast_t := 0.0
var code_input := ""


func _ready() -> void:
	font = ThemeDB.fallback_font
	box.set_corner_radius_all(18)
	box.set_border_width_all(4)
	box.shadow_size = 10
	box.shadow_color = Color(0, 0, 0, 0.4)


func open() -> void:
	focus = 0
	open_t = 0.0


func active() -> bool:
	return main.state in [main.State.LOBBY, main.State.SHOP, main.State.STAGE_CLEAR, main.State.GAMEOVER, main.State.MULTI, main.State.JOIN, main.State.ROOM]


func _process(delta: float) -> void:
	open_t += delta
	toast_t -= delta


func show_toast(s: String) -> void:
	toast = s
	toast_t = 1.6


# ------------------------------------------------------------------ 레이아웃

## 화면별 버튼 목록. 그리기와 입력 판정이 같은 레이아웃을 쓴다.
func layout() -> Array:
	var v: Vector2 = main.view
	var out: Array = []
	match main.state:
		main.State.LOBBY:
			var panel := _lobby_panel()
			var cy := panel.get_center().y
			out.append({"id": "prev", "rect": Rect2(panel.position.x - 120, cy - 48, 96, 96), "kind": "arrow", "dir": -1, "enabled": main.selected_stage > 1})
			out.append({"id": "next", "rect": Rect2(panel.end.x + 24, cy - 48, 96, 96), "kind": "arrow", "dir": 1, "enabled": main.selected_stage < main.unlocked})
			out.append({"id": "play", "rect": Rect2(v.x * 0.5 - 340, v.y - 150, 320, 100), "label": "출격!", "col": COL_PRIMARY, "enabled": true})
			out.append({"id": "shop", "rect": Rect2(v.x * 0.5 + 20, v.y - 150, 320, 100), "label": "강화 상점", "col": COL_SHOP, "enabled": true})
			out.append({"id": "multi", "rect": Rect2(24, v.y - 150, 220, 100), "label": "같이 하기", "col": Color("1565c0"), "size": 34, "enabled": true})
		main.State.MULTI:
			var web: bool = main.coop.net.available
			out.append({"id": "back", "rect": Rect2(24, 22, 150, 64), "label": "뒤로", "col": COL_SECOND, "enabled": true})
			out.append({"id": "create", "rect": Rect2(v.x * 0.5 - 340, v.y * 0.5 - 20, 320, 120), "label": "방 만들기", "col": Color("1565c0"), "enabled": web})
			out.append({"id": "join", "rect": Rect2(v.x * 0.5 + 20, v.y * 0.5 - 20, 320, 120), "label": "코드로 참가", "col": Color("6a1b9a"), "enabled": web})
		main.State.JOIN:
			out.append({"id": "back_multi", "rect": Rect2(24, 22, 150, 64), "label": "뒤로", "col": COL_SECOND, "enabled": true})
			var keys := ["1", "2", "3", "4", "5", "6", "7", "8", "9", "지우기", "0", "참가"]
			var kw := 120.0
			var kh := 84.0
			var x0: float = v.x * 0.5 + 40
			for i in keys.size():
				var k: String = keys[i]
				var col := COL_SECOND
				if k == "참가":
					col = COL_PRIMARY
				elif k == "지우기":
					col = Color("b71c1c")
				var en := true
				if k == "참가":
					en = code_input.length() == 4 and main.coop.net.status != "connecting"
				out.append({"id": "key:" + k, "rect": Rect2(x0 + (i % 3) * (kw + 12), 150.0 + (i / 3) * (kh + 12), kw, kh), "label": k, "col": col, "size": 36 if k.length() == 1 else 26, "enabled": en})
		main.State.ROOM:
			out.append({"id": "leave", "rect": Rect2(24, 22, 170, 64), "label": "나가기", "col": Color("b71c1c"), "enabled": true})
			if main.coop.net.is_host:
				out.append({"id": "rs_prev", "rect": Rect2(v.x * 0.5 + 60, v.y - 250, 80, 80), "kind": "arrow", "dir": -1, "enabled": main.coop.room_stage > 1})
				out.append({"id": "rs_next", "rect": Rect2(v.x * 0.5 + 420, v.y - 250, 80, 80), "kind": "arrow", "dir": 1, "enabled": main.coop.room_stage < main.unlocked})
				out.append({"id": "start", "rect": Rect2(v.x * 0.5 + 100, v.y - 140, 360, 100), "label": "시작!", "col": COL_PRIMARY, "enabled": main.coop.net.status == "hosting"})
		main.State.SHOP:
			out.append({"id": "back", "rect": Rect2(24, 22, 150, 64), "label": "뒤로", "col": COL_SECOND, "enabled": true})
			var cols := 4
			var gap := 16.0
			var cw: float = min(270.0, (v.x - 80.0) / cols - gap)
			var ch: float = min(250.0, (v.y - 150.0) / 2.0 - gap)
			var x0: float = (v.x - (cols * cw + (cols - 1) * gap)) * 0.5
			for i in Meta.LIST.size():
				var u: Dictionary = Meta.LIST[i]
				var r := Rect2(x0 + (i % cols) * (cw + gap), 112.0 + (i / cols) * (ch + gap), cw, ch)
				out.append({"id": "buy:" + u.id, "rect": r, "kind": "card", "meta": u, "enabled": true})
		main.State.STAGE_CLEAR, main.State.GAMEOVER when main.mode == "guest":
			pass
		main.State.STAGE_CLEAR when main.mode == "host":
			out.append({"id": "next_stage", "rect": Rect2(v.x * 0.5 - 340, v.y - 140, 320, 96), "label": "다음 스테이지", "col": COL_PRIMARY, "enabled": open_t > 0.8})
			out.append({"id": "to_room", "rect": Rect2(v.x * 0.5 + 20, v.y - 140, 320, 96), "label": "대기실로", "col": COL_SECOND, "enabled": open_t > 0.8})
		main.State.GAMEOVER when main.mode == "host":
			out.append({"id": "retry", "rect": Rect2(v.x * 0.5 - 340, v.y - 140, 320, 96), "label": "재도전", "col": COL_PRIMARY, "enabled": open_t > 1.2})
			out.append({"id": "to_room", "rect": Rect2(v.x * 0.5 + 20, v.y - 140, 320, 96), "label": "대기실로", "col": COL_SECOND, "enabled": open_t > 1.2})
		main.State.STAGE_CLEAR:
			out.append({"id": "next_stage", "rect": Rect2(v.x * 0.5 - 340, v.y - 140, 320, 96), "label": "다음 스테이지", "col": COL_PRIMARY, "enabled": open_t > 0.8})
			out.append({"id": "lobby", "rect": Rect2(v.x * 0.5 + 20, v.y - 140, 320, 96), "label": "로비로", "col": COL_SECOND, "enabled": open_t > 0.8})
		main.State.GAMEOVER:
			var w := 260.0
			var x0: float = v.x * 0.5 - (w * 3 + 40) * 0.5
			out.append({"id": "shop", "rect": Rect2(x0, v.y - 140, w, 96), "label": "강화하러 가기", "col": COL_SHOP, "enabled": open_t > 1.2})
			out.append({"id": "retry", "rect": Rect2(x0 + w + 20, v.y - 140, w, 96), "label": "재도전", "col": COL_PRIMARY, "enabled": open_t > 1.2})
			out.append({"id": "lobby", "rect": Rect2(x0 + (w + 20) * 2, v.y - 140, w, 96), "label": "로비로", "col": COL_SECOND, "enabled": open_t > 1.2})
	return out


func _lobby_panel() -> Rect2:
	var v: Vector2 = main.view
	return Rect2(v.x * 0.5 - 330, 108, 660, v.y - 285)


# ------------------------------------------------------------------ 입력

func _input(event: InputEvent) -> void:
	if not active() or main.is_portrait() or open_t < 0.3:
		return
	var pos = null
	if event is InputEventScreenTouch and event.pressed:
		pos = event.position
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		pos = event.position
	var btns := layout()
	if pos != null:
		for i in btns.size():
			var b: Dictionary = btns[i]
			if b.enabled and b.rect.has_point(pos):
				focus = i
				activate(b.id)
				get_viewport().set_input_as_handled()
				return
		return
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	var key: int = event.physical_keycode
	if main.state == main.State.LOBBY:
		if event.is_action("left"):
			activate("prev")
		elif event.is_action("right"):
			activate("next")
		elif event.is_action("bite") or key == KEY_ENTER or key == KEY_SPACE:
			activate("play")
		elif event.is_action("roar"):
			activate("shop")
		return
	if key == KEY_ESCAPE or key == KEY_BACKSPACE or (main.state == main.State.SHOP and event.is_action("roar")):
		if main.state == main.State.SHOP:
			activate("back")
		return
	var step := 0
	if event.is_action("left"):
		step = -1
	elif event.is_action("right"):
		step = 1
	elif main.state == main.State.SHOP and key == KEY_UP:
		step = -4
	elif main.state == main.State.SHOP and key == KEY_DOWN:
		step = 4
	if step != 0:
		focus = posmod(focus + step, btns.size())
		main.sfx.play("jump", -12.0)
	elif event.is_action("bite") or key == KEY_ENTER or key == KEY_SPACE:
		if focus < btns.size() and btns[focus].enabled:
			activate(btns[focus].id)


func activate(id: String) -> void:
	main.dlog("menu: " + id)
	match id:
		"prev":
			main.change_stage(-1)
			main.sfx.play("jump", -10.0)
		"next":
			main.change_stage(1)
			main.sfx.play("jump", -10.0)
		"play":
			main.start_stage(main.selected_stage)
		"shop":
			main.open_shop()
			main.sfx.play("jump", -8.0)
		"back", "lobby":
			main.goto_lobby()
		"next_stage":
			if main.mode == "host":
				main.coop.host_start(main.stage + 1)
			else:
				main.start_stage(main.stage + 1)
		"retry":
			if main.mode == "host":
				main.coop.host_start(main.stage)
			else:
				main.start_stage(main.stage)
		"multi":
			main.set_state(main.State.MULTI)
		"back_multi":
			main.coop.net.leave()
			main.set_state(main.State.MULTI)
		"create":
			main.coop.create_room()
		"join":
			code_input = ""
			main.set_state(main.State.JOIN)
		"leave":
			main.coop.leave_room()
		"rs_prev":
			main.coop.set_room_stage(main.coop.room_stage - 1)
		"rs_next":
			main.coop.set_room_stage(main.coop.room_stage + 1)
		"start":
			main.coop.host_start(main.coop.room_stage)
		"to_room":
			main.coop.net.send("*", {"t": "room"})
			main.mode = "solo"
			main.goto_lobby()
			main.set_state(main.State.ROOM)
		_:
			if id.begins_with("key:"):
				var k := id.substr(4)
				if k == "지우기":
					code_input = code_input.substr(0, max(code_input.length() - 1, 0))
				elif k == "참가":
					main.coop.join_room(code_input)
				elif code_input.length() < 4:
					code_input += k
			elif id.begins_with("buy:"):
				var mid := id.substr(4)
				var u := Meta.find(mid)
				var lvl: int = main.meta.get(mid, 0)
				if lvl >= u.max:
					show_toast("이미 최대 레벨입니다")
				elif main.buy_meta(mid):
					show_toast("%s Lv%d 강화 완료!" % [u.name, lvl + 1])
				else:
					show_toast("골드가 부족합니다")
					main.sfx.play("hurt", -10.0)


# ------------------------------------------------------------------ 드로잉

func _text(pos: Vector2, s: String, size: int, col: Color, align := HORIZONTAL_ALIGNMENT_CENTER, outline := 8) -> void:
	var w := font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var p := pos
	if align == HORIZONTAL_ALIGNMENT_CENTER:
		p.x -= w * 0.5
	elif align == HORIZONTAL_ALIGNMENT_RIGHT:
		p.x -= w
	if outline > 0:
		draw_string_outline(font, p, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, outline, Color(0, 0, 0, col.a * 0.85))
	draw_string(font, p, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)


func coin(c: Vector2, r: float) -> void:
	draw_circle(c, r, Color("b8860b"))
	draw_circle(c, r * 0.82, COIN)
	draw_arc(c, r * 0.55, 0.0, TAU, 20, Color("e0a800"), r * 0.18)
	draw_circle(c + Vector2(-r * 0.3, -r * 0.3), r * 0.18, Color(1, 1, 1, 0.6))


func _gold_label(right_x: float, y: float, amount: int, size := 34) -> void:
	var s := "%d" % amount
	var w := font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	_text(Vector2(right_x, y), s, size, COIN, HORIZONTAL_ALIGNMENT_RIGHT)
	coin(Vector2(right_x - w - size * 0.6, y - size * 0.33), size * 0.42)


func _panel(r: Rect2, border: Color, bg := Color(0.08, 0.1, 0.09, 0.88)) -> void:
	box.bg_color = bg
	box.border_color = border
	box.draw(get_canvas_item(), r)


func _button(b: Dictionary, focused: bool) -> void:
	var r: Rect2 = b.rect
	var col: Color = b.get("col", COL_SECOND)
	if not b.enabled:
		col = Color(0.3, 0.3, 0.3)
	if focused and b.enabled:
		r = r.grow(3.0 + sin(main.time * 6.0) * 2.0)
	box.bg_color = col
	box.border_color = Color.WHITE if focused and b.enabled else col.darkened(0.35)
	box.draw(get_canvas_item(), r)
	_text(r.get_center() + Vector2(0, 13), b.label, 36, Color(1, 1, 1, 1.0 if b.enabled else 0.4), HORIZONTAL_ALIGNMENT_CENTER, 6)


func _arrow(b: Dictionary) -> void:
	var c: Vector2 = b.rect.get_center()
	var a := 0.9 if b.enabled else 0.2
	draw_circle(c, 46.0, Color(0, 0, 0, 0.45 * a + 0.1))
	draw_arc(c, 46.0, 0.0, TAU, 32, Color(1, 1, 1, a), 4.0)
	var d: float = b.dir
	draw_colored_polygon(PackedVector2Array([c + Vector2(d * 22, 0), c + Vector2(-d * 14, -24), c + Vector2(-d * 14, 24)]), Color(1, 1, 1, a))


func _draw() -> void:
	if not active() or main.is_portrait():
		return
	match main.state:
		main.State.LOBBY:
			_draw_lobby()
		main.State.SHOP:
			_draw_shop()
		main.State.STAGE_CLEAR, main.State.GAMEOVER:
			_draw_result()
			if main.mode == "guest" and open_t > 1.0:
				_text(Vector2(main.view.x * 0.5, main.view.y - 90), "방장의 선택을 기다리는 중...", 30, Color(1, 1, 1, 0.85))
		main.State.MULTI:
			_draw_multi()
		main.State.JOIN:
			_draw_join()
		main.State.ROOM:
			_draw_room()
	var btns := layout()
	for i in btns.size():
		var b: Dictionary = btns[i]
		match b.get("kind", "button"):
			"arrow":
				_arrow(b)
			"card":
				_shop_card(b, i == focus)
			_:
				_button(b, i == focus and main.state != main.State.LOBBY)
	if toast_t > 0.0:
		var a: float = clamp(toast_t * 2.0, 0.0, 1.0)
		_text(Vector2(main.view.x * 0.5, main.view.y - 26), toast, 30, Color(1, 1, 0.6, a))


func _draw_multi() -> void:
	var v: Vector2 = main.view
	draw_rect(Rect2(Vector2.ZERO, v), Color(0, 0, 0, 0.55))
	_text(Vector2(v.x * 0.5, 150), "같이 하기", 64, Color("90caf9"), HORIZONTAL_ALIGNMENT_CENTER, 12)
	_text(Vector2(v.x * 0.5, 210), "친구와 방 코드로 최대 4명까지 함께 싸워요!", 28, Color(1, 1, 1, 0.85), HORIZONTAL_ALIGNMENT_CENTER, 5)
	if not main.coop.net.available:
		_text(Vector2(v.x * 0.5, v.y - 80), "같이 하기는 웹(브라우저)에서만 가능합니다", 24, Color(1, 1, 1, 0.6), HORIZONTAL_ALIGNMENT_CENTER, 0)


func _draw_join() -> void:
	var v: Vector2 = main.view
	draw_rect(Rect2(Vector2.ZERO, v), Color(0, 0, 0, 0.6))
	_text(Vector2(v.x * 0.5 - 300, 150), "방 코드 입력", 54, Color("e0e0ff"), HORIZONTAL_ALIGNMENT_CENTER, 10)
	_text(Vector2(v.x * 0.5 - 300, 200), "친구에게 받은 4자리 숫자", 24, Color(1, 1, 1, 0.75), HORIZONTAL_ALIGNMENT_CENTER, 0)
	for i in 4:
		var r := Rect2(v.x * 0.5 - 520 + i * 110, 250, 90, 120)
		_panel(r, Color("b39ddb"), Color(0.1, 0.1, 0.16))
		if i < code_input.length():
			_text(r.get_center() + Vector2(0, 24), code_input[i], 66, Color.WHITE)
	var st: String = main.coop.net.status
	if st == "connecting":
		_text(Vector2(v.x * 0.5 - 300, 430), "연결 중...", 30, Color(1, 1, 0.7))
	elif st == "error":
		_text(Vector2(v.x * 0.5 - 300, 430), _net_err(), 26, Color("ff8a80"))


func _net_err() -> String:
	match main.coop.net.error:
		"unavailable-id":
			return "이미 사용 중인 코드예요. 다시 만들어 주세요"
		"peer-unavailable":
			return "방을 찾을 수 없어요. 코드를 확인하세요"
		"timeout":
			return "연결 시간이 초과됐어요"
	return "연결 오류 (%s)" % main.coop.net.error


func _draw_room() -> void:
	var v: Vector2 = main.view
	var c = main.coop
	draw_rect(Rect2(Vector2.ZERO, v), Color(0, 0, 0, 0.55))
	_text(Vector2(v.x * 0.5, 80), "대기실", 54, Color("e0e0ff"), HORIZONTAL_ALIGNMENT_CENTER, 10)
	var cp := Rect2(v.x * 0.5 - 560, 120, 460, 220)
	_panel(cp, Color("ffd54f"), Color(0.12, 0.1, 0.05, 0.95))
	_text(Vector2(cp.get_center().x, cp.position.y + 50), "방 코드", 30, Color(1, 1, 1, 0.8))
	_text(Vector2(cp.get_center().x, cp.position.y + 150), c.net.code, 100, Color("ffd54f"), HORIZONTAL_ALIGNMENT_CENTER, 10)
	var st: String = c.net.status
	var msg := "친구에게 코드를 알려주세요 (최대 4명)" if c.net.is_host else "방장이 시작하기를 기다리는 중" + ".".repeat(int(main.time * 2.0) % 4)
	if st == "connecting":
		msg = "방을 여는 중..."
	elif st == "error":
		msg = _net_err()
	_text(Vector2(cp.get_center().x, cp.end.y + 40), msg, 24, Color(1, 1, 1, 0.85), HORIZONTAL_ALIGNMENT_CENTER, 0)
	for i in 4:
		var r := Rect2(v.x * 0.5 + 40, 120 + i * 80, 520, 68)
		var has: bool = i < c.roster.size()
		_panel(r, Color(0.4, 0.4, 0.5) if has else Color(0.2, 0.2, 0.24), Color(0.1, 0.1, 0.14, 0.9))
		if has:
			var e: Dictionary = c.roster[i]
			var pal: Array = main.dino.PALETTES[i]
			draw_circle(r.position + Vector2(40, 34), 20.0, pal[0])
			var me: bool = e.id == c.my_id()
			_text(Vector2(r.position.x + 76, r.position.y + 46), e.nick + (" (나)" if me else "") + ("   방장" if i == 0 else ""), 30, Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT, 4)
		else:
			_text(Vector2(r.position.x + 76, r.position.y + 46), "빈 자리", 26, Color(0.5, 0.5, 0.55), HORIZONTAL_ALIGNMENT_LEFT, 0)
	if c.net.is_host:
		_text(Vector2(v.x * 0.5 + 280, v.y - 196), "스테이지 %d" % c.room_stage, 40, Color.WHITE)


func _draw_lobby() -> void:
	var v: Vector2 = main.view
	var s: int = main.selected_stage
	_text(Vector2(v.x * 0.5, 78), "공룡 대난동", 60, Color("8bff6b"), HORIZONTAL_ALIGNMENT_CENTER, 12)
	_gold_label(v.x - 28, 60, main.gold)
	var p := _lobby_panel()
	var cleared: bool = s < main.unlocked
	_panel(p, Color("8bff6b") if cleared else Color("ffcf4a"))
	var cx := p.get_center().x
	_text(Vector2(cx, p.position.y + 74), "스테이지 %d" % s, 62, Color.WHITE)
	_text(Vector2(cx, p.position.y + 110), Stages.THEME_NAMES[Stages.theme(s)], 24, Color(0.8, 0.9, 1.0), HORIZONTAL_ALIGNMENT_CENTER, 0)
	# 난이도 별
	var n := Stages.stars(s)
	for i in 5:
		_star(Vector2(cx - 80 + i * 40, p.position.y + 142), 15.0, Color("ffca28") if i < n else Color(1, 1, 1, 0.2))
	var boss: Dictionary = Stages.BOSSES[Stages.boss_kind(s)]
	_text(Vector2(cx, p.position.y + 198), "보스: " + boss.name, 34, Color("ff8a80"))
	_text(Vector2(cx, p.position.y + 232), boss.desc, 22, Color(1, 1, 1, 0.85), HORIZONTAL_ALIGNMENT_CENTER, 0)
	var news := Stages.new_enemies(s)
	var y := p.position.y + 276
	if not news.is_empty():
		_text(Vector2(cx, y), "새로운 적: " + ", ".join(news), 24, Color("ffe082"), HORIZONTAL_ALIGNMENT_CENTER, 0)
		y += 34
	_text(Vector2(cx, y), "적 체력 x%.1f   공격력 x%.1f" % [Stages.hp_mult(s), Stages.dmg_mult(s)], 20, Color(1, 1, 1, 0.6), HORIZONTAL_ALIGNMENT_CENTER, 0)
	var best: int = int(main.best.get(str(s), 0))
	var info := "클리어 보상 %d G" % int(round(Stages.clear_gold(s) * Meta.gold_mult(main.meta)))
	if best > 0:
		info += "     최고 점수 %d" % best
	_text(Vector2(cx, min(y + 36, p.end.y - 16)), info, 22, COIN, HORIZONTAL_ALIGNMENT_CENTER, 0)
	if cleared:
		_text(Vector2(p.end.x - 20, p.position.y + 40), "클리어", 24, Color("8bff6b"), HORIZONTAL_ALIGNMENT_RIGHT, 4)
	if not main.touch.enabled:
		_text(Vector2(v.x * 0.5, v.y - 22), "← → 스테이지 선택     J 출격     K 강화 상점", 20, Color(1, 1, 1, 0.6), HORIZONTAL_ALIGNMENT_CENTER, 0)


func _draw_shop() -> void:
	var v: Vector2 = main.view
	draw_rect(Rect2(Vector2.ZERO, v), Color(0, 0, 0, 0.55))
	_text(Vector2(v.x * 0.5, 72), "강화 상점", 58, Color("ffcf4a"), HORIZONTAL_ALIGNMENT_CENTER, 12)
	_gold_label(v.x - 28, 64, main.gold)
	if not main.touch.enabled and toast_t <= 0.0:
		_text(Vector2(v.x * 0.5, v.y - 22), "방향키로 선택     J 구매     Esc 뒤로", 20, Color(1, 1, 1, 0.6), HORIZONTAL_ALIGNMENT_CENTER, 0)


func _shop_card(b: Dictionary, focused: bool) -> void:
	var u: Dictionary = b.meta
	var r: Rect2 = b.rect
	var lvl: int = main.meta.get(u.id, 0)
	var maxed: bool = lvl >= u.max
	var c := Meta.cost(u, lvl)
	var afford: bool = main.gold >= c
	var col: Color = u.col
	if focused:
		r = r.grow(3.0)
	_panel(r, Color.WHITE if focused else (col if afford and not maxed else col.darkened(0.5)), Color(0.1, 0.12, 0.11, 0.95))
	var cx := r.get_center().x
	_text(Vector2(cx, r.position.y + 40), u.name, 28, col, HORIZONTAL_ALIGNMENT_CENTER, 4)
	var lines: PackedStringArray = u.desc.split("\n")
	for j in lines.size():
		_text(Vector2(cx, r.position.y + 76 + j * 26), lines[j], 20, Color(0.88, 0.88, 0.88), HORIZONTAL_ALIGNMENT_CENTER, 0)
	# 레벨 칸
	var pips: int = u.max
	var pw: float = min(18.0, (r.size.x - 40.0) / pips - 4.0)
	var px0 := cx - (pips * pw + (pips - 1) * 4.0) * 0.5
	for p in pips:
		draw_rect(Rect2(px0 + p * (pw + 4.0), r.end.y - 78, pw, 10), col if p < lvl else Color(1, 1, 1, 0.15))
	_text(Vector2(cx, r.end.y - 88), "Lv %d / %d" % [lvl, u.max], 18, Color(1, 1, 1, 0.7), HORIZONTAL_ALIGNMENT_CENTER, 0)
	# 가격
	var pr := Rect2(r.position.x + 14, r.end.y - 58, r.size.x - 28, 44)
	draw_rect(pr, Color(0, 0, 0, 0.35))
	if maxed:
		_text(pr.get_center() + Vector2(0, 11), "최대", 28, Color("8bff6b"), HORIZONTAL_ALIGNMENT_CENTER, 0)
	else:
		var s := "%d" % c
		var w := font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, 28).x
		coin(pr.get_center() + Vector2(-w * 0.5 - 16, 0), 12.0)
		_text(pr.get_center() + Vector2(10, 11), s, 28, COIN if afford else Color("ff6e6e"), HORIZONTAL_ALIGNMENT_CENTER, 0)


func _draw_result() -> void:
	var v: Vector2 = main.view
	var r: Dictionary = main.result
	var a: float = clamp(open_t * 2.0, 0.0, 1.0)
	draw_rect(Rect2(Vector2.ZERO, v), Color(0, 0, 0, 0.5 * a))
	var p := Rect2(v.x * 0.5 - 380, 70, 760, min(v.y - 235.0, 380.0))
	var cleared: bool = r.get("cleared", false)
	_panel(p, Color("ffcf4a") if cleared else Color("ff6e6e"))
	var cx := p.get_center().x
	var y := p.position.y + 84
	if cleared:
		_text(Vector2(cx, y), "스테이지 %d 클리어!" % r.stage, 64, Color("ffe082"), HORIZONTAL_ALIGNMENT_CENTER, 12)
		y += 50
		if r.get("first", false):
			_text(Vector2(cx, y), "스테이지 %d 해금!" % (r.stage + 1), 28, Color("8bff6b"))
		y += 56
		_text(Vector2(cx, y), "처치 %d     점수 %d" % [r.kills, r.score], 32, Color.WHITE)
		y += 52
		_text(Vector2(cx, y), "골드 +%d  (처치 %d + 클리어 보너스 %d)" % [r.run_gold + r.bonus, r.run_gold, r.bonus], 30, COIN)
	else:
		_text(Vector2(cx, y), "게임 오버", 72, Color("ff6e6e"), HORIZONTAL_ALIGNMENT_CENTER, 12)
		y += 56
		_text(Vector2(cx, y), "스테이지 %d  -  웨이브 %d" % [r.stage, max(r.wave, 1)], 30, Color(1, 1, 1, 0.85))
		y += 54
		_text(Vector2(cx, y), "처치 %d     점수 %d" % [r.kills, r.score], 32, Color.WHITE)
		y += 52
		_text(Vector2(cx, y), "획득 골드 +%d" % r.run_gold, 30, COIN)
		y += 44
		_text(Vector2(cx, y), "상점에서 영구 강화를 하면 더 강해집니다!", 24, Color(0.8, 0.9, 1.0), HORIZONTAL_ALIGNMENT_CENTER, 0)
	_gold_label(p.end.x - 24, p.end.y - 22, main.gold, 28)


func _star(c: Vector2, r: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 10:
		var rr := r if i % 2 == 0 else r * 0.45
		var ang := -PI * 0.5 + TAU * i / 10.0
		pts.append(c + Vector2(cos(ang), sin(ang)) * rr)
	draw_colored_polygon(pts, col)
