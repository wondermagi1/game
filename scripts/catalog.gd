extends RefCounted
## V3 shared data. Stable IDs are persisted; display names may change safely.
const VERSION = 4
const MAX_LEVEL = 60
const MAX_SKILL = 10
const SKILL_REQUIREMENTS = [1,3,5,8,10,12,15,18,22,25]
const SKILL_COSTS = [0,2,3,3,3,4,4,4,5,5]
const MAX_ENHANCE = 10
const CAPACITY = 120
## Reinforcement seconds per normal wave, then clear remaining enemies to advance.
## Length grows through active encounters; chapter/round/wave counts remain unchanged.
const PACING = [
	{"seconds":36.0,"round_add":6.0,"wave_add":2.0,"batch":3,"interval":5.0,"alive":7,"boss_hp":2.4,"target":"2 分钟"},
	{"seconds":24.0,"round_add":3.0,"wave_add":2.0,"batch":3,"interval":4.8,"alive":10,"boss_hp":2.4,"target":"3 分钟"},
	{"seconds":18.0,"round_add":2.0,"wave_add":1.0,"batch":4,"interval":4.5,"alive":12,"boss_hp":2.4,"target":"5–6 分钟"},
	{"seconds":12.0,"round_add":1.0,"wave_add":1.0,"batch":4,"interval":4.2,"alive":14,"boss_hp":2.2,"target":"7–8 分钟"},
	{"seconds":9.0,"round_add":0.75,"wave_add":1.0,"batch":4,"interval":4.0,"alive":15,"boss_hp":2.2,"target":"7–8 分钟"},
	{"seconds":9.0,"round_add":0.75,"wave_add":1.0,"batch":4,"interval":3.8,"alive":16,"boss_hp":2.2,"target":"7–8 分钟"}
]
const ENEMY_LIMIT = 32
const SPAWN_INTERVAL = 0.38
## Fixed chapter difficulty tiers; never scaled from the player's current power.
## Later chapters assume equipment, talents and additional active skills together.
const DIFFICULTY = [
	{"hp":1.0,"damage":1.0,"speed":1.0,"round_growth":0.035,"elites":0,"ranged":1,"build":"Lv.1，基础武器，无天赋"},
	{"hp":1.6,"damage":1.18,"speed":1.04,"round_growth":0.04,"elites":1,"ranged":2,"build":"Lv.5，稀有 2 件 +1，4 点天赋"},
	{"hp":2.7,"damage":1.45,"speed":1.08,"round_growth":0.045,"elites":1,"ranged":3,"build":"Lv.10，稀有 4 件 +2，9 点天赋，E 技能 Lv.2"},
	{"hp":4.4,"damage":1.85,"speed":1.12,"round_growth":0.05,"elites":2,"ranged":3,"build":"Lv.15，稀有 6 件 +3，14 点天赋，E/Q 技能 Lv.2"},
	{"hp":6.6,"damage":2.2,"speed":1.14,"round_growth":0.05,"elites":2,"ranged":3,"build":"Lv.22，史诗 4 件 +5，21 点天赋，主技能 Lv.3"},
	{"hp":9.2,"damage":2.6,"speed":1.16,"round_growth":0.05,"elites":2,"ranged":4,"build":"Lv.30，史诗 6 件 +7，29 点天赋，主技能 Lv.5"}
]
const CHAPTERS = [
	{"name":"新手试炼","waves":[1,2],"level":1,"boss":6,"color":"#69dbce","hint":"WASD 移动 · 左键攻击 · Space 闪避；清房选择强化；G交互，M地图。"},
	{"name":"荒野营地","waves":[1,2,3],"level":5,"boss":7,"color":"#ddb977","hint":"冲锋前会出现红线；回合整备时可购买补给。"},
	{"name":"裂隙要塞","waves":[2,2,2,3,3],"level":10,"boss":4,"color":"#bca5ed","hint":"北墙三道微光：靠近后交互三次，打开镜渊支路。"},
	{"name":"灾厄圣殿","waves":[2,2,3,3,3,3,3],"level":15,"boss":5,"color":"#ea768e","hint":"保留闪避应对首领蓄力，技能组合能打破僵局。"},
	{"name":"熔炉回廊","waves":[2,2,3,3,3,3,3],"level":22,"boss":12,"color":"#eda35f","hint":"每 12 秒熔炉点燃横向火带，观察预警并进入缺口。优先击杀护盾祭司。"},
	{"name":"星蚀王座","waves":[2,2,3,3,3,3,3],"level":30,"boss":13,"color":"#8fa4ff","hint":"星蚀印追踪后锁定位置。持续移动；击败领主后解锁无尽深渊。"}
]
const QUALITIES = ["普通","稀有","史诗","传奇"]
const COLORS = ["#a6adb8","#69b5ff","#c397ff","#ffd279"]
const QUALITY_SCALE = [1.0,1.18,1.42,1.75]
const SLOTS = ["武器","头部","胸甲","护手","鞋靴","护符"]
const SETS = ["青岚御剑","赤烬猎魔","逐风星猎"]
const NAMES = [["流光剑","青岚冠","云纹法衣","御剑护腕","踏风履","剑心玉"],["烬火铳","猎魔帽","赤烬战衣","火药手套","远征靴","余烬徽记"],["逐星弓","星猎兜帽","逐风披衣","银翎护手","林行靴","猎星坠"]]
const SLOT_STATS = [{"attack":4.0},{"hp":12.0},{"hp":18.0,"armor":2.0},{"attack":2.0},{"speed":12.0},{"attack":1.5,"hp":6.0}]
const AFFIXES = [{"key":"attack","amount":2.0},{"key":"hp","amount":9.0},{"key":"armor","amount":2.0},{"key":"crit","amount":0.015},{"key":"rate_pct","amount":0.025},{"key":"range_pct","amount":0.05}]
const DROP_CHANCE = [0.07,0.40,1.0,1.0]
const DROP_WEIGHTS = [[70.0,25.0,4.5,0.5],[40.0,40.0,18.0,2.0],[10.0,40.0,40.0,10.0],[0.0,0.0,60.0,40.0]]
const SKILL_LEVELS = [1,5,10,15]
const SKILL_KEYS = ["E","Q","F","C"]
const SKILLS = [
	[
		{
			"name": "剑阵",
			"cd": 10.0,
			"text": "周身剑阵持续 3 秒，每 0.25 秒造成 45% 攻击伤害。每技能等级增加 1 秒、范围 20；Lv.3 首次发动追加剑气。"
		},
		{
			"name": "穿云剑",
			"cd": 8.0,
			"text": "完整巨剑贯穿10个目标，造成 (280% + 每级50%) 攻击伤害，附加8秒剑印；实际判定宽48，Lv.3宽64，Lv.5两把护卫剑，Lv.8剑印扩散。"
		},
		{
			"name": "回锋步",
			"cd": 9.0,
			"text": "沿瞄准方向冲刺并短暂无敌，路径留下三次剑气。剑阵中使用追加范围剑气；等级提高路径伤害。"
		},
		{
			"name": "万剑归宗",
			"cd": 18.0,
			"text": "0.35秒聚剑→约3秒有限剑雨→巨剑终结。Lv.1基础完整预算1700%，Lv.10为3320%攻击，另有觉醒余阵；Q与E可强化C，C中F可横向斩击。"
		}
	],
	[
		{
			"name": "爆破弹",
			"cd": 8.0,
			"text": "发射爆破弹，造成 (210% + 每级 40%) 攻击范围伤害，留下 6 秒火药区；强化首发或 F 强化弹可引爆一次，追加 200% 范围伤害。"
		},
		{
			"name": "霰弹齐射",
			"cd": 7.0,
			"text": "发射 4 + 技能等级发霰弹，各造成 45% 攻击伤害并标记目标 6 秒；重火力消耗标记追加伤害。"
		},
		{
			"name": "战术装填",
			"cd": 12.0,
			"text": "立即装满弹匣，4 + 技能等级秒内攻速 +35%，接下来 3 发强化；Lv.3 获得短暂护盾。"
		},
		{
			"name": "炼狱火力",
			"cd": 18.0,
			"text": "起手重火力→4至5.35秒压制有效目标→终结爆破。F状态强化持续弹与终结；Q标记可被C消费。Lv.5护卫弹，Lv.10余烬爆破。"
		}
	],
	[
		{
			"name": "贯日箭",
			"cd": 8.0,
			"text": "230像素巨型贯日箭，判定宽48，造成 (300% + 每级65%) 攻击伤害，贯穿12个目标；命中猎印额外240%范围星爆。"
		},
		{
			"name": "箭雨",
			"cd": 10.0,
			"text": "目标区域预示后落下 3 + 技能等级轮箭雨，每轮 50% 攻击；区域内普通箭获得两次额外弹射及 +25% 伤害。"
		},
		{
			"name": "猎印",
			"cd": 9.0,
			"text": "标记目标区域敌人 5 + 技能等级秒。标记供贯日箭、套装或传奇武器消耗，不会递归触发。"
		},
		{
			"name": "群星逐猎",
			"cd": 17.0,
			"text": "起手全场猎印→优先追击猎印/精英/首领→终结星坠。持续期间移速+20%，F强化追击，Q生成风暴域，C中E追加巨箭。"
		}
	]
]

