class_name ShadowTalk
## Offline understanding + replies (no internet, no model file).
## Understands TYPED Arabic/English text with a rule-based NLU (normalised keywords -> intent),
## and builds replies from templates + what the monster has learned about you (ctx).

const KEYS := {
	"threat": ["اقتلك", "اذبحك", "هقتلك", "انتهي منك", "kill you"],
	"insult": ["غبي", "ضعيف", "جبان", "قبيح", "احمق", "تافه", "stupid", "coward", "ugly", "idiot"],
	"plead": ["سيبني", "سبني", "اتركني", "دعني", "خليني", "ابعد", "لا تقتلني", "ارجوك", "رحمه", "اطلقني", "please", "leave me", "let me go", "dont kill", "don't kill"],
	"bargain": ["صفقه", "اتفاق", "اعطيك", "افتح الباب", "اطلعني", "deal", "open the door"],
	"help": ["النجده", "ساعدوني", "انقذوني", "help"],
	"who": ["من انت", "مين انت", "شنو انت", "ما انت", "من تكون", "ما اسمك", "who are you", "what are you"],
	"why": ["لماذا", "ليش", "ليه", "لمه", "why"],
	"greet": ["مرحبا", "هلا", "اهلا", "السلام", "هاي", "hello", " hi "],
}
const ORDER := ["threat", "insult", "plead", "bargain", "help", "who", "why", "greet"]

const R := {
	"plead": ["لماذا أتركك يا {name}؟ أنا أستمتع.", "التوسّل… أحب هذا الصوت.", "الليلة {night}… ولم يتوسّل أحد بصدق من قبل.", "قلها مرة أخرى… ببطء."],
	"who": ["أنا الظل… كنت هنا قبل هذا القبو وسأبقى بعده.", "لست حياً ولا ميتاً. أنا ما يبقى حين ينطفئ الضوء.", "اسمي الظل. أعيش على الخوف… وأنت وجبتي يا {name}."],
	"why": ["لأن الصمت يجعلني أسمع قلبك.", "سؤال لا يطرحه إلا من سيموت.", "لأنني وحيد… وأنت هنا."],
	"greet": ["مرحباً يا {name}… ما أجمل أن يكلّمني أحد.", "كنت أنتظرك."],
	"insult": ["اضحك ما شئت… قلبك يخونك.", "سأتذكر هذه الكلمة عند آخر نفس."],
	"threat": ["جميل… ابقَ هكذا.", "جرّب. الجميع جرّب."],
	"bargain": ["الباب؟ لن يُفتح قبل أن أسمح.", "أي صفقة تملكها وأنت لا تملك إلا خوفك؟"],
	"help": ["لا أحد يسمعك سواي.", "صرخ قبلك كثيرون…"],
	"voice_calm": ["همسٌ… أنت قريب جداً.", "أسمع شفتيك ترتجفان."],
	"voice_loud": ["اصرخ أكثر… أحب ذلك.", "ضجيجك سيدلّ عليك الجميع."],
	"voice_mid": ["ماذا قلت؟ كرّرها.", "أسمعك… لكنني لا أفهم لغة الخوف.", "تكلّم أكثر يا {name}."],
	"unknown": ["ماذا قلت؟ كرّرها.", "أسمعك يا {name}… تكلّم.", "كلماتك تضحكني."],
}
const OUT := {
	"spare": ["اذهب… لكنني أعرف رائحتك الآن.", "سأمنحك دقيقة… استغلّها.", "مللت منك… الآن فقط."],
	"punish": ["كان عليك أن تصمت.", "الآن… سأريك.", "لا أحب التوسّل."],
	"toy": ["ابقَ ثابتاً… لننظر كم تتحمل.", "لا تتحرك يا {name}."],
}


static func normalize(text: String) -> String:
	var t := text.to_lower()
	var out := ""
	for ch in t:
		var c := ch.unicode_at(0)
		if (c >= 0x064B and c <= 0x065F) or c == 0x0670 or c == 0x0640:
			continue
		out += ch
	return out.replace("أ", "ا").replace("إ", "ا").replace("آ", "ا").replace("ى", "ي").replace("ة", "ه")


static func intent(text: String) -> String:
	var n := " " + normalize(text) + " "
	for k in ORDER:
		for w in KEYS[k]:
			if n.contains(w):
				return k
	return "unknown"


static func voice_intent(peak: float) -> String:
	if peak < 0.4:
		return "voice_calm"
	if peak > 0.7:
		return "voice_loud"
	return "voice_mid"


static func _fill(line: String, c: Dictionary) -> String:
	return line.replace("{name}", str(c.get("name", ""))).replace("{night}", str(c.get("night", 1)))


static func reply(intent_name: String, c: Dictionary) -> String:
	var pool: Array = R.get(intent_name, R["unknown"]).duplicate()
	if intent_name == "plead" and int(c.get("wins", 0)) > 0:
		pool.append("هربتَ %d مرة… اليوم دوري." % int(c["wins"]))
	if intent_name == "who":
		pool.append("أتعلّم منك… أعرف الآن أنك %s." % str(c.get("habit", "هادئ")))
	return _fill(pool.pick_random(), c)


static func outcome_line(o: String, c: Dictionary) -> String:
	var pool: Array = OUT.get(o, OUT["toy"])
	return _fill(pool.pick_random(), c)
