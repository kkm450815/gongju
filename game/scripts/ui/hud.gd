extends CanvasLayer
## HUD — programmatic in-game UI: faith bar, town stats, power buttons, log, language switch.
## Created entirely from code so no .tscn editing is required.

class_name HUD

signal power_selected(power_id: String, kind: String)   # kind: "disaster" | "blessing"
signal speed_change_requested(speed: float)
signal pause_toggle_requested()
signal lang_change_requested(lang: String)

var _faith_bar: ProgressBar
var _faith_lbl: Label
var _pop_lbl: Label
var _prosp_lbl: Label
var _fear_lbl: Label
var _day_lbl: Label
var _hint_lbl: Label
var _log_box: VBoxContainer
var _disaster_box: HBoxContainer
var _blessing_box: HBoxContainer
var _selected_id: String = ""
var _selected_kind: String = ""
var _power_buttons: Dictionary = {}     # id -> Button
var _cooldowns: Dictionary = {}          # id -> remaining seconds

func _ready() -> void:
	_build()

func _build() -> void:
	# top-left stats
	var top := PanelContainer.new()
	top.anchor_left = 0.0; top.anchor_top = 0.0
	top.offset_left = 12; top.offset_top = 12
	top.modulate = Color(1, 1, 1, 0.95)
	add_child(top)
	var vb := VBoxContainer.new()
	top.add_child(vb)

	_faith_lbl = _mk_label(I18N.t("HUD_FAITH") + ": 0 / 100")
	vb.add_child(_faith_lbl)
	_faith_bar = ProgressBar.new()
	_faith_bar.min_value = 0; _faith_bar.max_value = 100; _faith_bar.value = 30
	_faith_bar.custom_minimum_size = Vector2(220, 16)
	vb.add_child(_faith_bar)
	_pop_lbl   = _mk_label("👥 0")
	_prosp_lbl = _mk_label("💰 0")
	_fear_lbl  = _mk_label("😱 0")
	_day_lbl   = _mk_label("📅 1")
	vb.add_child(_pop_lbl); vb.add_child(_prosp_lbl); vb.add_child(_fear_lbl); vb.add_child(_day_lbl)

	# top-right controls
	var right := HBoxContainer.new()
	right.anchor_left = 1.0; right.anchor_right = 1.0
	right.anchor_top = 0.0
	right.offset_left = -440; right.offset_right = -12; right.offset_top = 12
	add_child(right)
	right.add_child(_mk_btn("⏸", func(): emit_signal("pause_toggle_requested")))
	right.add_child(_mk_btn("1×", func(): emit_signal("speed_change_requested", 1.0)))
	right.add_child(_mk_btn("2×", func(): emit_signal("speed_change_requested", 2.0)))
	right.add_child(_mk_btn("4×", func(): emit_signal("speed_change_requested", 4.0)))

	var lang := OptionButton.new()
	for code in ["ko","en","ja","zh"]:
		lang.add_item(code.to_upper())
	lang.item_selected.connect(func(idx):
		var codes := ["ko","en","ja","zh"]
		emit_signal("lang_change_requested", codes[idx])
	)
	right.add_child(lang)

	# bottom: power tray
	var tray := PanelContainer.new()
	tray.anchor_left = 0.0; tray.anchor_right = 1.0
	tray.anchor_bottom = 1.0; tray.anchor_top = 1.0
	tray.offset_top = -120; tray.offset_left = 12; tray.offset_right = -12; tray.offset_bottom = -12
	add_child(tray)
	var tray_v := VBoxContainer.new()
	tray.add_child(tray_v)
	_hint_lbl = _mk_label(I18N.t("HUD_HINT_SELECT"))
	tray_v.add_child(_hint_lbl)
	var rows := HBoxContainer.new()
	rows.add_theme_constant_override("separation", 24)
	tray_v.add_child(rows)

	var dis_v := VBoxContainer.new()
	dis_v.add_child(_mk_label(I18N.t("HUD_DISASTERS")))
	_disaster_box = HBoxContainer.new()
	dis_v.add_child(_disaster_box)
	rows.add_child(dis_v)

	var ble_v := VBoxContainer.new()
	ble_v.add_child(_mk_label(I18N.t("HUD_BLESSINGS")))
	_blessing_box = HBoxContainer.new()
	ble_v.add_child(_blessing_box)
	rows.add_child(ble_v)

	# right side: log
	var log_panel := PanelContainer.new()
	log_panel.anchor_left = 1.0; log_panel.anchor_right = 1.0
	log_panel.anchor_top = 0.0; log_panel.anchor_bottom = 1.0
	log_panel.offset_left = -300; log_panel.offset_right = -12
	log_panel.offset_top = 90; log_panel.offset_bottom = -140
	log_panel.modulate = Color(1, 1, 1, 0.85)
	add_child(log_panel)
	_log_box = VBoxContainer.new()
	log_panel.add_child(_log_box)

