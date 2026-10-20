extends Node
class_name ShadowMind
## Offline learning brain (no internet, no cost, never stops learning).
## - Player model saved on the device between matches: where you walk (heat-map), which hiding spots
##   you use, how often you run, whether you freeze under the 7-second stare, how loud you are.
## - Tactics chosen by a bandit (UCB1): it tries different hunting tactics, rewards itself when a tactic
##   finds/catches you, and keeps the stats forever -> it keeps adapting night after night.
## - Speaks procedural Arabic lines built from what it really learned about you.

const SAVE_PATH := "user://shadow_mind.json"
const TACTICS := ["roam_heat", "favorite_zone", "camp_objective", "ambush_route", "check_last_seen"]
const GRID := 8
const HALF := 20.0

var data: Dictionary = {}
var tactic := ""
var leg_reward := 0.0
var _save_t := 20.0


func _ready() -> void:
	data = _load()
	data["games"] = int(data["games"]) + 1
	_save()
	Game.game_won.connect(_on_won)
	Game.game_over.connect(_on_over)


func _process(delta: float) -> void:
	_save_t -= delta
	if _save_t <= 0.0:
		_save_t = 20.0
		_save()


# ------------------------------------------------------------------ persistence
func _load() -> Dictionary:
	var d := {"games": 0, "deaths": 0, "wins": 0, "heat": [], "zone_use": {}, "run_ratio": 0.2,
		"stare_break": 0.5, "noise_avg": 0.2, "arms": {}, "facts": []}
	if FileAccess.file_exists(SAVE_PATH):
		var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
		if f != null:
			var j = JSON.parse_string(f.get_as_text())
			if j is Dictionary:
				for k in j:
					d[k] = j[k]
	if not (d["heat"] is Array) or d["heat"].size() != GRID * GRID:
		var h := []
		h.resize(GRID * GRID)
		h.fill(0.0)
		d["heat"] = h
	for t in TACTICS:
		if not d["arms"].has(t):
			d["arms"][t] = {"n": 0, "r": 0.0}
	return d


func _save() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(data))


func _on_won() -> void:
	data["wins"] = int(data["wins"]) + 1
	_save()


func _on_over() -> void:
	data["deaths"] = int(data["deaths"]) + 1
	_save()


func _f(k: String) -> float:
	return float(data[k])


# ------------------------------------------------------------------ learning the player
func _cell(p: Vector3) -> int:
	var x := clampi(int((p.x + HALF) / (2.0 * HALF) * GRID), 0, GRID - 1)
	var z := clampi(int((p.z + HALF) / (2.0 * HALF) * GRID), 0, GRID - 1)
	return z * GRID + x


func _cell_pos(i: int) -> Vector3:
	var cx := float(i % GRID)
	var cz := floorf(float(i) / GRID)
	return Vector3((cx + 0.5) / GRID * 2.0 * HALF - HALF, 0.0, (cz + 0.5) / GRID * 2.0 * HALF - HALF)


func note_pos(p) -> void:
	var h: Array = data["heat"]
	var c := _cell(p.global_position)
	h[c] = float(h[c]) + 1.0
	if randf() < 0.02:                       # old habits slowly fade
		for i in h.size():
			h[i] = float(h[i]) * 0.98
	data["run_ratio"] = lerpf(_f("run_ratio"), 1.0 if p.posture == 1 else 0.0, 0.03)


func note_zone(idx: int) -> void:
	if idx < 0:
		return
	var zu: Dictionary = data["zone_use"]
	zu[str(idx)] = float(zu.get(str(idx), 0.0)) + 1.0


func note_stare(broke: bool) -> void:
	data["stare_break"] = lerpf(_f("stare_break"), 1.0 if broke else 0.0, 0.15)


func note_noise(n: float) -> void:
	data["noise_avg"] = lerpf(_f("noise_avg"), n, 0.05)


func on_kill(victim, kind: String) -> void:
	var how := "ran" if kind == "intercept_slam" else ("crawled" if kind == "stomp_lift" else "hid")
	var facts: Array = data["facts"]
	facts.append("killed %s while they %s" % [victim.display_name, how])
	if facts.size() > 8:
		facts.pop_front()
	_save()


func reward(r: float) -> void:
	leg_reward += r


# ------------------------------------------------------------------ choosing a tactic (bandit)
func choose(m) -> bool:
	_finish_leg()
	tactic = _pick_tactic()
	leg_reward = 0.0
	Game.mind_status = "Mind: %s | night %d" % [tactic, Game.night]
	if not _apply(tactic, m):
		tactic = "roam_heat"
		_apply(tactic, m)
	return true


func _finish_leg() -> void:
	if tactic == "":
		return
	var a: Dictionary = data["arms"][tactic]
	a["n"] = int(a["n"]) + 1
	a["r"] = float(a["r"]) + leg_reward - 0.2


