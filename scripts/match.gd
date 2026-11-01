extends Node2D
## All positions are on the ice plane; rendering adds height to each skater.
const RINK := Rect2(80, 210, 800, 280)
const CENTER := Vector2(480, 350)
const GOAL_TOP := 318.0
const GOAL_BOTTOM := 382.0
const SPEED := 150.0
const MATCH_LENGTH := 180.0
var skaters: Array[Dictionary] = []
var puck := CENTER
var puck_velocity := Vector2.ZERO
var holder := -1
var selected := 0
var pickup_delay := 0.0
var ai_timer := 0.0
var scores := [0, 0]
var remaining := MATCH_LENGTH
var mode := "menu"
var banner := ""
var banner_time := 0.0
var elapsed := 0.0
var font: Font = ThemeDB.fallback_font

func _ready() -> void:
	reset_faceoff()

func reset_faceoff() -> void:
	skaters.clear()
	for team in range(2):
		for slot in range(4):
			var x := 355.0 if team == 0 else 605.0
			var y := 265.0 + slot * 75.0
			if slot == 3:
				x = 113.0 if team == 0 else 847.0
				y = 350.0
			skaters.append({"pos": Vector2(x, y), "vel": Vector2.ZERO,
				"team": team, "slot": slot, "face": Vector2.RIGHT if team == 0 else Vector2.LEFT})
	selected = 1
	puck = CENTER
	puck_velocity = Vector2.ZERO
	holder = -1
	pickup_delay = 0.6
	ai_timer = 0.0

func start_match() -> void:
	scores = [0, 0]
	remaining = MATCH_LENGTH
	mode = "play"
	banner = "Vhadzovanie"
	banner_time = 1.2
	reset_faceoff()

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	var key := event.keycode as Key
	if key == KEY_ENTER and mode in ["menu", "over"]:
		start_match()
	elif key == KEY_ESCAPE and mode in ["play", "paused"]:
		mode = "paused" if mode == "play" else "play"
	elif key == KEY_R and mode in ["play", "paused", "over"]:
		start_match()
	elif mode == "play":
		if key == KEY_SPACE:
			shoot(selected)
		elif key == KEY_C:
			if holder == selected:
				pass_puck(selected)
			else:
				switch_player()
		elif key == KEY_X:
			poke_check()

func switch_player() -> void:
	var previous := selected
	var best := INF
	for i in range(3):
		var distance: float = skaters[i].pos.distance_squared_to(puck)
		if i != previous and distance < best:
			best = distance
			selected = i

func release_puck(index: int, direction: Vector2, power: float) -> void:
	if holder != index:
		return
	puck = skaters[index].pos + direction.normalized() * 23.0
	puck_velocity = direction.normalized() * power
	holder = -1
	pickup_delay = 0.18

func shoot(index: int) -> void:
	if holder != index:
		return
	var target := Vector2(891 if skaters[index].team == 0 else 69, 350)
	release_puck(index, target - skaters[index].pos, 620.0)

func pass_puck(index: int) -> void:
	if holder != index:
		return
	var target := -1
	var best := INF
	for i in range(skaters.size()):
		if i == index or skaters[i].team != skaters[index].team or skaters[i].slot == 3:
			continue
		var distance: float = skaters[index].pos.distance_squared_to(skaters[i].pos)
		if distance < best:
			best = distance
			target = i
	if target >= 0:
		release_puck(index, skaters[target].pos - skaters[index].pos, 370.0)
		if skaters[index].team == 0:
			selected = target

func poke_check() -> void:
	if holder >= 0 and skaters[holder].team == 1 and skaters[selected].pos.distance_to(puck) < 43:
		var direction: Vector2 = (puck - skaters[selected].pos).normalized()
		release_puck(holder, direction, 190.0)

func _physics_process(delta: float) -> void:
	elapsed += delta
	if mode == "play":
		remaining = maxf(0, remaining - delta)
		banner_time = maxf(0, banner_time - delta)
		if remaining <= 0:
			mode = "over"
		else:
			step_match(delta)
	queue_redraw()

