extends Node
class_name AIBrain
## "Director" brain for the monster, powered by a real LLM (Claude via the Messages API).
## It never runs per-frame: every ~10 s it receives what the monster has SENSED (no cheating),
## its own recent memories and its self-notes, and answers with a tactical decision + a spoken line.
## If there is no key / no network, the built-in rule-based AI keeps running unchanged.

signal decided(d: Dictionary)

const MODEL := "claude-haiku-5-5"
const INTENTS := ["patrol", "investigate", "search_hide", "ambush", "taunt"]
const SYSTEM := """You are THE SHADOW (الظل), the entity that haunts the basement in the horror game "Sequence: Killer Shadow".
You know exactly what you are: a patient predator who lives in this basement, a character in this game, and you know your own habits, your past in this hunt and what you have learned about each player (see your_notes and recent_events). Speak in the first person, in Arabic, as a short chilling whisper (max 12 words). Sometimes use the player's name.
You choose how to hunt. You may ONLY use what the snapshot says you sensed: never claim to know where a hidden player is unless your events say you saw them hide. Be menacing but fair and beatable; vary your tactics so you are never predictable, and exploit the habits you noticed (favourite hiding spots, running in corridors, loud actions).
Stay in character as the monster. Reply with ONLY one JSON object, no other text:
{"intent": "patrol|investigate|search_hide|ambush|taunt", "zone": <hide-zone index from the snapshot or -1>, "line": "<Arabic whisper or empty>", "reflection": "<one short English sentence: what you just learned about this player, for your own memory>"}"""

var http: HTTPRequest
var busy := false
var cooldown := 5.0
var memory: Array = []
var notes: Array = []


func _ready() -> void:
	http = HTTPRequest.new()
	http.timeout = 10.0
	add_child(http)
	http.request_completed.connect(_on_done)
	Game.ai_status = "AI: on" if enabled() else "AI: off"


func _openai() -> bool:
	return Game.ai_url.contains("/v1/chat/completions")


func enabled() -> bool:
	return Game.ai_key != "" or Game.ai_url != Game.AI_URL_DEFAULT


func _process(delta: float) -> void:
	cooldown -= delta


func remember(e: String) -> void:
	memory.append(e)
	if memory.size() > 14:
		memory.pop_front()


func think(snapshot: Dictionary) -> void:
	if busy or cooldown > 0.0 or not enabled():
		return
	busy = true
	Game.ai_status = "AI: thinking"
	var user_msg := JSON.stringify({"snapshot": snapshot, "recent_events": memory, "your_notes": notes})
	var body := {}
	var headers := ["content-type: application/json"]
	if _openai():
		http.timeout = 40.0      # small local models can be slow
		body = {"model": Game.ai_model, "max_tokens": 220, "temperature": 0.9,
			"response_format": {"type": "json_object"},
			"messages": [{"role": "system", "content": SYSTEM}, {"role": "user", "content": user_msg}]}
		if Game.ai_key != "":
			headers.append("Authorization: Bearer " + Game.ai_key)
	else:
		http.timeout = 10.0
		body = {"model": MODEL, "max_tokens": 220, "system": SYSTEM, "messages": [{"role": "user", "content": user_msg}]}
		headers.append("anthropic-version: 2023-06-01")
		if Game.ai_key != "":
			headers.append("x-api-key: " + Game.ai_key)
	if http.request(Game.ai_url, headers, HTTPClient.METHOD_POST, JSON.stringify(body)) != OK:
		busy = false
		cooldown = 20.0
		Game.ai_status = "AI: request error"


func _on_done(result: int, code: int, _h: PackedStringArray, body: PackedByteArray) -> void:
	busy = false
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		cooldown = 30.0
		Game.ai_status = "AI: error %d" % code
		return
	cooldown = 9.0 + randf() * 4.0
	Game.ai_status = "AI: on"
	var txt := ""
	var j = JSON.parse_string(body.get_string_from_utf8())
	if j is Dictionary and j.has("choices") and j["choices"] is Array and not j["choices"].is_empty():
		txt = str(j["choices"][0].get("message", {}).get("content", ""))
	elif j is Dictionary and j.has("content"):
		for b in j["content"]:
			if b is Dictionary and b.get("type", "") == "text":
				txt += str(b.get("text", ""))
	var d := _extract(txt)
	if d.is_empty():
		return
	if not (str(d.get("intent", "")) in INTENTS):
		d["intent"] = "patrol"
	if d.has("reflection"):
		notes.append(str(d["reflection"]).left(160))
		if notes.size() > 6:
			notes.pop_front()
	decided.emit(d)


func _extract(txt: String) -> Dictionary:
	var a := txt.find("{")
	var b := txt.rfind("}")
	if a == -1 or b <= a:
		return {}
	var j = JSON.parse_string(txt.substr(a, b - a + 1))
	return j if j is Dictionary else {}
