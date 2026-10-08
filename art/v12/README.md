# 日式 2.5D 像素庭院素材

生成方式：本会话内置 imagegen，共五次生成/编辑：地表初稿、透明景物初稿、图集排布修整、地表像素风重绘、景物像素风重绘。由生成结果接入 Godot 并经过实际渲染检查；不标注为人工逐像素手绘或实时 3D 建模。

| 文件 | 用途 | 格式 |
|---|---|---|
| garden/ground_pixel.png | 当前使用的像素地表 | 1448×1086 RGB |
| garden/props_pixel.png | 当前使用的神社、鸟居、樱树、竹林、灯笼、小神龛 | 1536×1024 RGBA，真实透明通道 |
| garden/ground.png | 像素重绘前的布局母稿 | 1448×1086 RGB |
| garden/props_refined.png | 像素重绘前的景物母稿 | 1536×1024 RGBA |
| garden/foliage.gdshader | 根部固定的轻微树冠摆动 | 原生 CanvasItem shader |
| garden/water.gdshader | 限定在池塘轮廓里的水面变化 | 原生 CanvasItem shader |

游戏直接使用 AtlasTexture 区域，不对母稿进行破坏性裁切。每个景物使用独立脚底位置与碰撞；图集每格中的空白不是碰撞形状。

参考来源是用户附的日式庭院画面，只参考构图、空间层次和配色；未提取或复制该视频中的游戏资产。提示词与制作约束见 [GENERATION_PROMPTS.md](GENERATION_PROMPTS.md)。
