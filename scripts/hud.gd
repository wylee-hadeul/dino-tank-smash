extends Node2D
## HUD 및 타이틀/게임오버/세로화면 오버레이.

const Upgrades = preload("res://scripts/upgrades.gd")

const Stages = preload("res://scripts/stages.gd")

var main
var font: Font
var card_box := StyleBoxFlat.new()


func _ready() -> void:
	font = ThemeDB.fallback_font
	card_box.set_corner_radius_all(22)
	card_box.set_border_width_all(5)
	card_box.shadow_size = 12
	card_box.shadow_color = Color(0, 0, 0, 0.45)


func _text(pos: Vector2, s: String, size: int, col: Color, align := HORIZONTAL_ALIGNMENT_LEFT, outline := 8) -> void:
	var w := font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var p := pos
	if align == HORIZONTAL_ALIGNMENT_CENTER:
		p.x -= w * 0.5
	elif align == HORIZONTAL_ALIGNMENT_RIGHT:
		p.x -= w
	if outline > 0:
		draw_string_outline(font, p, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, outline, Color(0, 0, 0, col.a * 0.85))
	draw_string(font, p, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)


func _bar(r: Rect2, frac: float, col: Color) -> void:
	draw_rect(r.grow(3), Color(0, 0, 0, 0.55))
	draw_rect(r, Color(0.2, 0.2, 0.2, 0.8))
	draw_rect(Rect2(r.position, Vector2(r.size.x * clamp(frac, 0.0, 1.0), r.size.y)), col)
	draw_rect(Rect2(r.position, Vector2(r.size.x * clamp(frac, 0.0, 1.0), r.size.y * 0.35)), Color(1, 1, 1, 0.25))


