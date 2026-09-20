class_name TemporalBindings
extends RefCounted
## Shared input registration and conflict checks; gameplay never replaces a rebind.

const DEFAULTS := {&"focus": KEY_F, &"rewind": KEY_G}
const SETTINGS_PATH := "user://temporal_bindings.cfg"

static func ensure_actions() -> void:
	var settings := ConfigFile.new()
	settings.load(SETTINGS_PATH)
	for action: StringName in DEFAULTS:
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action)
		var event := InputEventKey.new()
		event.physical_keycode = int(settings.get_value("keys", action, DEFAULTS[action]))
		InputMap.action_add_event(action, event)


static func conflicts(action: StringName) -> Array[StringName]:
	var result: Array[StringName] = []
	if not InputMap.has_action(action):
		return result
	for other: StringName in InputMap.get_actions():
		if other == action or String(other).begins_with("ui_"):
			continue
		for event in InputMap.action_get_events(action):
			if InputMap.action_has_event(other, event) and other not in result:
				result.append(other)
	return result


static func rebind_key(action: StringName, key: Key, persist: bool = true) -> bool:
	if action not in DEFAULTS or key == KEY_NONE:
		return false
	ensure_actions()
	var event := InputEventKey.new()
	event.physical_keycode = key
	for other: StringName in InputMap.get_actions():
		if other != action and not String(other).begins_with("ui_") and InputMap.action_has_event(other, event):
			return false
	var settings := ConfigFile.new()
	if persist:
		settings.load(SETTINGS_PATH)
		settings.set_value("keys", action, key)
		if settings.save(SETTINGS_PATH) != OK:
			return false
	Input.action_release(action)
	InputMap.action_erase_events(action)
	InputMap.action_add_event(action, event)
	return true


static func label(action: StringName) -> String:
	if not InputMap.has_action(action):
		return ""
	var labels: PackedStringArray = []
	for event in InputMap.action_get_events(action):
		labels.append(event.as_text().replace(" (Physical)", ""))
	return " / ".join(labels)
