extends Node
## 테스트용 오토플레이 봇 + 주기적 스크린샷/로그.
## 실행: godot --path . -- --autoplay [--shots=DIR] [--duration=SEC] [--shot-every=SEC]
## 웹: index.html?autoplay

var main
var shots_dir := ""
var duration := 90.0
var shot_every := 5.0
var elapsed := 0.0
var next_shot := 1.0
var next_log := 0.0
var shot_n := 0
var taps := {}       # 한 프레임만 눌렀다 떼는 액션
var holding := {}
var frames := 0
var fps_acc := 0.0
var restart_t := 0.0
var suicide_at := -1.0  # 게임오버 화면 검수용
var manual_pick := false  # 강화 카드는 사람이 직접 고른다 (터치 테스트용)


func configure(args: PackedStringArray) -> void:
	process_priority = -10  # main보다 먼저 입력을 넣어야 just_pressed가 잡힌다
	for a in args:
		if a.begins_with("--shots="):
			shots_dir = a.substr(8)
		elif a.begins_with("--duration="):
			duration = float(a.substr(11))
		elif a.begins_with("--suicide="):
			suicide_at = float(a.substr(10))
		elif a == "--manualpick":
			manual_pick = true
		elif a.begins_with("--shot-every="):
			shot_every = float(a.substr(13))
	if shots_dir != "":
		DirAccess.make_dir_recursive_absolute(shots_dir)
	main.dlog("autoplay on: duration=%.0fs shots=%s every=%.1fs" % [duration, shots_dir, shot_every])


func _process(delta: float) -> void:
	elapsed += delta
	frames += 1
	fps_acc += delta
	for a in taps.keys():
		if taps[a] <= 0:
			Input.action_release(a)
			taps.erase(a)
		else:
			taps[a] -= 1

	if main.state == main.State.TITLE and elapsed > 1.5:
		main.start_game()
	elif main.state == main.State.GAMEOVER:
		restart_t += delta
		if restart_t > 3.0:
			restart_t = 0.0
			main.dlog("auto-restart")
			main.start_game()
	elif main.state == main.State.UPGRADE:
		_move(0.0)
		if main.upgrade_t > 1.2 and not manual_pick:
			if shots_dir != "":
				_screenshot()
			main.choose_upgrade(randi() % main.upgrade_choices.size())
	elif main.state == main.State.PLAYING:
		if suicide_at > 0.0 and elapsed >= suicide_at:
			suicide_at = -1.0
			main.dino.invuln = 0.0
			main.dino.hurt(99999.0)
		_think()

	if elapsed >= next_log:
		next_log += 2.0
		var d = main.dino
		main.dlog("state=%s wave=%d hp=%.0f roar=%.0f score=%d kills=%d tanks=%d helis=%d shells=%d fx=%d fps=%.0f" % [
			main.State.keys()[main.state], main.wave, d.hp, d.roar_meter, main.score, main.kills,
			main.tanks.size(), main.helis.size(), main.shells.size(), main.fx.parts.size(), frames / max(fps_acc, 0.001)])
		frames = 0
		fps_acc = 0.0
	if shots_dir != "" and elapsed >= next_shot:
		next_shot += shot_every
		_screenshot()
	if elapsed >= duration:
		main.dlog("autoplay finished: best=%d" % main.high_score)
		get_tree().quit()


func _screenshot() -> void:
	var img := get_viewport().get_texture().get_image()
	if img == null:
		return
	shot_n += 1
	var path := "%s/shot_%03d_%s_w%d.png" % [shots_dir, shot_n, main.State.keys()[main.state].to_lower(), main.wave]
	img.save_png(path)
	main.dlog("screenshot " + path)


func _tap(a: String) -> void:
	if taps.has(a):
		return
	Input.action_press(a)
	taps[a] = 1


func _hold(a: String, on: bool) -> void:
	if on and not holding.get(a, false):
		Input.action_press(a)
	elif not on and holding.get(a, false):
		Input.action_release(a)
	holding[a] = on


func _move(dir: float) -> void:
	_hold("left", dir < 0.0)
	_hold("right", dir > 0.0)


func _think() -> void:
	var d = main.dino
	if d.dead:
		_move(0.0)
		return
	var px: float = d.position.x

	# 1) 날아오는 포탄: 가까우면 그쪽을 보고 문다
	for s in main.shells:
		if s.dead or s.reflected:
			continue
		var dx: float = s.position.x - px
		var dy: float = s.position.y - (d.position.y - 90.0)
		if abs(dx) < 190.0 and abs(dy) < 200.0 and sign(s.vel.x) != sign(dx):
			var face: float = sign(dx)
			if face != d.facing:
				_move(face)
				return
			_tap("bite")
			return

	# 2) 포효: 적이 2기 이상이면
	if d.roar_meter >= 100.0 and main.tanks.size() + main.helis.size() >= 2:
		_tap("roar")

	# 3) 가장 가까운 적에게 접근
	var target = null
	var best := INF
	for t in main.tanks:
		if t.dead:
			continue
		var dist: float = abs(t.position.x - px)
		if dist < best:
			best = dist
			target = t
	for h in main.helis:
		if h.dead:
			continue
		var dist: float = abs(h.position.x - px) + 120.0
		if dist < best:
			best = dist
			target = h
	if target == null:
		_move(sign(main.view.x * 0.5 - px) if abs(main.view.x * 0.5 - px) > 40.0 else 0.0)
		return
	var tdx: float = target.position.x - px
	var is_heli: bool = main.helis.has(target)
	if is_heli:
		_move(sign(tdx) if abs(tdx) > 40.0 else 0.0)
		if abs(tdx) < 110.0 and d.on_ground:
			_tap("jump")
		if not d.on_ground and d.vel.y > -250.0:
			_tap("bite")
		return
	var reach: float = target.half_w + 90.0
	if abs(tdx) > reach:
		_move(sign(tdx))
		# 가끔 점프해서 밟기 시도
		if abs(tdx) < reach + 120.0 and d.on_ground and randf() < 0.02:
			_tap("jump")
	else:
		_move(0.0)
		if sign(tdx) != d.facing and tdx != 0.0:
			_move(sign(tdx))
		else:
			_tap("bite")