func _draw() -> void:
	var v: Vector2 = main.view
	var tm: float = main.time
	if main.is_portrait():
		draw_rect(Rect2(Vector2.ZERO, v), Color("1d2b1d"))
		var c := v * 0.5
		var phone := Rect2(c.x - 70, c.y - 260, 140, 240)
		var rot := sin(tm * 2.0) * 0.5 + 0.5
		draw_set_transform(phone.get_center(), -rot * PI * 0.5, Vector2.ONE)
		draw_rect(Rect2(-70, -120, 140, 240), Color.WHITE, false, 8.0)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		_text(Vector2(c.x, c.y + 110), "화면을 가로로 돌려주세요", 64, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
		_text(Vector2(c.x, c.y + 190), "가로 모드 전용 게임입니다", 40, Color(1, 1, 1, 0.7), HORIZONTAL_ALIGNMENT_CENTER)
		return

	var d = main.dino
	if main.state in [main.State.PLAYING, main.State.UPGRADE]:
		# 체력/포효 게이지
		_text(Vector2(18, 45), "체력", 24, Color.WHITE)
		var hp_col := Color("5ee35e") if d.hp > 35.0 else Color("ff5252")
		_bar(Rect2(70, 24, 280, 24), d.hp / d.max_hp, hp_col)
		_text(Vector2(24, 82), "포효", 20, Color(1, 0.75, 0.3))
		var full: bool = d.roar_meter >= 100.0
		var rcol := Color(1, 0.55 + sin(tm * 10.0) * 0.2, 0.1) if full else Color("ffa726")
		_bar(Rect2(82, 66, 220, 16), d.roar_meter / 100.0, rcol)
		if full:
			_text(Vector2(312, 82), "준비!", 20, rcol)
		# 보유 강화
		var x := 24.0
		for u in Upgrades.LIST:
			var l: int = d.lv(u.id)
			if l <= 0:
				continue
			var label := "%s %d" % [u.short, l]
			var w := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
			draw_rect(Rect2(x - 4, 94, w + 8, 22), Color(0, 0, 0, 0.45))
			_text(Vector2(x, 111), label, 16, u.col, HORIZONTAL_ALIGNMENT_LEFT, 0)
			x += w + 14.0
		# 점수
		_text(Vector2(v.x * 0.5, 50), "%d" % main.score, 44, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
		_text(Vector2(v.x * 0.5, 76), "처치 %d" % main.kills, 18, Color(1, 1, 1, 0.75), HORIZONTAL_ALIGNMENT_CENTER)
		var wave_txt := "보스전" if main.wave >= Stages.WAVES_PER_STAGE else "웨이브 %d/%d" % [max(main.wave, 1), Stages.WAVES_PER_STAGE]
		_text(Vector2(v.x - 24, 44), "스테이지 %d" % main.stage, 30, Color.WHITE, HORIZONTAL_ALIGNMENT_RIGHT)
		_text(Vector2(v.x - 24, 74), wave_txt, 22, Color(1, 1, 1, 0.8), HORIZONTAL_ALIGNMENT_RIGHT)
		_gold_label(v.x - 24, 106, main.run_gold, 24)
		if main.boss and not main.boss.dead:
			_boss_bar(v, main.boss)
		if main.combo >= 2:
			var cs: int = 34 + min(main.combo, 8) * 3
			_text(Vector2(v.x * 0.5, 168), "콤보 x%d" % main.combo, cs, Color(1, 0.55, 0.2, clamp(main.combo_t, 0.0, 1.0)), HORIZONTAL_ALIGNMENT_CENTER)

	if main.banner_t > 0.0 and main.state == main.State.PLAYING:
		var a: float = clamp(main.banner_t * 2.0, 0.0, 1.0)
		var pop: float = 1.0 + max(0.0, main.banner_t - 1.9) * 2.0
		_text(Vector2(v.x * 0.5, v.y * 0.36), main.banner_text, int(72 * pop), Color(1, 0.95, 0.4, a), HORIZONTAL_ALIGNMENT_CENTER, 12)

	if main.state == main.State.UPGRADE:
		_draw_upgrade(v, tm)

	if main.state == main.State.TITLE:
		draw_rect(Rect2(Vector2.ZERO, v), Color(0, 0, 0, 0.35))
		var bob := sin(tm * 2.5) * 6.0
		_text(Vector2(v.x * 0.5, v.y * 0.27 + bob), "공룡 대난동", 120, Color("8bff6b"), HORIZONTAL_ALIGNMENT_CENTER, 16)
		_text(Vector2(v.x * 0.5, v.y * 0.37 + bob), "vs  탱크 군단", 56, Color("ffcf4a"), HORIZONTAL_ALIGNMENT_CENTER, 12)
		var blink := 0.55 + sin(tm * 5.0) * 0.45
		_text(Vector2(v.x * 0.5, v.y * 0.53), "터치해서 시작" if main.touch.enabled else "아무 키나 눌러 시작", 46, Color(1, 1, 1, blink), HORIZONTAL_ALIGNMENT_CENTER)
		_text(Vector2(v.x * 0.5, v.y * 0.62), "이동: A/D, 방향키    점프: W, 스페이스    물기: J    포효: K", 22, Color(1, 1, 1, 0.85), HORIZONTAL_ALIGNMENT_CENTER, 6)
		_text(Vector2(v.x * 0.5, v.y * 0.67), "날아오는 포탄을 물어서 되받아쳐라!  점프해서 탱크를 밟아라!", 22, Color(1, 1, 1, 0.85), HORIZONTAL_ALIGNMENT_CENTER, 6)
		if main.high_score > 0:
			_text(Vector2(v.x * 0.5, v.y * 0.74), "최고 기록 %d" % main.high_score, 26, Color(1, 0.9, 0.4), HORIZONTAL_ALIGNMENT_CENTER)


func _gold_label(right_x: float, y: float, amount: int, size := 34) -> void:
	var s := "%d" % amount
	var w := font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	_text(Vector2(right_x, y), s, size, Color("ffca28"), HORIZONTAL_ALIGNMENT_RIGHT)
	var c := Vector2(right_x - w - size * 0.6, y - size * 0.33)
	var r := size * 0.42
	draw_circle(c, r, Color("b8860b"))
	draw_circle(c, r * 0.82, Color("ffca28"))
	draw_arc(c, r * 0.55, 0.0, TAU, 20, Color("e0a800"), r * 0.18)


func _boss_bar(v: Vector2, b) -> void:
	var w: float = min(620.0, v.x - 760.0)
	var r := Rect2(v.x * 0.5 - w * 0.5, 120, w, 20)
	_text(Vector2(v.x * 0.5, 113), b.boss_name + ("  (분노!)" if b.enraged() else ""), 24, Color("ff8a80"), HORIZONTAL_ALIGNMENT_CENTER, 6)
	_bar(r, b.hp / b.max_hp, Color("e53935") if not b.enraged() else Color(1, 0.3 + sin(main.time * 10.0) * 0.2, 0.1))


func _draw_upgrade(v: Vector2, tm: float) -> void:
	var a: float = clamp(main.upgrade_t * 3.0, 0.0, 1.0)
	draw_rect(Rect2(Vector2.ZERO, v), Color(0, 0, 0, 0.6 * a))
	_text(Vector2(v.x * 0.5, 150 - (1.0 - a) * 30.0), "능력 강화를 선택하세요", 58, Color(1, 0.9, 0.35, a), HORIZONTAL_ALIGNMENT_CENTER, 12)
	var rects: Array = main.card_rects()
	var d = main.dino
	for i in rects.size():
		var u: Dictionary = main.upgrade_choices[i]
		var k: float = clamp(main.upgrade_t * 3.0 - i * 0.25, 0.0, 1.0)
		if k <= 0.0:
			continue
		var r: Rect2 = rects[i]
		var e := 1.0 - pow(1.0 - k, 3.0)
		r.position.y += (1.0 - e) * 120.0
		var sel: bool = i == main.upgrade_sel
		if sel:
			r = r.grow(6.0 + sin(tm * 6.0) * 3.0)
		var col: Color = u.col
		card_box.bg_color = Color(0.12, 0.14, 0.12, 0.95 * e)
		card_box.border_color = Color(col, e) if sel else Color(col.darkened(0.35), e)
		card_box.draw(get_canvas_item(), r)
		var cx := r.get_center().x
		# 아이콘 원
		var ic := Vector2(cx, r.position.y + 85.0)
		draw_circle(ic, 52.0, Color(col, 0.25 * e))
		draw_circle(ic, 40.0, Color(col, e))
		_icon(u.id, ic, Color(0.1, 0.1, 0.1, e))
		_text(Vector2(cx, r.position.y + 185.0), u.name, 30, Color(1, 1, 1, e), HORIZONTAL_ALIGNMENT_CENTER, 6)
		var lines: PackedStringArray = u.desc.split("\n")
		for j in lines.size():
			_text(Vector2(cx, r.position.y + 228.0 + j * 30.0), lines[j], 22, Color(0.85, 0.85, 0.85, e), HORIZONTAL_ALIGNMENT_CENTER, 0)
		var lvl: int = d.lv(u.id)
		var lv_txt := "Lv %d  >  %d" % [lvl, lvl + 1] if lvl > 0 else "신규!"
		_text(Vector2(cx, r.end.y - 52.0), lv_txt, 24, Color(col, e), HORIZONTAL_ALIGNMENT_CENTER, 6)
		# 레벨 칸
		var pips: int = u.max
		var pw := 18.0
		var px0 := cx - (pips * pw + (pips - 1) * 6.0) * 0.5
		for p in pips:
			var pr := Rect2(px0 + p * (pw + 6.0), r.end.y - 34.0, pw, 10.0)
			var filled := p < lvl
			var next := p == lvl
			var pc := Color(col, e) if filled else (Color(1, 1, 1, (0.5 + sin(tm * 8.0) * 0.4) * e) if next else Color(1, 1, 1, 0.15 * e))
			draw_rect(pr, pc)
	if main.upgrade_t > 0.5:
		var hint := "카드를 터치하세요" if main.touch.enabled else "1/2/3 키 또는 좌우 이동 후 J로 선택"
		_text(Vector2(v.x * 0.5, v.y - 24.0), hint, 22, Color(1, 1, 1, 0.6), HORIZONTAL_ALIGNMENT_CENTER, 0)


func _icon(id: String, c: Vector2, col: Color) -> void:
	match id:
		"hp":
			draw_rect(Rect2(c - Vector2(7, 22), Vector2(14, 44)), col)
			draw_rect(Rect2(c - Vector2(22, 7), Vector2(44, 14)), col)
		"bite", "frenzy":
			for i in 4:
				var x := c.x - 22.0 + i * 11.0
				draw_colored_polygon(PackedVector2Array([Vector2(x, c.y - 14), Vector2(x + 11, c.y - 14), Vector2(x + 5.5, c.y + 4)]), col)
				draw_colored_polygon(PackedVector2Array([Vector2(x, c.y + 18), Vector2(x + 11, c.y + 18), Vector2(x + 5.5, c.y)]), col)
			if id == "frenzy":
				draw_arc(c, 30.0, -0.5, 1.2, 12, col, 4.0)
		"reach":
			draw_line(c + Vector2(-22, 0), c + Vector2(22, 0), col, 6.0)
			draw_colored_polygon(PackedVector2Array([c + Vector2(26, 0), c + Vector2(12, -12), c + Vector2(12, 12)]), col)
			draw_colored_polygon(PackedVector2Array([c + Vector2(-26, 0), c + Vector2(-12, -12), c + Vector2(-12, 12)]), col)
		"speed":
			for i in 3:
				var o := Vector2(-14 + i * 12, 0)
				draw_polyline(PackedVector2Array([c + o + Vector2(-8, -16), c + o + Vector2(6, 0), c + o + Vector2(-8, 16)]), col, 5.0)
		"jump":
			draw_colored_polygon(PackedVector2Array([c + Vector2(0, -24), c + Vector2(18, -4), c + Vector2(-18, -4)]), col)
			draw_rect(Rect2(c + Vector2(-7, -6), Vector2(14, 16)), col)
			draw_rect(Rect2(c + Vector2(-20, 16), Vector2(40, 6)), col)
		"roar":
			for i in 3:
				draw_arc(c + Vector2(-16, 0), 12.0 + i * 11.0, -0.7, 0.7, 10, col, 4.0)
		"armor":
			draw_colored_polygon(PackedVector2Array([c + Vector2(-20, -20), c + Vector2(20, -20), c + Vector2(18, 4), c + Vector2(0, 24), c + Vector2(-18, 4)]), col)
		"vamp":
			draw_circle(c + Vector2(-9, -6), 12.0, col)
			draw_circle(c + Vector2(9, -6), 12.0, col)
			draw_colored_polygon(PackedVector2Array([c + Vector2(-20, 0), c + Vector2(20, 0), c + Vector2(0, 22)]), col)
		"reflect":
			draw_circle(c + Vector2(10, -10), 9.0, col)
			draw_arc(c, 22.0, PI * 0.6, PI * 1.9, 14, col, 5.0)
			draw_colored_polygon(PackedVector2Array([c + Vector2(-22, 12), c + Vector2(-30, -2), c + Vector2(-12, -2)]), col)
		"regen":
			draw_arc(c, 20.0, 0.3, TAU - 0.3, 20, col, 5.0)
			draw_colored_polygon(PackedVector2Array([c + Vector2(20, -4), c + Vector2(12, 8), c + Vector2(28, 8)]), col)
