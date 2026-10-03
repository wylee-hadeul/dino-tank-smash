extends Node2D
## HUD 및 타이틀/게임오버/세로화면 오버레이.

var main
var font: Font


func _ready() -> void:
	font = ThemeDB.fallback_font


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
		_text(Vector2(c.x, c.y + 110), "ROTATE YOUR PHONE", 64, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
		_text(Vector2(c.x, c.y + 190), "Landscape mode only", 40, Color(1, 1, 1, 0.7), HORIZONTAL_ALIGNMENT_CENTER)
		return

	var d = main.dino
	if main.state != main.State.TITLE:
		# 체력/포효 게이지
		_text(Vector2(24, 44), "HP", 26, Color.WHITE)
		var hp_col := Color("5ee35e") if d.hp > 35.0 else Color("ff5252")
		_bar(Rect2(70, 24, 280, 24), d.hp / d.max_hp, hp_col)
		_text(Vector2(24, 82), "ROAR", 18, Color(1, 0.75, 0.3))
		var full: bool = d.roar_meter >= 100.0
		var rcol := Color(1, 0.55 + sin(tm * 10.0) * 0.2, 0.1) if full else Color("ffa726")
		_bar(Rect2(82, 66, 220, 16), d.roar_meter / 100.0, rcol)
		if full:
			_text(Vector2(312, 82), "READY!", 20, rcol)
		# 점수
		_text(Vector2(v.x * 0.5, 50), "%d" % main.score, 44, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
		_text(Vector2(v.x * 0.5, 78), "BEST %d" % max(main.high_score, main.score), 18, Color(1, 1, 1, 0.75), HORIZONTAL_ALIGNMENT_CENTER)
		_text(Vector2(v.x - 24, 48), "WAVE %d" % max(main.wave, 1), 32, Color.WHITE, HORIZONTAL_ALIGNMENT_RIGHT)
		_text(Vector2(v.x - 24, 78), "KILLS %d" % main.kills, 20, Color(1, 1, 1, 0.75), HORIZONTAL_ALIGNMENT_RIGHT)
		if main.combo >= 2:
			var cs: int = 34 + min(main.combo, 8) * 3
			_text(Vector2(v.x * 0.5, 130), "COMBO x%d" % main.combo, cs, Color(1, 0.55, 0.2, clamp(main.combo_t, 0.0, 1.0)), HORIZONTAL_ALIGNMENT_CENTER)

	if main.banner_t > 0.0 and main.state == main.State.PLAYING:
		var a: float = clamp(main.banner_t * 2.0, 0.0, 1.0)
		var pop: float = 1.0 + max(0.0, main.banner_t - 1.9) * 2.0
		_text(Vector2(v.x * 0.5, v.y * 0.36), main.banner_text, int(72 * pop), Color(1, 0.95, 0.4, a), HORIZONTAL_ALIGNMENT_CENTER, 12)

	if main.state == main.State.TITLE:
		draw_rect(Rect2(Vector2.ZERO, v), Color(0, 0, 0, 0.35))
		var bob := sin(tm * 2.5) * 6.0
		_text(Vector2(v.x * 0.5, v.y * 0.27 + bob), "DINO SMASH", 110, Color("8bff6b"), HORIZONTAL_ALIGNMENT_CENTER, 16)
		_text(Vector2(v.x * 0.5, v.y * 0.37 + bob), "vs  TANKS", 54, Color("ffcf4a"), HORIZONTAL_ALIGNMENT_CENTER, 12)
		var blink := 0.55 + sin(tm * 5.0) * 0.45
		_text(Vector2(v.x * 0.5, v.y * 0.53), "TAP TO START", 44, Color(1, 1, 1, blink), HORIZONTAL_ALIGNMENT_CENTER)
		_text(Vector2(v.x * 0.5, v.y * 0.62), "Move: A/D or Arrows   Jump: W/Space   Bite: J   Roar: K", 22, Color(1, 1, 1, 0.85), HORIZONTAL_ALIGNMENT_CENTER, 6)
		_text(Vector2(v.x * 0.5, v.y * 0.67), "Bite shells to send them back!  Jump on tanks to stomp!", 22, Color(1, 1, 1, 0.85), HORIZONTAL_ALIGNMENT_CENTER, 6)
		if main.high_score > 0:
			_text(Vector2(v.x * 0.5, v.y * 0.74), "BEST %d" % main.high_score, 26, Color(1, 0.9, 0.4), HORIZONTAL_ALIGNMENT_CENTER)
	elif main.state == main.State.GAMEOVER:
		var a: float = clamp(main.gameover_t * 1.5, 0.0, 1.0)
		draw_rect(Rect2(Vector2.ZERO, v), Color(0.2, 0, 0, 0.45 * a))
		_text(Vector2(v.x * 0.5, v.y * 0.32), "GAME OVER", 100, Color(1, 0.35, 0.3, a), HORIZONTAL_ALIGNMENT_CENTER, 14)
		_text(Vector2(v.x * 0.5, v.y * 0.44), "SCORE %d" % main.score, 48, Color(1, 1, 1, a), HORIZONTAL_ALIGNMENT_CENTER)
		var best_txt := "NEW BEST!" if main.score >= main.high_score and main.score > 0 else "BEST %d" % main.high_score
		_text(Vector2(v.x * 0.5, v.y * 0.52), best_txt, 32, Color(1, 0.9, 0.4, a), HORIZONTAL_ALIGNMENT_CENTER)
		_text(Vector2(v.x * 0.5, v.y * 0.59), "WAVE %d  ·  %d TANKS SMASHED" % [main.wave, main.kills], 26, Color(1, 1, 1, a * 0.85), HORIZONTAL_ALIGNMENT_CENTER)
		if main.gameover_t > 2.2:
			var blink := 0.55 + sin(tm * 5.0) * 0.45
			_text(Vector2(v.x * 0.5, v.y * 0.7), "TAP TO RETRY", 42, Color(1, 1, 1, blink), HORIZONTAL_ALIGNMENT_CENTER)
