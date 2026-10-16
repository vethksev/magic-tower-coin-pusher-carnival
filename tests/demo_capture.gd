extends SceneTree
## 用真 renderer 開主場景、發 20 幣、等 6 秒、截圖到 .godot/qa/phase0.png。
## 要唔加 --headless 跑；會短暫彈一個視窗。


func _initialize() -> void:
	run()


func run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://.godot/qa"))
	var main: Node = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	for _i in range(10):
		await process_frame
	for i in range(20):
		main.call("demo_fire", i % 2)
		for _t in range(16):
			await physics_frame
	for _t in range(360):
		await physics_frame
	await process_frame
	await process_frame
	var img: Image = root.get_viewport().get_texture().get_image()
	var path: String = ProjectSettings.globalize_path("res://.godot/qa/phase0.png")
	var err: int = img.save_png(path)
	print("capture %s -> %s (%dx%d)" % ["ok" if err == OK else "FAILED", path, img.get_width(), img.get_height()])
	quit(0 if err == OK else 1)
