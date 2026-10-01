extends RefCounted
## Version 7 build definitions. One branch is chosen per active skill and then
## advanced through three finite tiers. Branch index also forms the role's
## primary archetype, so four matching skills create a coherent build.

const BUILD_NAMES = [
	["剑阵流","巨剑流","回锋流"],
	["炽焰连射流","爆破重炮流","精准猎杀流"],
	["风暴箭雨流","穿云巨箭流","游猎机关流"]
]

const BUILD_TAGS = [
	[["飞剑","召唤","控制"],["巨剑","蓄力","破甲"],["回锋","穿透","机动"]],
	[["燃烧","弹药","攻速"],["爆炸","重炮","范围"],["标记","暴击","处决"]],
	[["箭雨","控制","持续"],["蓄力","穿透","巨箭"],["陷阱","弹射","游猎"]]
]

# role, slot, branch, display name, three behavior-changing tier descriptions.
const BRANCHES = [
	[0,0,0,"护体剑轮",["剑阵增加两把护体飞剑，并扩大拦截范围。","剑轮会主动追击附近精英，收阵时齐射。","收阵产生剑域，短时间拦截敌方弹幕。"]],
	[0,0,1,"天坠剑胚",["展开剑阵时同时投下一柄巨剑。","巨剑落点留下破甲剑痕。","剑痕汇聚为第二次天坠斩。"]],
	[0,0,2,"往复剑环",["剑阵飞剑命中后折返，再次造成伤害。","完美回收飞剑会缩短回锋步冷却。","折返飞剑分裂为两道交叉剑气。"]],
	[0,1,0,"剑阵先锋",["穿云剑命中后召出三把护卫剑。","护卫剑锁定精英并留下剑印。","剑印目标被剑阵命中时引发连锁剑爆。"]],
	[0,1,1,"山河巨刃",["穿云剑体积与判定大幅增加并击退普通怪。","蓄力剑获得破甲和更强命中停顿。","命中Boss后引发延迟山河斩。"]],
	[0,1,2,"折返穿云",["穿云剑抵达终点后返回角色。","回程必定暴击被剑印标记的目标。","每次穿透会增加回程伤害。"]],
	[0,2,0,"御剑回旋",["回锋步结束时展开短暂旋转剑阵。","冲刺路径上的剑气向玩家位置回收。","完美闪避会立刻完成一次剑阵齐射。"]],
	[0,2,1,"断岳踏",["冲刺终点产生重型剑压。","剑压击破护甲并短暂减速Boss。","连续命中时形成十字巨剑震荡。"]],
	[0,2,2,"燕返",["回锋步可以在短时间内再次反向释放。","第二段冲刺沿原路径追加回程剑气。","完成往返后重置普通攻击并获得暴击。"]],
	[0,3,0,"万剑天幕",["万剑归宗增加剑雨数量与覆盖范围。","剑雨优先锁定精英并生成护体剑。","终结后留下持续剑阵，自动拦截弹幕。"]],
	[0,3,1,"归宗巨剑",["万剑汇聚为超大型巨剑终结。","巨剑落地产生三层冲击波与剑痕。","Boss受到额外破甲，终结伤害再次提升。"]],
	[0,3,2,"轮回剑河",["剑雨落下后向玩家位置折返。","去程与回程命中不同目标时产生剑爆。","终结巨剑分裂成八道回锋剑潮。"]],

	[1,0,0,"灼热弹芯",["爆破弹留下持续燃烧区并积累热量。","高热状态扩大燃烧区且提高持续伤害。","过热时爆破弹自动分裂为三枚火种。"]],
	[1,0,1,"攻城榴弹",["爆破弹变为更慢、更大的重型榴弹。","爆炸产生二次冲击环并可引爆火药区。","命中Boss时附着延迟炸弹。"]],
	[1,0,2,"弱点爆弹",["爆破弹为目标叠加两层猎杀标记。","完整标记被引爆时返还弹药。","处决低生命目标后将标记传给附近敌人。"]],
	[1,1,0,"炽焰霰幕",["霰弹命中增加热量并施加燃烧。","高热时霰弹收束且穿透一名敌人。","主动散热会向四周释放一圈火焰霰弹。"]],
	[1,1,1,"爆裂弹幕",["每第三枚霰弹变为小型爆裂弹。","同一目标被多枚命中会触发聚合爆炸。","爆炸击杀会产生一枚追踪榴弹。"]],
	[1,1,2,"猎手齐射",["霰弹集中在准星附近并叠加标记。","满标目标会暴露弱点并受到额外暴击伤害。","击破弱点立即装填两发弹药。"]],
	[1,2,0,"红线装填",["战术装填获得热量增伤，停火可快速散热。","高热强化弹附带火焰轨迹。","过热不再完全停火，而是释放一次泄压爆燃。"]],
	[1,2,1,"重炮装药",["强化弹获得范围爆炸和明显后坐力。","前三发分别触发火光、烟雾和冲击波。","最后一发变为无消耗的攻城弹。"]],
	[1,2,2,"处决装填",["装填后自动锁定生命最低的标记目标。","强化弹暴击会返还一发弹药。","处决目标立即重置爆破弹冷却。"]],
	[1,3,0,"炼狱过载",["炼狱火力期间进入高热连射。","连续命中提高射速，停火后释放泄压火环。","终结时消耗热量形成持续火焰风暴。"]],
	[1,3,1,"末日炮列",["持续射击改为重炮弹幕。","每第四发触发大范围链式爆炸。","终结生成三枚延迟攻城炸弹。"]],
	[1,3,2,"死亡准星",["大招自动锁定标记和精英目标。","弱点暴击缩短下一轮射击间隔。","终结处决低生命目标并转移剩余标记。"]],

	[2,0,0,"风暴贯日",["贯日箭经过处生成持续风压通道。","通道内会落下小型追踪箭雨。","命中多个目标后召来第二轮风暴巨箭。"]],
	[2,0,1,"破界巨箭",["贯日箭尺寸、蓄力光效和贯穿宽度大幅增加。","完美蓄力获得Boss破甲与必定暴击。","箭矢末端产生贯穿全屏的第二道风压。"]],
	[2,0,2,"折跃猎矢",["贯日箭命中墙体后向目标折射。","每次折射在地面放置一个爆裂陷阱。","陷阱连线形成可重复触发的狩猎区域。"]],
	[2,1,0,"追风箭雨",["箭雨区域缓慢跟随玩家移动。","击杀会延长箭雨并扩大覆盖范围。","箭雨结束时形成持续风暴眼。"]],
	[2,1,1,"天穹箭柱",["箭雨中心周期性落下大型灵能箭。","巨箭落地后产生穿透冲击线。","最后一轮变为覆盖房间中央的天穹箭柱。"]],
	[2,1,2,"机关箭场",["箭雨边缘布置减速绊索。","绊索触发时弹射三支追踪箭。","多个陷阱相互连接并共享暴击。"]],
	[2,2,0,"风眼猎印",["猎印区域生成吸附敌人的风眼。","标记目标死亡会延长风眼持续时间。","风眼消失时释放一次全向箭雨。"]],
	[2,2,1,"穿云锁定",["猎印使巨箭蓄力更快并扩大弱点。","完美蓄力消耗标记造成破甲。","标记Boss后生成可贯穿的巨大弱点线。"]],
	[2,2,2,"猎场机关",["猎印区域内自动生成两个诱饵陷阱。","敌人触发陷阱后箭矢可额外弹射。","陷阱爆炸会刷新附近猎印。"]],
	[2,3,0,"群星风暴",["群星逐猎期间持续生成移动箭雨。","每次击杀扩大风暴并追加追踪箭。","终结时形成全屏但保留安全边界的星风暴。"]],
	[2,3,1,"逐日神箭",["大招终结改为超大型贯日箭。","蓄力阶段锁定直线上的全部弱点。","终结巨箭留下贯穿场地的星光通道。"]],
	[2,3,2,"星罗猎场",["大招期间自动布置陷阱与诱饵。","追击箭会在陷阱之间弹射。","终结同时引爆全部陷阱并重建猎印。"]]
]

