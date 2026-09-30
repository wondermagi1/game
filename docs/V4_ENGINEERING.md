# 第四版模块入口

| 模块 | 职责 |
|---|---|
| catalog.gd / profile.gd | 点数公式、门槛、强化、持久化迁移 |
| loot_rules.gd | 分章条件品质、职业适配、首领传奇保底 |
| room_graph.gd | 稳定房间ID、约束连接、地图随机 |
| room_run.gd | 当前房间生命周期、波次、奖励、交互、探索检查点 |
| room_template.gd / scenes/rooms/*.tscn | 可编辑障碍、边界、门、世界安全位置、导航和绘制 |
| breakable_cover.gd | 有实际碰撞的可破坏木箱 |
| room_events.gd | 六类事件选项、成本、真实效果 |
| ultimate_controller.gd | 三职业C分阶段、有界伤害次数和连携 |
| skill_controller.gd / projectile.gd | 常规技能、独立来源、宽弹体扫掠及地形 |
| skill_art.gd / effects.gd / sound.gd | 剑箭轮廓、有限装饰池、三段合成音 |
| ui_v4.gd / exploration_map.gd | 当前规则UI、技能对比、事件、首通、地图 |
| abyss_run.gd / wave_director.gd | 深渊及旧检查点兼容 |

新UI继承第三版滚动/焦点与输入捕获修复。interface.gd现在继承ui_v4.gd。

测试入口（Godot `--headless --path 工程路径 --script res://tests/文件.gd --fixed-fps 60`）：regression_v4.gd、integration_v4.gd、rooms_v4.gd、autoplay_v4.gd、abyss_combat_v4.gd。integration使用res://tests/isolated_v4_profile.json隔离真实磁盘测试，不接触用户档。

渲染测试stress_v4.gd不要加headless或fixed-fps。capture_v4.gd是静态截图，movie_v4.gd通过Godot的write-movie输出带引擎内录音的演示。技能录像为明确标注的训练靶，不代表推荐构筑秒伤或正常存档能点满所有技能。

运行期上限：敌人32、弹体450、范围区40、技能主体64、装饰粒子240、浮字80、轨迹350、符阵30；低特效降低装饰池使用量。饱和友方弹体按来源合并伤害，防止超高Buff增长完全丢失。实体伤害不随装饰剑影数量增加。敌人避障缓存0.16秒，避免每个敌人每帧重算路径。
