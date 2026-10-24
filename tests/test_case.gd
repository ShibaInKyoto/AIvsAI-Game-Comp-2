class_name TestCase
extends RefCounted
## Minimal xUnit-style base class. Test methods start with "test_"; use the
## assert helpers, which record failures instead of aborting the run.

var failures: PackedStringArray = []
var _current := ""


func run_all() -> Dictionary:
	var passed := 0
	var failed := 0
	for m in get_method_list():
		var method: String = m.name
		if not method.begins_with("test_"):
			continue
		_current = method
		var before := failures.size()
		call(method)
		if failures.size() == before:
			passed += 1
		else:
			failed += 1
	return {"passed": passed, "failed": failed}


func check(condition: bool, message := "") -> void:
	if not condition:
		failures.append("%s: %s" % [_current, message if message != "" else "assertion failed"])


func check_eq(actual: Variant, expected: Variant, message := "") -> void:
	if actual != expected:
		failures.append("%s: expected %s, got %s %s" % [_current, str(expected), str(actual), message])


func check_near(actual: float, expected: float, tolerance: float, message := "") -> void:
	if absf(actual - expected) > tolerance:
		failures.append("%s: expected %f +- %f, got %f %s" % [_current, expected, tolerance, actual, message])
