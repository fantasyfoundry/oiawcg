extends SceneTree

func _initialize() -> void:
	call_deferred("run_tests")

func run_tests() -> void:
	var match_scene = load("res://main.tscn").instantiate()
	root.add_child(match_scene)
	match_scene.set_physics_process(false)
	match_scene.start_match()
	# The side camera preserves the long axis but compresses rink depth.
	var far_left: Vector2 = match_scene.ice_to_screen(Vector2(80, 210))
	var far_right: Vector2 = match_scene.ice_to_screen(Vector2(1920, 210))
	var near_left: Vector2 = match_scene.ice_to_screen(Vector2(80, 710))
	var near_right: Vector2 = match_scene.ice_to_screen(Vector2(1920, 710))
	assert(far_left.y == far_right.y and near_left.y == near_right.y, "Rink axis stays horizontal")
	assert(near_left.y > far_left.y and near_left.y - far_left.y < 250, "Low side camera compresses depth")
	assert(near_right.x - near_left.x > far_right.x - far_left.x, "Perspective narrows the far side")
	assert(match_scene.skaters.size() == 8, "Both teams must spawn")
	assert(match_scene.kit_frames[0].size() == 8 and match_scene.kit_frames[1].size() == 8, "Both uniforms have eight skating frames")
	assert(match_scene.kit_idle[0].get_height() >= 100, "Detailed full-height sprite imports")
	# The old rink edge must no longer block a puck travelling through the new centre.
	match_scene.puck = Vector2(879, 460)
	match_scene.puck_velocity = Vector2(300, 0)
	match_scene.advance_puck(0.1)
	assert(match_scene.puck.x > 900 and match_scene.scores == [0, 0], "No obsolete invisible end board")
	# Camera eases toward action, then stops at both ends of the rink.
	match_scene.puck.x = 1910
	match_scene.skaters[match_scene.selected].pos.x = 1830
	var camera_before: float = match_scene.camera_x
	match_scene.update_camera(1.0 / 60)
	assert(match_scene.camera_x > camera_before and match_scene.camera_x < 1560, "Camera scrolls smoothly")
	for tick in range(240):
		match_scene.update_camera(1.0 / 60)
	assert(absf(match_scene.camera_x - 1560) < 1, "Right camera boundary")
	assert(match_scene.ice_to_screen(Vector2(1920, 460)).x < 960, "Right goal stays visible")
	match_scene.puck.x = 90
	match_scene.skaters[match_scene.selected].pos.x = 140
	for tick in range(240):
		match_scene.update_camera(1.0 / 60)
	assert(absf(match_scene.camera_x - 440) < 1, "Left camera boundary")
	assert(match_scene.ice_to_screen(Vector2(80, 460)).x > 0, "Left goal stays visible")
	match_scene.reset_faceoff()
	match_scene.holder = 1
	match_scene.puck = match_scene.skaters[1].pos
	match_scene.shoot(1)
	assert(match_scene.holder == -1 and match_scene.puck_velocity.x > 0, "Boston shot heads right")
	match_scene.holder = 1
	match_scene.pass_puck(1)
	assert(match_scene.holder == -1 and match_scene.selected != 1, "Pass changes controlled teammate")
	match_scene.reset_faceoff()
	match_scene.puck = Vector2(1919, 460)
	match_scene.puck_velocity = Vector2(620, 0)
	match_scene.advance_puck(0.03)
	assert(match_scene.scores == [1, 0], "Right net counts Boston goal")
	match_scene.puck = Vector2(81, 460)
	match_scene.puck_velocity = Vector2(-620, 0)
	match_scene.advance_puck(0.03)
	assert(match_scene.scores == [1, 1], "Left net counts Montreal goal")
	match_scene.puck = Vector2(1919, 300)
	match_scene.puck_velocity = Vector2(620, 0)
	match_scene.advance_puck(0.03)
	assert(match_scene.puck_velocity.x < 0 and match_scene.scores == [1, 1], "Outside net bounces")
	match_scene.reset_faceoff()
	match_scene.pickup_delay = 0
	match_scene.puck = match_scene.skaters[0].pos
	match_scene.step_match(1.0 / 60)
	assert(match_scene.holder == 0 and match_scene.selected == 0, "Pickup selects Boston carrier")
	match_scene.mode = "paused"
	var time_before: float = match_scene.remaining
	match_scene._physics_process(1)
	assert(match_scene.remaining == time_before, "Pause freezes clock")
	match_scene.mode = "play"
	match_scene.remaining = 0.01
	match_scene._physics_process(0.02)
	assert(match_scene.mode == "over", "Clock ends match")
	match_scene.start_match()
	# At full speed, a push/glide cycle must take longer than one second.
	match_scene.skaters[4].vel = Vector2(-205, 0)
	match_scene.skaters[4].effort = 1.0
	match_scene.skaters[4].phase = 0.0
	match_scene.step_match(0.1)
	assert(match_scene.skaters[4].phase > 0 and match_scene.skaters[4].phase < 0.1, "Skating cadence stays under one cycle per second")
	var paused_phase: float = match_scene.skaters[4].phase
	match_scene.mode = "paused"
	match_scene._physics_process(0.3)
	assert(match_scene.skaters[4].phase == paused_phase, "Pause freezes skating animation")
	match_scene.start_match()
	for tick in range(3600):
		match_scene._physics_process(1.0 / 60)
		assert(is_finite(match_scene.puck.x) and is_finite(match_scene.puck.y), "Finite puck state")
	print("PASS: detailed sprite imports, expanded rink, side projection, camera tracking and limits, slow animation, shooting, passing, both goals, boards, pickup, pause, clock and 60-second simulation")
	quit()
