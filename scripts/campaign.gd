extends RefCounted
const C = preload("res://scripts/catalog.gd")
var abyss: bool = false
var capybara: bool = false
var exploration: bool = false
var room_kind: String = "start"
var room_waves: int = 1
var floor_number: int = 1
var run_id: String = ""
var chapter: int = 1
var round_number: int = 1
var wave: int = 0
var hidden: bool = false
var secret_done: bool = false
var runes: Array[int] = []
var stock: Array = []

func start(index: int) -> void:
	capybara = false
	abyss = false
	floor_number = 1
	chapter = clampi(index,1,6)
	round_number = 1
	wave = 0
	hidden = false
	secret_done = false
	runes.clear()
	stock.clear()

func rounds() -> int:
	return C.CHAPTERS[chapter-1].waves.size()

func waves() -> int:
	if exploration: return room_waves
	if abyss: return 1
	return 2 if hidden else int(C.CHAPTERS[chapter-1].waves[clampi(round_number-1,0,rounds()-1)])

func final_wave() -> bool:
	if abyss: return false
	return wave>=waves() and (hidden or round_number>=rounds())

func boss_kind() -> int:
	if capybara: return 14 if room_kind=="boss" else -1
	if exploration: return (8 if room_kind=="secret" else int(C.CHAPTERS[chapter-1].boss)) if room_kind in ["boss","secret"] else -1
	if abyss: return [12,13,8][int(floor_number/10)%3] if floor_number%10==0 else -1
	if not final_wave(): return -1
	return 8 if hidden else int(C.CHAPTERS[chapter-1].boss)

func title() -> String:
	if capybara: return "噜噜温泉"
	if abyss: return "无尽深渊 · 第 %d 层"%floor_number
	return "镜渊裂隙" if hidden else C.CHAPTERS[chapter-1].name

func can_secret() -> bool:
	return not abyss and chapter==3 and round_number==3 and runes.size()==3 and not secret_done and not hidden
