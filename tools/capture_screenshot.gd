extends SceneTree

func _initialize() -> void:
	call_deferred("_capture")

func _capture() -> void:
	var packed: PackedScene = load("res://scenes/main.tscn")
	var scene: Node = packed.instantiate()
	root.add_child(scene)

	await process_frame
	await process_frame
	await create_timer(1.2).timeout

	var viewport: Viewport = scene.get_viewport()
	var image: Image = viewport.get_texture().get_image()
	var workspace := OS.get_environment("GITHUB_WORKSPACE")
	if workspace.is_empty():
		workspace = ProjectSettings.globalize_path(".")
	var output_dir := workspace.path_join("artifacts")
	DirAccess.make_dir_recursive_absolute(output_dir)
	var output_path := output_dir.path_join("tinyrush-current.png")
	var err := image.save_png(output_path)
	if err != OK:
		push_error("Screenshot save failed: %s" % error_string(err))
		quit(1)
		return

	print("SCREENSHOT_WRITTEN: ", output_path)
	quit(0)
