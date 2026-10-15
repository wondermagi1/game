extends RefCounted
## Frontier-only save format. Never reads or writes the original 2D save.
const PATH = "user://frontier_journey_v1.json"
const VERSION = 1

static func valid(data: Variant) -> bool:
	if not data is Dictionary or data.get("version") != VERSION: return false
	for key in ["role", "hp", "max_hp", "level", "xp", "coins", "kills", "elapsed", "potions", "runes"]:
		if not data.get(key) is float and not data.get(key) is int: return false
		if not is_finite(float(data[key])): return false
	if data.role < 0 or data.role > 2 or data.role != int(data.role): return false
	if data.hp <= 0 or data.hp > data.max_hp or data.max_hp > 10000: return false
	if data.level < 1 or data.level > 1000 or data.runes < 0 or data.runes > 3: return false
	for key in ["xp", "coins", "kills", "elapsed", "potions"]:
		if data[key] < 0: return false
	for key in ["claimed", "cleared", "discovered", "buffs", "rested"]:
		if not data.get(key) is Dictionary: return false
	for value in data.buffs.values():
		if not value is float and not value is int: return false
		if not is_finite(float(value)) or value < 0 or value > 10000: return false
	if data.cleared.has("boss") or data.claimed.has("boss"): return false
	if not data.get("position") is Array or data.position.size() != 2: return false
	for value in data.position:
		if not value is float and not value is int: return false
		if not is_finite(float(value)) or absf(float(value)) > 61: return false
	if not data.get("cooldowns") is Array or data.cooldowns.size() != 4: return false
	for value in data.cooldowns:
		if not value is float and not value is int: return false
		if not is_finite(float(value)) or value < 0 or value > 60: return false
	return true

static func read_file(path: String = PATH) -> Dictionary:
	# A failed write can leave the previous, valid save in .bak.
	for candidate in [path, path+".bak"]:
		if not FileAccess.file_exists(candidate): continue
		var parser = JSON.new()
		if parser.parse(FileAccess.get_file_as_string(candidate)) != OK: continue
		var data = parser.data
		if valid(data): return data
	return {}

static func write_file(data: Dictionary, path: String = PATH) -> Error:
	if not valid(data): return ERR_INVALID_DATA
	var file = FileAccess.open(path+".tmp", FileAccess.WRITE)
	if file == null: return FileAccess.get_open_error()
	file.store_string(JSON.stringify(data))
	file.flush()
	var error = file.get_error()
	file.close()
	if error != OK: return error
	if FileAccess.file_exists(path):
		if FileAccess.file_exists(path+".bak"):
			error = DirAccess.remove_absolute(path+".bak")
			if error != OK: return error
		error = DirAccess.rename_absolute(path, path+".bak")
		if error != OK: return error
	return DirAccess.rename_absolute(path+".tmp", path)

static func clear_file(path: String = PATH) -> void:
	for suffix in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(path+suffix): DirAccess.remove_absolute(path+suffix)