func populate_powers(disasters: Array, blessings: Array) -> void:
	for d in disasters:
		_make_power_btn(d, "disaster", _disaster_box)
	for b in blessings:
		_make_power_btn(b, "blessing", _blessing_box)

func _make_power_btn(p: Dictionary, kind: String, parent: HBoxContainer) -> void:
	var b := Button.new()
	var emoji := String(p.get("icon_emoji", "✨"))
	var label := I18N.t(String(p.get("name_key", p.get("id", "?"))))
	var cost := int(p.get("cost_faith", 0))
	b.text = "%s %s\n−%d" % [emoji, label, cost]
	b.tooltip_text = I18N.t(String(p.get("desc_key", "")))
	b.custom_minimum_size = Vector2(110, 60)
	var pid := String(p["id"])
	b.pressed.connect(func():
		_selected_id = pid
		_selected_kind = kind
		_hint_lbl.text = "%s %s — %s" % [emoji, label, I18N.t("HUD_HINT_SELECT")]
		emit_signal("power_selected", pid, kind)
	)
	_power_buttons[pid] = b
	parent.add_child(b)

func set_cooldown(power_id: String, seconds: float) -> void:
	_cooldowns[power_id] = seconds

func _process(delta: float) -> void:
	for pid in _cooldowns.keys():
		var left: float = _cooldowns[pid] - delta
		_cooldowns[pid] = left
		var btn: Button = _power_buttons.get(pid)
		if btn:
			btn.disabled = left > 0.0
			if left <= 0.0:
				_cooldowns.erase(pid)

func update_faith(value: float, max_value: float) -> void:
	_faith_bar.max_value = max_value
	_faith_bar.value = value
	_faith_lbl.text = "%s: %d / %d" % [I18N.t("HUD_FAITH"), int(value), int(max_value)]

func update_population(n: int) -> void:
	_pop_lbl.text = "👥 %s: %d" % [I18N.t("HUD_POPULATION"), n]

func update_prosperity(v: float) -> void:
	_prosp_lbl.text = "💰 %s: %d" % [I18N.t("HUD_PROSPERITY"), int(v)]

func update_fear(v: float) -> void:
	_fear_lbl.text = "😱 %s: %d" % [I18N.t("HUD_FEAR"), int(v)]

func update_day(d: int) -> void:
	_day_lbl.text = "📅 %s %d" % [I18N.t("HUD_DAY"), d]

func push_log(text: String) -> void:
	var l := Label.new()
	l.text = "• " + text
	_log_box.add_child(l)
	# keep only last 8
	while _log_box.get_child_count() > 8:
		_log_box.get_child(0).queue_free()

func hint(text: String) -> void:
	_hint_lbl.text = text

func _mk_label(t: String) -> Label:
	var l := Label.new()
	l.text = t
	return l

func _mk_btn(t: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = t
	b.custom_minimum_size = Vector2(54, 28)
	b.pressed.connect(cb)
	return b