func step_match(delta: float) -> void:
	pickup_delay = maxf(0, pickup_delay - delta)
	ai_timer += delta
	var input_dir := Vector2(float(Input.is_physical_key_pressed(KEY_RIGHT)) - float(Input.is_physical_key_pressed(KEY_LEFT)),
		float(Input.is_physical_key_pressed(KEY_DOWN)) - float(Input.is_physical_key_pressed(KEY_UP))).normalized()
	for i in range(skaters.size()):
		var s: Dictionary = skaters[i]
		var direction := Vector2.ZERO
		if i == selected:
			direction = input_dir
		else:
			var target: Vector2 = s.pos
			var attack := 1.0 if s.team == 0 else -1.0
			if s.slot == 3:
				target = Vector2(113 if s.team == 0 else 847, clampf(puck.y, 324, 376))
			elif holder == i:
				target = Vector2(780 if s.team == 0 else 180, 350)
				if absf(s.pos.x - target.x) < 105 and ai_timer > 0.8:
					shoot(i)
					ai_timer = 0.0
			elif holder < 0 or skaters[holder].team != s.team:
				var nearest := nearest_skater(s.team, puck)
				if nearest == i:
					target = puck
				else:
					target = Vector2(clampf(puck.x - attack * 110, 180, 780), 265 + s.slot * 80)
			else:
				target = Vector2(clampf(puck.x + attack * 110, 180, 780), 265 + s.slot * 80)
			if s.pos.distance_to(target) > 6:
				direction = s.pos.direction_to(target)
		var speed := SPEED if i == selected else SPEED * 0.83
		s.vel = s.vel.move_toward(direction * speed, (480.0 if direction != Vector2.ZERO else 220.0) * delta)
		s.pos += s.vel * delta
		s.pos.x = clampf(s.pos.x, RINK.position.x + 17, RINK.end.x - 17)
		s.pos.y = clampf(s.pos.y, RINK.position.y + 18, RINK.end.y - 12)
		if direction != Vector2.ZERO:
			s.face = direction
	# Separate bodies on the ice plane, independently of sprite height.
	for i in range(skaters.size()):
		for j in range(i + 1, skaters.size()):
			var offset: Vector2 = skaters[j].pos - skaters[i].pos
			if offset.length() < 19:
				var push := offset.normalized() * (19 - offset.length()) * 0.5
				skaters[i].pos -= push
				skaters[j].pos += push
	if holder >= 0:
		puck = skaters[holder].pos + skaters[holder].face * 16
	else:
		advance_puck(delta)
		if pickup_delay <= 0:
			var nearest := -1
			var best := 22.0
			for i in range(skaters.size()):
				var distance: float = skaters[i].pos.distance_to(puck)
				if distance < best:
					best = distance
					nearest = i
			if nearest >= 0:
				holder = nearest
				puck_velocity = Vector2.ZERO
				if skaters[nearest].team == 0 and skaters[nearest].slot != 3:
					selected = nearest
				elif skaters[nearest].slot == 3:
					# Goalies clear immediately; the player controls outfield skaters.
					release_puck(nearest, Vector2(1 if skaters[nearest].team == 0 else -1, 0.5), 280)

func nearest_skater(team: int, point: Vector2) -> int:
	var result := -1
	var distance := INF
	for i in range(skaters.size()):
		if skaters[i].team == team and skaters[i].slot != 3:
			var d: float = skaters[i].pos.distance_squared_to(point)
			if d < distance:
				distance = d
				result = i
	return result

func advance_puck(delta: float) -> void:
	# Substeps keep fast shots from tunnelling through boards or goal mouths.
	var steps := maxi(1, ceili(puck_velocity.length() * delta / 5.0))
	for substep in range(steps):
		puck += puck_velocity * delta / steps
		if puck.y < RINK.position.y + 4 or puck.y > RINK.end.y - 4:
			puck.y = clampf(puck.y, RINK.position.y + 4, RINK.end.y - 4)
			puck_velocity.y *= -0.8
		if puck.x < RINK.position.x or puck.x > RINK.end.x:
			if puck.y > GOAL_TOP and puck.y < GOAL_BOTTOM:
				score_goal(0 if puck.x > CENTER.x else 1)
				return
			puck.x = clampf(puck.x, RINK.position.x, RINK.end.x)
			puck_velocity.x *= -0.8
	puck_velocity = puck_velocity.move_toward(Vector2.ZERO, 38 * delta)

