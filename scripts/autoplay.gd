extends Node
## 테스트용 오토플레이 봇 + 주기적 스크린샷/로그.
## 실행: godot --path . -- --autoplay [옵션]
##   --shots=DIR --shot-every=SEC   주기적 스크린샷
##   --duration=SEC                 종료 시간
##   --stage=N                      N 스테이지부터 (해금 처리)
##   --gold=N                       시작 골드 (상점 테스트)
##   --god                          무적 (보스 패턴 관찰용)
##   --fresh                        테스트 저장 파일 초기화
##   --suicide=SEC                  지정 시각에 사망 (게임오버/부활 검수)
##   --manualpick                   강화 카드는 사람이 직접 선택
## 웹: index.html?autoplay&stage=3&god
## 오토플레이는 user://save_autoplay.cfg 를 사용해 실제 저장을 건드리지 않는다.

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
var wait_t := 0.0
var suicide_at := -1.0
var manual_pick := false
var god := false
var start_stage := 0
var shot_states := {}  # 화면별 첫 스크린샷 여부


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
		elif a == "--god":
			god = true
		elif a.begins_with("--stage="):
			start_stage = int(a.substr(8))
			main.unlocked = max(main.unlocked, start_stage)
			main.selected_stage = start_stage
		elif a.begins_with("--gold="):
			main.gold = int(a.substr(7))
		elif a.begins_with("--shot-every="):
			shot_every = float(a.substr(13))
	if shots_dir != "":
		DirAccess.make_dir_recursive_absolute(shots_dir)
	main.dlog("autoplay on: duration=%.0fs stage=%d god=%s gold=%d" % [duration, start_stage, god, main.gold])


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

	var st: int = main.state
	if st != main.State.PLAYING:
		_move(0.0)
	wait_t += delta
	match st:
		main.State.TITLE:
			if elapsed > 1.5:
				main.goto_lobby()
				wait_t = 0.0
		main.State.LOBBY:
			_first_shot("lobby")
			if wait_t > 1.2:
				wait_t = 0.0
				if _cheapest_affordable() != "":
					main.menu.activate("shop")
				else:
					main.selected_stage = main.unlocked if start_stage == 0 else start_stage
					start_stage = 0
					main.menu.activate("play")
		main.State.SHOP:
			_first_shot("shop")
			if wait_t > 0.6:
				wait_t = 0.0
				var id := _cheapest_affordable()
				if id != "":
					main.menu.activate("buy:" + id)
				else:
					main.menu.activate("back")
		main.State.UPGRADE:
			if main.upgrade_t > 1.2 and not manual_pick:
				_first_shot("upgrade", true)
				main.choose_upgrade(randi() % main.upgrade_choices.size())
		main.State.STAGE_CLEAR:
			_first_shot("clear", true)
			if wait_t > 2.5:
				wait_t = 0.0
				main.menu.activate("lobby")
		main.State.GAMEOVER:
			_first_shot("gameover", true)
			if wait_t > 3.0:
				wait_t = 0.0
				main.menu.activate("lobby")
		main.State.PLAYING:
			wait_t = 0.0
			if suicide_at > 0.0 and elapsed >= suicide_at:
				suicide_at = -1.0
				main.dino.invuln = 0.0
				main.dino.god = false
				main.dino.hurt(99999.0)
			if main.boss:
				_first_shot("boss_%d" % main.boss.kind)
			for h in main.hazards.items:
				if h.k == "laser" and h.t > h.warn + 0.1:
					_first_shot("laser")
				elif h.k == "quake" and h.t > 0.25:
					_first_shot("quake")
			for e in main.helis:
				var nm: String = e.get_script().resource_path.get_file().get_basename()
				if nm != "heli" and nm != "boss" and e.position.x > 100 and e.position.x < main.view.x - 100:
					_first_shot("enemy_" + nm)
			for e in main.tanks:
				if e != main.boss and e.position.x > 100 and e.position.x < main.view.x - 100 and str(e.kind) in ["rocket", "armored"]:
					_first_shot("enemy_" + str(e.kind))
			_think()

	if elapsed >= next_log:
		next_log += 2.0
		var d = main.dino
		var boss_txt := ""
		if main.boss:
			boss_txt = " boss=%s(%.0f/%.0f,%s)" % [main.boss.boss_name, main.boss.hp, main.boss.max_hp, main.boss.state]
		main.dlog("state=%s stage=%d wave=%d hp=%.0f/%.0f roar=%.0f score=%d kills=%d gold=%d+%d enemies=%d/%d shells=%d fx=%d nodes=%d fps=%.0f%s" % [
			main.State.keys()[st], main.stage, main.wave, d.hp, d.max_hp, d.roar_meter, main.score, main.kills, main.gold, main.run_gold,
			main.tanks.size(), main.helis.size(), main.shells.size(), main.fx.parts.size(), Performance.get_monitor(Performance.OBJECT_NODE_COUNT), frames / max(fps_acc, 0.001), boss_txt])
		frames = 0
		fps_acc = 0.0
	if shots_dir != "" and elapsed >= next_shot:
		next_shot += shot_every
		_screenshot()
	if elapsed >= duration:
		main.dlog("autoplay finished: gold=%d unlocked=%d meta=%s" % [main.gold, main.unlocked, main.meta])
		get_tree().quit()


