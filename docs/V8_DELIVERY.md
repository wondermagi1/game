# 第八版交付说明

## 实际完成范围

本轮集中完成角色战斗动作、三职业终极技能层次、组合技可读性、深渊长期成长和输入手感。第七版已经完成的构筑、敌群、地图、装备、UI、Boss与存档系统保持启用，并重新通过当前基线测试。

主要代码位于：

- `scripts/actor_integrated.gd`：完整持械动作形变、八相位移动衔接和三职业攻击运动。
- `scripts/material_fx.gd`、`scripts/skill_art.gd`、`scripts/ultimate_controller.gd`：终极技能聚势、持续、命中、终结和残留层。
- `scripts/skill_controller.gd`、`scripts/ui_v7.gd`：组合技窗口、HUD提示、中央反馈和战报计数。
- `scripts/buff_progression.gd`、`scripts/stats.gd`、`scripts/game.gd`：深渊四阶质变、循环突破、事件和安全数值转换。
- `scripts/player.gd`：普攻/技能输入缓冲、动作收势和闪避取消。

## 验证结果

当前版本专项与兼容基线共 **785 项断言通过**：V8 输入 20、深渊 20、组合技 21、终极技能视觉 23、动作 57、V7 96、V6 548。Godot 脚本检查通过。测试环境会输出 Windows 系统证书读取提示；它不属于游戏脚本错误。历史 V3 回归仍保留一条旧强化价格断言（期望 45 金币，当前平衡值为 34），因此没有计入当前基线。

## 验收画面

- `docs/screenshots-v8/01-role-attack-motion.png`：三职业攻击动作。
- `docs/screenshots-v8/02-ultimate-*-sustain.png`、`03-ultimate-*-finish.png`：三个 C 技能。
- `docs/screenshots-v8/04-combo-ready-*.png`：三职业组合技就绪 HUD。
- `docs/screenshots-v8/05-abyss-buff-progression.png`：深渊 Buff 阶段与下一节点。
- `docs/screenshots-v8/06-chapter-two-route-map.png`：第二章分支地图。
- `docs/screenshots-v8/07-legendary-equipment.png`：传奇装备信息与流派机制。
- `docs/screenshots-v8/08-lulu-boss-intro.png`：噜噜 Boss 入场。
- `docs/screenshots-v8/09-detailed-run-report.png`：构筑与战斗统计。

## 美术边界

角色当前仍是“完整角色与武器图片 + 程序网格形变”的稳定方案。新增的中间动作属于程序补间和局部变形，并非新绘制的逐帧原画。C 技能新增了多层材质、图形、冲击和残留效果，但部分纹理仍为代码生成或工程内占位资源。要达到商业成品质量，仍需动画师制作四主方向关键帧，再人工校正八方向；同时需要为九套流派补专属贴图序列和分层音频。

## 下一阶段优先级

1. 为剑修巨剑、火枪爆破、游侠巨箭各制作一套最终关键帧、贴图序列与分层音效，建立九流派的成品质量基准。
2. 重做第二章“逐火之牙”的战旗交互、破防窗口和封印支路联动，并进行三职业九场真人流程测试，把完整路线稳定在约 7～8 分钟。
3. 把战报继续扩展到房间耗时、Buff/装备触发次数与组合技实际伤害，依据真人数据调整无效奖励率和敌群模板。