func score_goal(team: int) -> void:
	scores[team] += 1
	banner = "GÓL!  " + ("BOSTON" if team == 0 else "MONTREAL")
	banner_time = 2.0
	reset_faceoff()

func text_at(value: String, point: Vector2, size: int, color := Color("efe5cb")) -> void:
	draw_string(font, point, value, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)

func centered(value: String, y: float, size: int, color := Color("efe5cb")) -> void:
	text_at(value, Vector2((960 - font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x) / 2, y), size, color)

func _draw() -> void:
	draw_rect(Rect2(0, 0, 960, 600), Color("142831"))
	# Distant pines, snow and wooden terraces; all art is generated locally.
	for i in range(26):
		var x := float(i * 41 - 25)
		var height := 35.0 + float((i * 17) % 45)
		draw_colored_polygon(PackedVector2Array([Vector2(x, 160), Vector2(x + 21, 160 - height), Vector2(x + 42, 160)]), Color("234049"))
	draw_rect(Rect2(30, 160, 900, 360), Color("bfcbc3"))
	for i in range(60):
		var x := 40 + i * 15
		draw_rect(Rect2(x, 174, 12, 24), Color("6b5040"))
		draw_rect(Rect2(x + 3, 165 + (i % 3) * 3, 6, 7), Color("bc9879"))
	draw_rect(Rect2(65, 198, 830, 306), Color("684d39"))
	draw_rect(Rect2(70, 201, 820, 297), Color("decfae"))
	draw_rect(RINK, Color("d7e8df"))
	for i in range(32):
		var a := Vector2(100 + (i * 97) % 760, 225 + (i * 43) % 245)
		draw_line(a, a + Vector2(14, -3), Color("bfd6cf"), 1)
	# No modern blue lines: this is an early gameplay sketch, not a rules simulation.
	draw_line(Vector2(480, 211), Vector2(480, 489), Color("ab6a62"), 2)
	draw_arc(CENTER, 46, 0, TAU, 48, Color("ab6a62"), 2)
	draw_circle(CENTER, 4, Color("ab6a62"))
	for x in [235, 725]:
		for y in [275, 425]:
			draw_arc(Vector2(x, y), 25, 0, TAU, 32, Color("a6bdb5"), 1)
	for x in [58, 880]:
		draw_rect(Rect2(x, GOAL_TOP, 22, 64), Color("bac6b6"))
		for y in range(320, 382, 8):
			draw_line(Vector2(x, y), Vector2(x + 22, y), Color("6c7d73"), 1)
		draw_rect(Rect2(x, GOAL_TOP, 22, 64), Color("935440"), false, 3)
	var order: Array[int] = []
	for i in range(skaters.size()):
		order.append(i)
	order.sort_custom(func(a: int, b: int) -> bool: return skaters[a].pos.y < skaters[b].pos.y)
	for i in order:
		draw_skater(i)
	draw_circle(puck + Vector2(0, 2), 5, Color("9bb4ab"))
	draw_rect(Rect2(puck - Vector2(4, 2), Vector2(8, 4)), Color("1b292d"))
	draw_rect(Rect2(0, 0, 960, 112), Color("101f27"))
	text_at("ON ICE", Vector2(30, 40), 29)
	text_at("A WINTER CLASSIC", Vector2(32, 64), 11, Color("a9bdb6"))
	text_at("1924 — 1927  /  PROTOTYP 0.1", Vector2(32, 88), 10, Color("d1ae68"))
	centered("BOSTON    %d  :  %d    MONTREAL" % [scores[0], scores[1]], 47, 24)
	var seconds := ceili(remaining)
	centered("TRÉNING  •  %02d:%02d" % [seconds / 60, seconds % 60], 78, 14, Color("a9bdb6"))
	text_at("3 + BRANKÁR", Vector2(805, 43), 13)
	text_at("ÚTOK  →", Vector2(812, 69), 13, Color("d1ae68"))
	centered("ŠÍPKY  pohyb     C  prihrávka / zmena hráča     MEDZERNÍK  strela     X  vypichnutie", 551, 14)
	centered("ESC  pauza     R  nový zápas   •   Dobové pravidlá a plné zostavy pripravujeme", 578, 12, Color("9aafa9"))
	if banner_time > 0 and mode == "play":
		centered(banner, 143, 22, Color("f0cf84"))
	if mode != "play":
		draw_rect(Rect2(160, 245, 640, 194), Color(0.04, 0.10, 0.13, 0.96))
		var title := "ZIMNÁ KLASIKA"
		var subtitle := "Boston proti Montrealu • skúšobné vonkajšie klzisko"
		var prompt := "ENTER  začať zápas"
		if mode == "paused":
			title = "PRESTÁVKA"
			subtitle = "Zápas je pozastavený"
			prompt = "ESC  pokračovať     R  nový zápas"
		elif mode == "over":
			title = "KONIEC ZÁPASU"
			subtitle = "Boston %d : %d Montreal" % [scores[0], scores[1]]
			prompt = "ENTER  odveta"
		centered(title, 294, 32)
		centered(subtitle, 334, 17, Color("a9bdb6"))
		centered(prompt, 386, 19, Color("f0cf84"))

