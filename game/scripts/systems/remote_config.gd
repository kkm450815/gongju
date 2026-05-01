extends Node
## RemoteConfig — pulls game_config rows from Supabase at startup and overrides
## DataLoader.balance values. Disabled when SUPABASE_URL is empty.

const SUPABASE_URL := ""              # set to "https://xxxx.supabase.co" to enable
const SUPABASE_ANON_KEY := ""

signal config_synced()

var _http: HTTPRequest

func _ready() -> void:
	if SUPABASE_URL == "" or SUPABASE_ANON_KEY == "":
		return
	_http = HTTPRequest.new()
	add_child(_http)
	_http.request_completed.connect(_on_done)
	var url := "%s/rest/v1/game_config?select=key,value" % SUPABASE_URL
	var headers := PackedStringArray([
		"apikey: " + SUPABASE_ANON_KEY,
		"Authorization: Bearer " + SUPABASE_ANON_KEY,
	])
	_http.request(url, headers, HTTPClient.METHOD_GET)

func _on_done(_result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if code != 200:
		push_warning("[RemoteConfig] HTTP %d" % code)
		return
	var parsed = JSON.parse_string(body.get_string_from_utf8())
	if typeof(parsed) != TYPE_ARRAY:
		return
	if not has_node("/root/DataLoader"):
		return
	for row in parsed:
		var k = row.get("key")
		var v = row.get("value")
		if k != null and v != null:
			DataLoader.balance[String(k)] = v
	emit_signal("config_synced")
	print("[RemoteConfig] synced %d values" % parsed.size())