const PASSIVES = [
	{"id":"power","name":"锋芒","branch":"输出","key":"attack_pct","amount":0.04,"max":3,"text":"每点攻击 +4%"},
	{"id":"focus","name":"凝神","branch":"输出","key":"crit","amount":0.02,"max":3,"text":"每点暴击率 +2 个百分点"},
	{"id":"vital","name":"坚韧","branch":"生存","key":"hp","amount":10.0,"max":3,"text":"每点最大生命 +10"},
	{"id":"guard","name":"铁壁","branch":"生存","key":"armor","amount":3.0,"max":3,"text":"每点防御 +3"},
	{"id":"flow","name":"灵流","branch":"机制","key":"cooldown","amount":0.03,"max":3,"text":"每点技能冷却缩短 3%"},
	{"id":"step","name":"轻灵","branch":"机制","key":"dash_cooldown","amount":0.05,"max":3,"text":"每点闪避冷却缩短 5%"}
]
const ITEMS = [
	{"id":"potion","name":"治疗药剂","price":35,"text":"恢复 35% 最大生命","cd":8.0},
	{"id":"barrier","name":"护盾卷轴","price":50,"text":"获得 45 点护盾，持续 8 秒","cd":12.0},
	{"id":"frost","name":"冰霜符文","price":50,"text":"全场敌人减速 5 秒；首领减速较弱","cd":12.0},
	{"id":"thunder","name":"雷霆符文","price":65,"text":"对周身 330 范围造成 250% 攻击伤害","cd":12.0},
	{"id":"magnet","name":"引力符石","price":25,"text":"立即收取战利品，并提高拾取范围 12 秒","cd":10.0},
	{"id":"sand","name":"时砂","price":85,"text":"当前主动技能剩余冷却减少 50%，不重置被动","cd":20.0}
]
const ACHIEVEMENTS = [
	{"id":"lulu","name":"噜噜的好朋友","text":"完成噜噜温泉的泡泡切磋","gold":180},
	{"id":"chapter1","name":"初入试炼","text":"首次完成第一章","gold":100},
	{"id":"boss","name":"破阵者","text":"首次击败章节首领","gold":80},
	{"id":"legend","name":"金色传说","text":"获得一件传奇装备","gold":120},
	{"id":"set6","name":"六器归一","text":"装备完整六件套","gold":150},
	{"id":"enhance10","name":"百炼成器","text":"强化一件装备至 +10","gold":150},
	{"id":"level15","name":"独当一面","text":"任一角色达到 15 级","gold":100},
	{"id":"combo","name":"心有灵犀","text":"首次触发技能组合","gold":80},
	{"id":"secret","name":"裂隙行者","text":"首次进入隐藏关卡","gold":150},
	{"id":"chapter4","name":"灾厄终结","text":"首次完成第四章","gold":300},
	{"id":"chapter6","name":"星蚀破晓","text":"完成第六章，开启深渊","gold":400},
	{"id":"abyss10","name":"深渊先驱","text":"完成深渊 10 层","gold":250},
	{"id":"abyss30","name":"破界行者","text":"完成深渊 30 层","gold":600}
]
const ENEMIES = ["追击者","冲锋兽","远程射手","重甲守卫","铁甲统领","灾厄核心","试炼守卫","荒野督军","镜渊守望者","护盾祭司","裂生虫","星蚀术士","熔炉巨像","星蚀领主","水豚噜噜"]
const ENEMY_TEXT = ["贴近后挥击，看到蓄力圆环及时离开。","红线蓄力后冲锋，横向闪避。","保持距离并发射单发弹丸。","缓慢重甲近战，防御较高。","冲锋、扇形弹幕、召唤；半血加快节奏。","环形弹幕留有缺口，扇形弹幕与地面预警；半血二阶段。","教学首领：慢速冲锋与稀疏扇形弹幕。","扇形射击与召唤小怪，保持走位。","镜渊中释放旋转缺口弹环和延迟双重落印。","每次蓄力给予附近同伴护盾；优先击杀可削弱敌群。","死亡分裂成两只幼体；幼体不再分裂，不重复掉落装备。","在玩家脚下锁定延迟落印；移动离开预警区。","交替熔炉火带与召唤护盾祭司；半血追加冲击波。","星蚀弹环留有缺口，二阶段追踪落印与术士支援。","噜噜温泉的主人：扇形泡泡、预警拍水、泡澡休息。半血增加泡泡数量。泡澡时没有无敌或回血，可以安心反击。"]
const STAT_NAMES = {"hp":"生命","armor":"防御","attack":"攻击","speed":"移速","crit":"暴击率","crit_damage":"暴击倍率","attack_pct":"攻击","rate_pct":"攻速","range_pct":"射程","cooldown":"技能冷却缩减","dash_cooldown":"闪避冷却缩减"}