func draw_skater(index: int) -> void:
	var s: Dictionary = skaters[index]
	var p: Vector2 = s.pos.round()
	var jersey := Color("b58b36") if s.team == 0 else Color("a53c38")
	var trim := Color("2b2929") if s.team == 0 else Color("ebe0c6")
	if index == selected:
		draw_arc(p + Vector2(0, 3), 14, 0, TAU, 20, Color("c48f3b"), 2)
		draw_colored_polygon(PackedVector2Array([p + Vector2(-5, -48), p + Vector2(5, -48), p + Vector2(0, -41)]), Color("d3a34a"))
	draw_set_transform(p + Vector2(0, 2), 0, Vector2(1, 0.35))
	draw_circle(Vector2.ZERO, 12, Color(0.15, 0.26, 0.24, 0.22))
	draw_set_transform(Vector2.ZERO)
	var stride := sin(elapsed * 15 + index) * 3 if s.vel.length() > 15 else 0.0
	for side in [-1, 1]:
		draw_rect(Rect2(p + Vector2(side * 4 - 3, -11), Vector2(5, 10 + stride * side)), trim)
		draw_rect(Rect2(p + Vector2(side * 4 - 4, stride * side), Vector2(9, 3)), Color("333b38"))
		draw_line(p + Vector2(side * 4 - 4, 4 + stride * side), p + Vector2(side * 4 + 6, 4 + stride * side), Color("80908b"), 1)
	draw_rect(Rect2(p + Vector2(-9, -29), Vector2(18, 19)), jersey)
	draw_rect(Rect2(p + Vector2(-9, -18), Vector2(18, 4)), trim)
	draw_rect(Rect2(p + Vector2(-12, -27), Vector2(5, 13)), jersey)
	draw_rect(Rect2(p + Vector2(8, -27), Vector2(5, 13)), jersey)
	draw_rect(Rect2(p + Vector2(-12, -16), Vector2(5, 5)), Color("5c4937"))
	draw_rect(Rect2(p + Vector2(8, -16), Vector2(5, 5)), Color("5c4937"))
	draw_rect(Rect2(p + Vector2(-6, -39), Vector2(12, 11)), Color("cda17e"))
	draw_rect(Rect2(p + Vector2(-6, -40), Vector2(12, 4)), Color("503e31"))
	var stick_side := 1.0 if s.face.x >= 0 else -1.0
	draw_line(p + Vector2(stick_side * 10, -14), p + Vector2(stick_side * 22, 6), Color("785638"), 3)
	draw_line(p + Vector2(stick_side * 22, 6), p + Vector2(stick_side * 31, 6), Color("785638"), 3)
