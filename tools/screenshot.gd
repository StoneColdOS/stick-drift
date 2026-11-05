extends SceneTree
## Renders a few frames and saves screenshots (used to check the look without a phone).
## Run: xvfb-run godot --rendering-driver opengl3 --resolution 1560x720 --path . -s res://tools/screenshot.gd

func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await _secs(1.0)
	await _shot("docs/screenshots/parked.png")
	main.touch.snap_to_gear(1)
	await _secs(1.5)
	main.touch.snap_to_gear(2)
	await _secs(1.2)
	Input.action_press("steer_right")
	await _secs(0.4)
	Input.action_release("steer_right")
	Input.action_press("steer_left", 0.4)
	await _secs(0.6)
	await _shot("docs/screenshots/drift.png")
	Input.action_release("steer_left")
	quit()


func _secs(s: float) -> void:
	for i in int(s * 60):
		await process_frame


func _shot(path: String) -> void:
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://docs/screenshots"))
	root.get_texture().get_image().save_png("res://" + path)
	print("saved ", path)
