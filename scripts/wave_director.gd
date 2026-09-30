extends RefCounted
## One wave consists of several reinforcement groups, not extra reward waves.
## The caller advances this clock only during active combat, after entry delays.
const C = preload("res://scripts/catalog.gd")
var chapter: int = 1
var elapsed: float = 0.0
var duration: float = 0.0
var next_group: float = 0.0
var groups: int = 0
var elites_sent: int = 0

func reset() -> void:
	elapsed = 0.0
	duration = 0.0
	next_group = 0.0
	groups = 0
	elites_sent = 0

func start(flow) -> void:
	reset()
	chapter = flow.chapter
	if flow.boss_kind()>=0: return
	var pacing: Dictionary = C.PACING[chapter-1]
	duration = 45.0 if flow.hidden else pacing.seconds+(flow.round_number-1)*pacing.round_add+(flow.wave-1)*pacing.wave_add
	if flow.abyss: duration = 22.0+minf(18.0,flow.floor_number*0.35)

func receiving() -> bool:
	return elapsed<duration

func remaining() -> int:
	return maxi(0,ceili(duration-elapsed))

func phase() -> int:
	if duration<=0: return 0
	return mini(2,floori(elapsed/duration*3.0))

func tick(delta: float, occupied: int) -> int:
	elapsed += delta
	if not receiving(): return 0
	next_group -= delta
	# Quick clears bring the next group forward; never leave an empty arena waiting.
	if occupied==0: next_group = minf(next_group,0.8)
	if next_group>0: return 0
	var pacing: Dictionary = C.PACING[chapter-1]
	var cap = mini(C.ENEMY_LIMIT,int(pacing.alive)-2+phase())
	var count = mini(int(pacing.batch),maxi(0,cap-occupied))
	if count==0: return 0
	groups += 1
	next_group = pacing.interval*(1.15 if phase()==0 else 1.0)
	return count

func take_elite() -> bool:
	if duration<=0 or elites_sent>=int(C.DIFFICULTY[chapter-1].elites): return false
	if elapsed/duration < 0.5+elites_sent*0.25: return false
	elites_sent += 1
	return true
