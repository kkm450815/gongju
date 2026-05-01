extends Node
## WeatherSystem — placeholder for now. Holds current weather state.

signal weather_changed(state: String)

var state: String = "clear"   # clear|rain|storm|fog

func set_state(s: String) -> void:
	state = s
	emit_signal("weather_changed", s)
