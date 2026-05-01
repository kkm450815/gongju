extends Node
## I18N — minimal CSV-backed translator.
## Use I18N.t("KEY") in code. Switch language via I18N.set_lang("ko"|"en"|"ja"|"zh").

signal lang_changed(lang: String)

const SUPPORTED := ["ko", "en", "ja", "zh"]
var lang: String = "ko"
var _dict: Dictionary = {}    # lang -> { KEY -> VALUE }

func _ready() -> void:
	for l in SUPPORTED:
		_dict[l] = _load_csv("res://i18n/%s.csv" % l)
	# auto-detect from system locale, fallback to ko
	var sys := OS.get_locale_language()
	if SUPPORTED.has(sys):
		lang = sys
	print("[I18N] loaded — active=%s langs=%s" % [lang, SUPPORTED])

func t(key: String) -> String:
	var d: Dictionary = _dict.get(lang, {})
	if d.has(key):
		return d[key]
	# fallback to en, then key itself
	var en: Dictionary = _dict.get("en", {})
	if en.has(key):
		return en[key]
	return key

func set_lang(new_lang: String) -> void:
	if not SUPPORTED.has(new_lang):
		return
	lang = new_lang
	emit_signal("lang_changed", lang)

func _load_csv(path: String) -> Dictionary:
	var out: Dictionary = {}
	if not FileAccess.file_exists(path):
		push_warning("[I18N] missing %s" % path)
		return out
	var f := FileAccess.open(path, FileAccess.READ)
	var first := true
	while not f.eof_reached():
		var line := f.get_line()
		if first:
			first = false
			continue
		if line.strip_edges() == "":
			continue
		var idx := line.find(",")
		if idx < 0:
			continue
		var k := line.substr(0, idx).strip_edges()
		var v := line.substr(idx + 1).strip_edges()
		out[k] = v
	f.close()
	return out
