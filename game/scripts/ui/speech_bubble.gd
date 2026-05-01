extends Node3D
## SpeechBubble — a small Label3D that floats above an entity for a few seconds,
## drifts upward, fades out, then frees itself.
## Use SpeechBubble.spawn(parent, "🌾", 2.5) for transient emoji popups
## or SpeechBubble.attach(npc_node, "🌾") for persistent activity badges.

class_name SpeechBubble

@export var text: String = ""
@export var duration_sec: float = 2.5

var _label: Label3D
var _persistent: bool = false

static func spawn(parent: Node3D, msg: String, duration: float = 2.5, height_offset: float = 2.4) -> SpeechBubble:
	var b := SpeechBubble.new()
	b.text = msg
	b.duration_sec = duration
	parent.add_child(b)
	b.position.y = height_offset
	return b

static func attach(parent: Node3D, msg: String, height_offset: float = 2.4) -> SpeechBubble:
	var b := SpeechBubble.new()
	b.text = msg
	b._persistent = true
	parent.add_child(b)
	b.position.y = height_offset
	return b

func _ready() -> void:
	_label = Label3D.new()
	_label.text = text
	_label.font_size = 64
	_label.outline_size = 8
	_label.modulate = Color(1, 1, 1, 1)
	_label.outline_modulate = Color(0, 0, 0, 0.85)
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.no_depth_test = true
	_label.fixed_size = true
	_label.pixel_size = 0.005
	_label.alpha_cut = Label3D.ALPHA_CUT_OPAQUE_PREPASS
	# system font with emoji + CJK fallback so 🌾 / 🎣 etc. actually render
	var sf := SystemFont.new()
	sf.font_names = PackedStringArray([
		"Segoe UI Emoji", "Apple Color Emoji", "Noto Color Emoji",
		"Twemoji Mozilla", "Segoe UI Symbol",
		"Malgun Gothic", "Apple SD Gothic Neo", "Noto Sans CJK KR",
	])
	sf.allow_system_fallback = true
	_label.font = sf
	add_child(_label)

	if not _persistent:
		var tw := create_tween()
		tw.set_parallel(true)
		tw.tween_property(self, "position:y", position.y + 1.0, duration_sec)
		tw.tween_property(_label, "modulate:a", 0.0, duration_sec)
		tw.chain().tween_callback(Callable(self, "queue_free"))

func set_text(msg: String) -> void:
	text = msg
	if _label:
		_label.text = msg
