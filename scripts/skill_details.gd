extends RefCounted
static func effect(role: int, slot: int, rank: int) -> String:
	if slot==3:
		if role==0:
			var hits = 8+floori((rank-1)*4.0/9)
			var start = 2.5+(rank-1)/6.0
			var tick = 1+(rank-1)/15.0
			var finish = 6.5+(rank-1)*3.5/9.0
			return "聚剑 %.0f%% + %d 次落剑 × %.0f%% + 巨剑终结 %.0f%%；基础完整预算 %.0f%% 攻击。范围 %.0f，持续 3.5 秒。"%[start*100,hits,tick*100,finish*100,(start+hits*tick+finish)*100,230+(35 if rank>=3 else 0)+(30 if rank>=10 else 0)]
		if role==1: return "%.1f 秒重火力，最多 %d 发 × %.1f%% 攻击；终结爆破 %.0f%%。有目标才发射，Lv.5 增加护卫弹。"%[4.5+(rank-1)*0.15,24+rank*2,(0.65+0.035*rank)*100,(5+rank*0.35)*100]
		return "%.1f 秒追猎，最多 %d 发 × %.1f%% 攻击；终结星坠 %.0f%%。优先猎印/首领，期间移速 +20%%。"%[4.5+(rank-1)*0.15,10+rank,(0.85+0.045*rank)*100,(5+rank*0.35)*100]
	if role==0 and slot==1: return "巨剑 %.0f%% 攻击，贯穿 10 个目标；宽度 %.0f，8 秒剑印。Lv.5 两把护卫剑，Lv.8 重复剑印追加 80%% 范围斩。"%[(2.8+rank*0.5)*100,2*(24+(8 if rank>=3 else 0))]
	if role==2 and slot==0: return "巨型贯日箭 %.0f%% 攻击，宽度 48，贯穿 12 个目标。猎印触发额外 240%% 范围星爆。"%[(3+rank*0.65)*100]
	if role==0 and slot==0: return "剑阵 %.1f 秒，半径 %d；每 0.25 秒 %.0f%% 攻击，Lv.3 追加五道 50%% 剑气。"%[minf(12,3+rank-1),150+(rank-1)*20,(0.45+0.04*(rank-1))*100]
	if role==0 and slot==2: return "无敌冲刺，三段路径剑气各 %.0f%%；E 中追加 180%% 范围斩，C 中追加一次 300%% 横向剑潮。"%[(0.6+0.2*rank)*100]
	if role==1 and slot==0: return "爆破 %.0f%% 攻击，半径 %d；6 秒火药标记供 F 强化弹引爆 200%%。"%[(2.1+rank*0.4)*100,160+10*(rank-1)]
	if role==1 and slot==1: return "%d 发霰弹 × %.0f%% 攻击，8 秒火药标记。Lv.5 穿透 2；普攻/C 消耗标记追加 110%% 爆破。"%[mini(9,4+rank),(0.45+0.05*maxi(0,rank-5))*100]
	if role==1 and slot==2: return "立即装填，攻速 +35%% 持续 %d 秒；%d 发强化弹；Lv.3 护盾 30。"%[4+rank,3+(1 if rank>=5 else 0)+(2 if rank>=8 else 0)]
	if role==2 and slot==1: return "%d 次箭雨 × 50%% 攻击，半径 %d；区域普攻弹射 +2、伤害 +25%%，8 秒内接 C 形成风暴箭域。"%[3+rank,170+(20 if rank>=3 else 0)]
	return "猎印持续 %d 秒，半径 %d；8 秒内接 C 强化追猎与终结，接 E 触发星爆。"%[6+rank,210+(50 if rank>=5 else 0)]
static func milestones(role: int, slot: int) -> String:
	if slot==3:
		return ["3级：扩大并追踪剑阵；5级：终结交叉斩形态；8级：更大终结主剑；10级：觉醒余阵三次 60% 伤害。","3级：持续与火力成长；5级：护卫弹 / 穿透3；8级：重型终结形态；10级：爆破余烬三次 60% 伤害。","3级：持续与追猎成长；5级：护卫箭 / 穿透3；8级：大型星坠形态；10级：星落余阵三次 60% 伤害。"][role]
	if role==0 and slot==1: return "3级：宽度64；5级：双护卫剑；8级：剑印扩散；10级：主剑250像素并返还其他技能0.75秒。"
	return "3级：职业基础效果进阶；5级：穿透/范围/护卫强化；8级：施法护盾8%生命；10级：其他技能冷却-0.75秒。详见当前效果。"