func _prior(t: String) -> float:
	if t == "ambush_route" and _f("run_ratio") > 0.4:
		return 0.3
	if t == "favorite_zone" and _fav_zone() >= 0:
		return 0.3
	return 0.0


func _pick_tactic() -> String:
	var total := 0
	for t in TACTICS:
		total += int(data["arms"][t]["n"])
	var best: String = TACTICS[0]
	var best_s := -INF
	for t in TACTICS:
		var a: Dictionary = data["arms"][t]
		var n := int(a["n"])
		var s := 0.0
		if n == 0:
			s = 100.0 + randf()
		else:
			s = float(a["r"]) / n + 0.8 * sqrt(log(total + 1.0) / n) + _prior(t) + randf() * 0.15
		if s > best_s:
			best_s = s
			best = t
	return best


func _apply(t: String, m) -> bool:
	match t:
		"roam_heat":
			m.dest = _heat_sample()
			m.hold_t = 0.0
			m._set_state(0)
			return true
		"favorite_zone":
			var zs: Array = m.hide_zones
			if zs.is_empty():
				return false
			var ws: Array = []
			var tot := 0.0
			for i in zs.size():
				var w := 1.0 + float(data["zone_use"].get(str(i), 0.0)) * 2.0 + float(zs[i].score) * 2.0
				if Time.get_ticks_msec() - zs[i].last_checked < 15000:
					w *= 0.1
				ws.append(w)
				tot += w
			var r := randf() * tot
			for i in zs.size():
				r -= ws[i]
				if r <= 0.0:
					m.current_zone = zs[i]
					m.noise_pos = zs[i].global_position
					m._set_state(4)
					return true
			return false
		"camp_objective":
			var o: Vector3 = Game.OBJ_POS[mini(Game.step, 2)]
			m.dest = o + Vector3(randf_range(-4.0, 4.0), 0.0, randf_range(-4.0, 4.0))
			m.hold_t = 10.0
			m._set_state(0)
			return true
		"ambush_route":
			var h: Array = data["heat"]
			var best := -1
			var bv := -1.0
			for i in h.size():
				if _cell_pos(i).distance_to(m.global_position) < 8.0:
					continue
				var v := float(h[i]) + randf() * 2.0
				if v > bv:
					bv = v
					best = i
			if best < 0:
				return false
			m.dest = _cell_pos(best)
			m.hold_t = 12.0
			m._set_state(0)
			return true
		"check_last_seen":
			var latest := ""
			for n in m.seen_t:
				if latest == "" or m.seen_t[n] > m.seen_t[latest]:
					latest = n
			if latest == "":
				return false
			m._start_investigate(m.seen_pos[latest])
			return true
	return false


func _heat_sample() -> Vector3:
	var h: Array = data["heat"]
	var tot := 0.0
	for v in h:
		tot += float(v) + 0.5
	var r := randf() * tot
	for i in h.size():
		r -= float(h[i]) + 0.5
		if r <= 0.0:
			return _cell_pos(i)
	return _cell_pos(0)


func _fav_zone() -> int:
	var zu: Dictionary = data["zone_use"]
	var tot := 0.0
	var best := -1
	var bv := 0.0
	for k in zu:
		tot += float(zu[k])
		if float(zu[k]) > bv:
			bv = float(zu[k])
			best = int(k)
	if tot >= 3.0 and bv / tot > 0.3:
		return best
	return -1


# ------------------------------------------------------------------ what it says (built from what it learned)
func line(ctx: String, pname: String) -> String:
	var games := int(data["games"])
	var deaths := int(data["deaths"])
	var wins := int(data["wins"])
	var pool: Array = []
	match ctx:
		"greet":
			pool = ["أنا الظل… أعيش هنا قبل أن تدخل يا %s." % pname, "الليلة %d يا %s… وأنا أتذكر كل شيء." % [Game.night, pname]]
			if games > 1:
				pool.append("عدتَ يا %s… ظننتك تعلمت." % pname)
			if deaths > 0:
				pool.append("قتلتك %d مرة… وما زلت تعود." % deaths)
		"spot":
			pool = ["رأيتك يا %s…" % pname, "لا تتحرك…", "%s… أنا أراك." % pname]
			if _f("run_ratio") > 0.4:
				pool.append("تركض كثيراً يا %s… أسمعك من بعيد." % pname)
		_:
			pool = ["%s… أين أنت؟" % pname, "أسمع أنفاسك…", "أتعلّم منك في كل مرة."]
			var fz := _fav_zone()
			if fz >= 0 and fz < Game.ZONE_NAMES.size():
				pool.append("أعرف أنك تحب الاختباء في %s." % Game.ZONE_NAMES[fz])
			if _f("stare_break") < 0.3:
				pool.append("تثبت أمام عيني… لن تنجح مرتين يا %s." % pname)
			if wins > 0:
				pool.append("هربتَ %d مرة… لن تهرب الليلة." % wins)
	return pool.pick_random()