const ELITE_MODIFIERS = [
	{"id":"swift","name":"迅捷","text":"移动与攻击节奏更快，生命增幅较低。","color":"#76ddc7","reward":1.15},
	{"id":"armored","name":"坚甲","text":"拥有可击破护甲，破甲后短暂虚弱。","color":"#9eb4d2","reward":1.20},
	{"id":"volatile","name":"爆裂","text":"死亡后产生延迟爆炸，可伤及其他敌人。","color":"#ff9d6c","reward":1.20},
	{"id":"commander","name":"指挥","text":"强化附近普通怪，优先击杀可解除强化。","color":"#e1c16b","reward":1.25},
	{"id":"draining","name":"吸能","text":"命中后短暂延长技能冷却，具有触发间隔。","color":"#bd91e8","reward":1.20},
	{"id":"mirror","name":"镜影","text":"周期生成低生命幻影，幻影不会掉落战利品。","color":"#87c8ef","reward":1.25}
]

const ROOM_OBJECTIVES = [
	{"id":"defend","name":"灵石坚守","text":"守护中央灵石直到计时结束。","reward":"强化材料与防御类馈赠"},
	{"id":"hunt","name":"悬赏追猎","text":"在敌群中击败会逃跑的悬赏目标。","reward":"金币与定向装备"},
	{"id":"seal","name":"三阵封印","text":"依次激活并守住三处阵眼。","reward":"高阶技能进化权重"}
]

