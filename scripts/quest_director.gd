extends Node
class_name QuestDirector
## Watches what you collect / photograph / record / say, and advances the investigation.


func _ready() -> void:
	Game.item_added.connect(func(_i): check())
	Game.evidence_added.connect(func(_i): check())
	Game.evp_added.connect(func(_i): check())
	Game.flag_set.connect(func(_k): check())


func _count_prefix(arr, prefix: String) -> int:
	var n := 0
	for k in arr:
		if str(k).begins_with(prefix):
			n += 1
	return n


func check() -> void:
	var s: int = Game.step
	var ok := false
	if s == Game.Step.MEET:
		ok = _count_prefix(Game.flags.keys(), "talked_") >= 3
	elif s == Game.Step.EVIDENCE:
		ok = Game.evidence.size() >= 3
	elif s == Game.Step.VOICES:
		ok = Game.evp.size() >= 2
	elif s == Game.Step.PAGES:
		ok = _count_prefix(Game.items, "page_") >= 4
	elif s == Game.Step.MUSICBOX:
		ok = Game.has_item("music_box")
	elif s == Game.Step.DIG:
		ok = Game.has_item("toy_shoe")
	if ok:
		Game.fire("complete_step", [s])
