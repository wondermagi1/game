# 美术素材与生成记录

第二版使用 imagegen 技能及内置 image_gen 工具生成一张三角色透明图集，直接复制为 `art/heroes-v2.png`，1774×887 RGBA。未使用外部付费素材、下载素材或 Python 图像重绘。角色造型为本项目生成的开发素材；不作独家性或法律权利保证。

原始生成文件：`C:/Users/GXR/.codex/generated_images/01a0beeb-dd07-7470-9ae8-1a3640283063/exec-26ac7651-c342-49b2-a13e-010ddca9a5ca.png`。工程包含副本，不依赖这个外部路径。

完整生成提示词：

> Use case: stylized-concept. Asset type: transparent game character sprite atlas for a top-down 2D fantasy roguelite. ONE horizontal atlas containing exactly THREE full-body characters, equal-sized, in three equal-width columns. Transparent alpha background. Each character fully contained with generous empty gutters inside their own third, feet at same baseline and top at same height, no overlap between thirds. Left: elegant male Chinese flying-sword cultivator, teal and ivory flowing robe, long black hair, silver floating sword, refined face. Center: rugged female flintlock gunner, warm brown leather long coat, brass trim, tricorn hat, silver hair, holds compact long flintlock firearm. Right: agile female elven archer, deep purple hood, forest-green cloak, curved golden bow, silver-white hair. Camera elevated three-quarter top-down 35 degrees, all facing down-right ready stance. Premium hand-painted fantasy RPG game sprite style, clear silhouettes, illustrated cel shading, moderately chibi 3.5-head proportions, detailed clothing yet legible at small size. Entire bodies including weapons and feet visible. Characters rendered on genuinely transparent background, no panels, no ground, no labels, no text, no logos, no watermark, no scene, no cast shadow. Wide landscape sheet with each character centered at x=1/6, 1/2, 5/6 of image width. Consistent scale and lighting.

图集实际采用 AtlasTexture 区域：剑修 `(0,0,673,887)`，火枪手 `(674,0,526,887)`，游侠 `(1202,0,572,887)`。该分区依据输出图像实际人物边界调整，图集本体未做裁剪修改。actor_visual.gd 的英雄逻辑高度为 112；菜单和角色画廊复用同一素材。

`art/icons/0.svg` 至 `18.svg` 为本次编写的简洁线条图标，覆盖武器、装备部位、技能和物品，不是 AI 位图。场地、敌人轮廓、法阵、拖尾、粒子和阴影由 Godot 绘制。

当前动作表现是单图配合位移、浮动、缩放、镜像、受击闪烁和死亡淡出，不是完整逐帧动画或骨骼动画。镜像瞄准不等于四/八方向完整动作。后续可在 CharacterVisual.tscn 内替换为 AnimatedSprite2D 或骨骼节点，保留上层战斗接口。普通怪、首领、地面环境及声音仍为简化占位内容；没有使用实时 3D 渲染。

## 第三版追加

第三版复用角色图集，没有重新生成位图。新增敌人轮廓、技能进阶法阵、爆破光环、强化弹、通知动画和危险描边均由 GDScript 绘制。新增声音由 sound.gd 合成，不依赖外部音频文件。
