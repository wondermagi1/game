extends Control
## Standalone, profile-free inspection. Shared frames are labelled honestly.
signal closed
var actor
var running=true
var elapsed: float=0
var speed: float=1
var state: String="combat"
var effects_intensity: float=.65
var art
var particles=preload("res://scripts/material_fx.gd").new()
var phase_slider: HSlider
var info: Label
var skill_rank: int=1
var frame_label: Label
var particle_layer
const ACTIONS=["ready","run_forward","run_back","strafe_left","attack","dash","hurt","skill_0","skill_1","skill_2","ultimate_gather","ultimate_sustain","ultimate_finish","combo","death"]
const NAMES=["持械待机","前进","后撤","横移","普攻","闪避","受击","技能一","技能二","技能三","C 聚势","C 维持","C 终结","连携","退场"]
var selected_action=0
func text(value: String, pos: Vector2, font_size: int=24) -> Label:
	var label=Label.new();label.text=value;label.position=pos;label.add_theme_font_size_override("font_size",font_size);add_child(label);return label
func choose(items: Array, pos: Vector2, callback: Callable) -> OptionButton:
	var b=OptionButton.new();b.position=pos;b.size=Vector2(310,50)
	b.add_theme_font_size_override("font_size",24)
	for item in items:b.add_item(str(item))
	b.item_selected.connect(callback);add_child(b);return b
func button(value: String,pos: Vector2,callback: Callable) -> void:
	var b=Button.new();b.text=value;b.position=pos;b.size=Vector2(145,45);b.pressed.connect(callback);add_child(b)
	b.add_theme_font_size_override("font_size",23)
func _ready() -> void:
	set_anchors_preset(Control.PRESET_TOP_LEFT);size=Vector2(1920,1080)
	var bg=ColorRect.new();bg.size=size;bg.color=Color("#111e2a");add_child(bg)
	var font=SystemFont.new();font.font_names=PackedStringArray(["Microsoft YaHei UI","Microsoft YaHei"]);add_theme_font_override("font",font)
	text("持械动作 · 检视室",Vector2(80,45),42)
	text("完整人物与武器共同绘制；红点为视觉出手位置，青点为脚底。",Vector2(80,110),23)
	actor=preload("res://scripts/actor_visual.gd").new();actor.position=Vector2(790,770);actor.scale=Vector2.ONE*3.8;actor.debug_joints=true;actor.set_process(false);add_child(actor);actor.set_process(false)
	art=preload("res://scripts/skill_art.gd").new();art.game=self;add_child(art)
	particle_layer=preload("res://scripts/material_fx_layer.gd").new();particle_layer.system=particles;particle_layer.z_index=24;add_child(particle_layer)
	choose(["御剑 · 剑修","火药 · 火枪手","长弓 · 游侠"],Vector2(90,220),func(i):actor.kind=i;refresh())
	choose(NAMES,Vector2(90,290),func(i):selected_action=i;refresh())
	choose(["右","右下","下","左下","左","左上","上","右上"],Vector2(90,360),func(i):actor.aim=Vector2.from_angle(i*PI/4);refresh())
	choose(["0.25 倍速","0.5 倍速","正常速度","1.5 倍速"],Vector2(90,430),func(i):speed=[.25,.5,1,1.5][i]).select(2)
	choose(["普通","稀有","史诗","传奇"],Vector2(90,500),func(i):actor.quality=i)
	choose(["技能 Lv.1","技能 Lv.5","技能 Lv.10"],Vector2(90,570),func(i):skill_rank=[1,5,10][i])
	button("播放 / 暂停",Vector2(90,660),func():running=not running)
	button("前进一帧",Vector2(255,660),func():running=false;advance(1.0/60))
	button("触发特效",Vector2(90,725),emit_preview)
	button("标记开关",Vector2(255,725),func():actor.debug_joints=not actor.debug_joints)
	phase_slider=HSlider.new();phase_slider.position=Vector2(90,805);phase_slider.size=Vector2(310,40);phase_slider.min_value=0;phase_slider.max_value=1;phase_slider.step=.01
	phase_slider.value_changed.connect(func(v):running=false;elapsed=v;advance(0));add_child(phase_slider)
	text("拖动时间轴逐帧观察",Vector2(90,855),21)
	text("原版完整持械立绘 · 对照",Vector2(1280,210),28)
	var classic=TextureRect.new();classic.name="Classic";classic.position=Vector2(1260,320);classic.size=Vector2(430,580);classic.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;classic.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;add_child(classic)
	info=text("",Vector2(530,890),22)
	frame_label=text("",Vector2(530,930),21)
	text("当前基础图集：每职业 8 朝向 × 4 帧组。技能暂共用释放姿态，并非 25 套独立动作。",Vector2(80,1000),21)
	button("返回",Vector2(1680,55),func():closed.emit();queue_free())
	refresh()
func refresh() -> void:
	elapsed=0;actor.clip=ACTIONS[selected_action];actor.forced_clip=actor.clip;actor.clip_length=1
	actor.dying=actor.clip=="death";actor.death_time=0
	actor.movement=actor.aim*(.7 if actor.clip.begins_with("run") else (-.7 if actor.clip=="strafe_left" else 0))
	var texture=AtlasTexture.new();texture.atlas=preload("res://art/heroes-v2.png");texture.region=[Rect2(0,0,662,850),Rect2(690,0,500,850),Rect2(1205,0,575,850)][actor.kind]
	get_node("Classic").texture=texture
	advance(0)
func advance(delta: float) -> void:
	elapsed=fposmod(elapsed+delta,1);actor.override_phase=elapsed;actor.clip_time=elapsed
	actor._process(delta);actor.death_time=elapsed if actor.dying else 0
	phase_slider.set_value_no_signal(elapsed)
	info.text="%s  /  朝向 %d  /  时间 %.2f 秒"%[NAMES[selected_action],actor.facing_index,elapsed]
	frame_label.text="帧组 %d · 八方向为离散朝向；部分弓箭朝向仍需补画精修。"%actor.selected_row
	actor.queue_redraw()
func emit_preview() -> void:
	var p=actor.position+actor.muzzle_local()*actor.scale
	particles.emit("shot",p,actor.aim,actor.kind,1,effects_intensity)
	if actor.kind==1:art.emit("muzzle",p,actor.aim,85,.13,1)
	if selected_action>=7:
		var target=Vector2(1090,730)
		particles.emit("ultimate",target,actor.aim,actor.kind,2+skill_rank*.2,effects_intensity)
		art.emit("blast" if actor.kind==1 else "finish",target,actor.aim,180+skill_rank*12,.7,actor.kind)
func _process(delta: float) -> void:
	if running:advance(delta*speed)
	particles.tick(delta*speed if running else 0)
	art.set_process(running)
	queue_redraw()
	particle_layer.queue_redraw()
