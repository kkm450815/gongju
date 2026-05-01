extends Node
## Telemetry — batches in-game events and POSTs them to Supabase every 30s.
## Disabled if SUPABASE_URL is empty.

const SUPABASE_URL := ""
const SUPABASE_ANON_KEY := ""
const FLUSH_EVERY_SEC := 30.0

var _user_id: String = ""
var _queue: Array = []
var _http: HTTPRequest
var _timer: float = 0.0

func _ready() -> void:
	# generate a stable anon user id (persisted in user://)
	_user_id = _load_or_create_user_id()
	_http = HTTPRequest.new()
	add_child(_http)
	track("session_start", {})

func _process(delta: float) -> void:
	_timer += delta
	if _timer >= FLUSH_EVERY_SEC:
		_timer = 0.0
		_flush()

func track(event_type: String, payload: Dictionary) -> void:
	_queue.append({
		"user_id": _user_id,
		"type": event_type,
		"payload": payload
	})

func _flush() -> void:
	if SUPABASE_URL == "" or _queue.is_empty():
		_queue.clear()
		return
	var body := JSON.stringify(_queue)
	var headers := PackedStringArray([
		"Content-Type: application/json",
		"apikey: " + SUPABASE_ANON_KEY,
		"Authorization: Bearer " + SUPABASE_ANON_KEY,
		"Prefer: return=minimal",
	])
	_http.request(SUPABASE_URL + "/rest/v1/events", headers, HTTPClient.METHOD_POST, body)
	_queue.clear()

func _load_or_create_user_id() -> String:
	var path := "user://user_id.txt"
	if FileAccess.file_exists(path):
		var f := FileAccess.open(path, FileAccess.READ)
		var s := f.get_as_text().strip_edges()
		f.close()
		if s != "":
			return s
	var id := _uuid4()
	var f2 := FileAccess.open(path, FileAccess.WRITE)
	f2.store_string(id)
	f2.close()
	return id

func _uuid4() -> String:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var bytes := PackedByteArray()
	for i in 16:
		bytes.append(rng.randi() & 0xff)
	bytes[6] = (bytes[6] & 0x0f) | 0x40
	bytes[8] = (bytes[8] & 0x3f) | 0x80
	var hex := ""
	for b in bytes:
		hex += "%02x" % b
	return "%s-%s-%s-%s-%s" % [
		hex.substr(0, 8), hex.substr(8, 4), hex.substr(12, 4),
		hex.substr(16, 4), hex.substr(20, 12)
	]
