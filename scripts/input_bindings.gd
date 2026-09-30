extends RefCounted
## Only physical, unmodified keyboard keys are accepted. Escape always cancels.
const DEFAULTS = {"move_left":KEY_A,"move_right":KEY_D,"move_up":KEY_W,"move_down":KEY_S,"dash":KEY_SPACE,"reload":KEY_R,"skill":KEY_E,"skill_2":KEY_Q,"skill_3":KEY_F,"skill_4":KEY_C,"item_1":KEY_1,"item_2":KEY_2,"item_3":KEY_3,"interact":KEY_G,"map":KEY_M}
const NAMES = {"move_left":"向左","move_right":"向右","move_up":"向上","move_down":"向下","dash":"闪避","reload":"换弹","skill":"技能一","skill_2":"技能二","skill_3":"技能三","skill_4":"技能四","item_1":"道具槽一","item_2":"道具槽二","item_3":"道具槽三","interact":"交互 / 安全整备","map":"探索地图"}
var keys: Dictionary = DEFAULTS.duplicate()
func apply() -> void:
	for action in keys:
		if not InputMap.has_action(action): InputMap.add_action(action)
		InputMap.action_erase_events(action)
		var event = InputEventKey.new()
		event.physical_keycode = int(keys[action])
		InputMap.action_add_event(action,event)
func conflict(action: String, key: int) -> String:
	for other in keys:
		if other!=action and int(keys[other])==key: return other
	return ""
func bind_key(action: String, key: int, swap: bool = false) -> bool:
	if not keys.has(action) or key in [0,KEY_ESCAPE,KEY_TAB,KEY_SHIFT,KEY_CTRL,KEY_ALT,KEY_META]: return false
	var other = conflict(action,key)
	if not other.is_empty():
		if not swap: return false
		keys[other] = keys[action]
	keys[action] = key
	apply()
	return true
func load_config(config: ConfigFile) -> void:
	var candidate: Dictionary = DEFAULTS.duplicate()
	var used: Array = []
	# Load existing bindings first; newly added actions must not erase an old custom key.
	for action in candidate:
		if not config.has_section_key("bindings",action): continue
		var key = int(config.get_value("bindings",action,DEFAULTS[action]))
		if key<=0 or key in used or key in [KEY_ESCAPE,KEY_TAB]: return
		used.append(key)
		candidate[action] = key
	for action in candidate:
		if config.has_section_key("bindings",action): continue
		var desired: int = DEFAULTS[action]
		if desired in used:
			for fallback in [KEY_G,KEY_M,KEY_H,KEY_J,KEY_K,KEY_L,KEY_B,KEY_N,KEY_V,KEY_T,KEY_Y,KEY_U,KEY_I,KEY_O,KEY_P]:
				if fallback not in used: desired = fallback; break
		candidate[action] = desired
		used.append(desired)
	keys = candidate
	apply()
func save_config(config: ConfigFile) -> void:
	for action in keys: config.set_value("bindings",action,keys[action])
func text(action: String) -> String:
	return OS.get_keycode_string(int(keys.get(action,0)))