func _cheapest_affordable() -> String:
	var Meta = preload("res://scripts/meta.gd")
	var best_id := ""
	var best_c := 1 << 30
	for u in Meta.LIST:
		var lvl: int = main.meta.get(u.id, 0)
		if lvl >= u.max:
			continue
		var c: int = Meta.cost(u, lvl)
		if c <= main.gold and c < best_c:
			best_c = c
			best_id = u.id
	return best_id


func _first_shot(key: String, delayed := false) -> void:
	if shots_dir == "" or shot_states.has(key):
		return
	if delayed and wait_t < 1.0 and main.state != main.State.UPGRADE:
		return
	shot_states[key] = true
	_screenshot(key)


func _screenshot(tag := "") -> void:
	var img := get_viewport().get_texture().get_image()
	if img == null:
		return
	shot_n += 1
	if tag == "":
		tag = main.State.keys()[main.state].to_lower()
	var path := "%s/shot_%03d_s%d_%s.png" % [shots_dir, shot_n, main.stage, tag]
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

	# 0) 보스 패턴(지진파/레이저): 점프로 피한다
	if d.on_ground and main.hazards.threat_for(px) != "":
		_tap("jump")

	# 1) 날아오는 포탄: 가까우면 그쪽을 보고 문다
	for s in main.shells:
		if s.dead or s.reflected:
			continue
		var dx: float = s.position.x - px
		var dy: float = s.position.y - (d.position.y - 90.0)
		if abs(dx) < 190.0 and abs(dy) < 200.0 and (sign(s.vel.x) != sign(dx) or abs(s.vel.x) < 80.0):
			var face: float = sign(dx) if dx != 0.0 else d.facing
			if face != d.facing:
				_move(face)
				return
			_tap("bite")
			return

	# 2) 포효: 적이 2기 이상이거나 보스가 있으면
	if d.roar_meter >= 100.0 and (main.tanks.size() + main.helis.size() >= 2 or main.boss):
		_tap("roar")

	# 3) 가장 가까운 적에게 접근 (탈출하는 폭격기 제외)
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
		if h.dead or h.get("escaped") != null:
			continue
		var dist: float = abs(h.position.x - px) + 120.0
		if dist < best:
			best = dist
			target = h
	if target == null:
		_move(sign(main.view.x * 0.5 - px) if abs(main.view.x * 0.5 - px) > 40.0 else 0.0)
		return
	var tdx: float = target.position.x - px
	if main.helis.has(target):
		_move(sign(tdx) if abs(tdx) > 40.0 else 0.0)
		if abs(tdx) < 130.0 and d.on_ground:
			_tap("jump")
		if not d.on_ground and d.vel.y > -250.0:
			_tap("bite")
		return
	var reach: float = target.half_w + 90.0
	if abs(tdx) > reach:
		_move(sign(tdx))
		# 가끔 점프해서 밟기 시도 (장갑 전차와 보스는 더 자주)
		var p_jump := 0.06 if (target == main.boss or str(target.get("kind")) == "armored") else 0.02
		if abs(tdx) < reach + 120.0 and d.on_ground and randf() < p_jump:
			_tap("jump")
	else:
		_move(0.0)
		if sign(tdx) != d.facing and tdx != 0.0:
			_move(sign(tdx))
		else:
			_tap("bite")
			if str(target.get("kind")) == "armored" and d.on_ground and randf() < 0.05:
				_tap("jump")