static func xp_needed(level: int) -> int:
	if level>30:
		var extra = level-30
		return 3018+95*extra+2*extra*extra
	return 60 + 15*(level-1) + 3*(level-1)*(level-1)

static func upgrade_cost(next_level: int) -> Dictionary:
	return {"gold":25+9*next_level*next_level,"material":1+floori(next_level/3.0)}

static func set_text(role: int) -> Array:
	return [
		["2件：攻击 +8%","4件：飞剑额外穿透 1 名敌人，并获得返程","6件：剑阵期间每 4 次普攻追加 3 道剑气（追加攻击不再次触发）"],
		["2件：弹匣 +2","4件：换弹缩短 15%，首发额外 +25% 基础伤害","6件：强化首发产生半径 100 的 65% 攻击爆破（每 1 秒至多一次）"],
		["2件：暴击率 +5 个百分点","4件：远射被动额外 +15%，猎印持续更久","6件：普通箭命中猎印目标追加一道 70% 攻击箭（每 1 秒至多一次）"]
	][role]

static func special_text(role: int, hidden: bool = false) -> String:
	if hidden: return ["镜渊剑心：回锋步冷却额外缩短 15%","镜渊火种：战术装填强化持续额外 2 秒","镜渊星瞳：猎印范围额外扩大 70"][role]
	return ["返程剑命中后追加一道 45% 剑气，内置冷却 1 秒","强化首发命中后产生 60% 攻击爆破，内置冷却 1 秒","普通箭命中猎印时额外弹射 1 次，内置冷却 1 秒"][role]

static func stat_text(key: String, amount: float) -> String:
	var percent = key.ends_with("_pct") or key in ["crit","crit_damage","cooldown","dash_cooldown"]
	return "%s +%s%s" % [STAT_NAMES.get(key,key),str(snappedf(amount*(100 if percent else 1),0.1)),"%" if percent else ""]

static func skill_milestones(slot: int) -> String:
	var fifth = ["追加双重落印","强化穿透/扩展覆盖","强化弹更多/猎印延长/路径增伤","穿透连射+双重落印"][slot]
	return "3级：增强施法光环；5级：%s；8级：施法获得 8%% 生命护盾（4秒）；10级：其他技能冷却 -0.75秒。"%fifth

static func earned_points(level: int) -> int:
	return 2*(level-1)+2*floori(mini(level,30)/5.0)
