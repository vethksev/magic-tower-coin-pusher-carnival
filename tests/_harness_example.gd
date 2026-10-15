extends SceneTree

var checks: int = 0
var failures: int = 0


func _initialize() -> void:
	check(1 + 1 == 2, "harness sanity")
	print("Harness: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)


func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("FAILED: " + message)