# Epic and legendary equipment receives one behavior hook. The branch index is
# shared with BUILD_NAMES/BUILD_TAGS so equipment can support a chosen route.
const GEAR_MECHANICS = [
	[
		{"id":"sword_guard","name":"归阵护锋","text":"剑阵飞剑数量增加；收阵时获得短暂护盾。"},
		{"id":"sword_scar","name":"断岳剑痕","text":"巨剑体积与伤害提高，命中会留下更强冲击。"},
		{"id":"sword_return","name":"双生回锋","text":"回锋弹体获得额外穿透和一次弹射。"}
	],
	[
		{"id":"gun_heat","name":"赤烬散热器","text":"提高过热阈值，并强化高热状态伤害。"},
		{"id":"gun_reload","name":"爆破解闩","text":"爆炸技能范围扩大；爆炸击杀可返还弹药。"},
		{"id":"gun_mark","name":"猎魔准镜","text":"弱点路线提高暴击，完整标记更易处决。"}
	],
	[
		{"id":"bow_storm","name":"逐风箭羽","text":"风暴区域持续次数增加，并扩大移动控场。"},
		{"id":"bow_giant","name":"破界弓臂","text":"巨箭更宽更长，并提高完美蓄力伤害。"},
		{"id":"bow_trap","name":"星罗机括","text":"陷阱额外触发一次，并让箭矢增加弹射。"}
	]
]

const CAMP_NPC = "守灯人 · 砚秋"
const CAMP_LINES = {
	"new":"荒野的灯一盏盏熄了。去第二章时，替我看看是谁在收走火种。",
	"entered":"督军并非只在掠夺。他守着一扇朝地下吹风的旧门。",
	"failed":"败退并不可耻。记住它抬起战旗后的停顿，那就是下一次的破绽。",
	"cleared":"荒野重新亮了，但裂隙深处传来的风更冷了。第三章会给你答案。",
	"secret":"你找到了镜渊留下的旧印。有人在六座试炼之外，记录我们的每一次选择。"
}
const CHAPTER_TWO_ROLE_LINES = [
	"剑修：你的战旗压不住我的剑阵。",
	"火枪手：站稳了，下一声枪响会穿过你的号令。",
	"游侠：你守着路口，我会从风里找到另一条路。"
]

static func gear_mechanic(role: int, branch_index: int) -> Dictionary:
	return GEAR_MECHANICS[clampi(role,0,2)][clampi(branch_index,0,2)]

static func branch(role: int, slot: int, branch_index: int) -> Array:
	for entry in BRANCHES:
		if int(entry[0])==role and int(entry[1])==slot and int(entry[2])==branch_index: return entry
	return []

static func evolution_id(role: int, slot: int, branch_index: int, tier: int) -> String:
	return "evo_%d_%d_%d_%d" % [role,slot,branch_index,tier]

static func choice(role: int, slot: int, branch_index: int, tier: int) -> Array:
	var entry = branch(role,slot,branch_index)
	if entry.is_empty(): return []
	var tags: Array = BUILD_TAGS[role][branch_index]
	var title = "%s · %s %d阶" % [entry[3],BUILD_NAMES[role][branch_index],tier]
	var text = "%s\n标签：%s" % [entry[4][tier-1]," / ".join(tags)]
	return [evolution_id(role,slot,branch_index,tier),title,text,"evolution",float(tier),3,mini(2,tier-1),role]

static func parse_id(id: String) -> Dictionary:
	var parts = id.split("_")
	if parts.size()!=5 or parts[0]!="evo": return {}
	return {"role":int(parts[1]),"slot":int(parts[2]),"branch":int(parts[3]),"tier":int(parts[4])}

static func role_codex(role: int) -> String:
	var lines: Array[String] = []
	for branch_index in range(3):
		lines.append("%s：%s" % [BUILD_NAMES[role][branch_index]," / ".join(BUILD_TAGS[role][branch_index])])
	return "\n".join(lines)
