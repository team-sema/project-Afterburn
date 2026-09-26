extends RefCounted
## Project code loader for the development Lab, not an untrusted-code sandbox.

static func load_pattern(path: String) -> Dictionary:
	path = path.strip_edges().simplify_path()
	if not path.begins_with("res://") or path.get_extension().to_lower() != "gd" or path.contains(".."):
		return {"error": "프로젝트 안의 res://...gd 경로를 입력하세요."}
	if not FileAccess.file_exists(path):
		return {"error": "파일이 없습니다: " + path}
	var script = ResourceLoader.load(path, "GDScript", ResourceLoader.CACHE_MODE_IGNORE)
	if not script is GDScript:
		return {"error": "스크립트를 읽지 못했습니다. 문법 오류는 Output도 확인하세요."}
	script.source_code = FileAccess.get_file_as_string(path)
	if script.reload() != OK or not script.can_instantiate():
		return {"error": "스크립트 컴파일 실패. 문법 오류는 Output을 확인하세요."}
	var base: Script = script
	while base != null and base != preload("res://projectiles/barrage_sequence.gd"):
		base = base.get_base_script()
	if base == null:
		return {"error": "extends BarrageSequence가 필요합니다."}
	for method in script.get_script_method_list():
		if method.name == "_init" and method.args.size() > method.default_args.size():
			return {"error": "_init에는 필수 인자를 둘 수 없습니다."}
	var sequence = script.new()
	if not sequence is BarrageSequence:
		return {"error": "패턴을 생성하지 못했습니다."}
	# The Lab has no enemy scene, so build() sees an empty Dictionary and must use defaults.
	sequence.build({})
	var error: String = sequence.validation_error()
	if not error.is_empty(): return {"error": error}
	return {"error": "", "sequence": sequence.snapshot(), "path": path}

static func list_patterns(directory := "res://patterns") -> PackedStringArray:
	var result := PackedStringArray()
	for name in DirAccess.get_files_at(directory):
		if name.ends_with(".gd"): result.append(directory.path_join(name))
	for name in DirAccess.get_directories_at(directory):
		result.append_array(list_patterns(directory.path_join(name)))
	result.sort()
	return result
