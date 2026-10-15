extends CharacterBody3D
const Western = preload("res://scripts/western_art.gd")
var role: int = 0
var enemy_kind: int = -1
var hp: float = 100
var max_hp: float = 100
var boss: bool = false
var alive: bool = true
var attack_clock: float = 1.0
var windup: float = 0
var stun: float = 0
var hit_flash: float = 0
var aim = Vector3.FORWARD
var visual
var sprite: Sprite3D
var viewport: SubViewport
var bar: Label3D
var origin_site: String = ""

func _ready() -> void:
	collision_layer = 2 if enemy_kind<0 else 4
	collision_mask = 1|4 if enemy_kind<0 else 1|2|4
	floor_snap_length = .8
	var shape = CollisionShape3D.new()
	var capsule = CapsuleShape3D.new()
	capsule.radius = .43 if not boss else .9
	capsule.height = 1.8 if not boss else 3.2
	shape.shape = capsule
	shape.position.y = capsule.height*.5
	add_child(shape)
	sprite = Sprite3D.new()
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sprite.shaded = true
	sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	sprite.alpha_scissor_threshold = .12
	sprite.double_sided = true
	add_child(sprite)
	if enemy_kind<0:
		viewport = SubViewport.new()
		viewport.name = "AnimatedCharacterCanvas"
		viewport.size = Vector2i(384,384)
		viewport.transparent_bg = true
		viewport.disable_3d = true
		viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		add_child(viewport)
		visual = preload("res://scripts/actor_visual.gd").new()
		visual.kind = role
		visual.position = Vector2(192,335)
		visual.scale = Vector2.ONE*1.65
		viewport.add_child(visual)
		sprite.texture = viewport.get_texture()
		sprite.pixel_size = .012
		sprite.position.y = 1.716
	else:
		var atlas = AtlasTexture.new()
		atlas.atlas = Western.texture(Western.MONSTER_PATH)
		atlas.region = Western.region(Western.MONSTER_PATH,Western.MONSTER_CELLS[enemy_kind],4,4)
		sprite.texture = atlas
		var height = 4.2 if boss else 1.95
		sprite.pixel_size = height/atlas.region.size.y
		sprite.position.y = height*.5
		bar = Label3D.new()
		bar.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		bar.position.y = height+.45
		bar.pixel_size = .009
		bar.font_size = 30
		bar.outline_size = 7
		bar.modulate = Color("#f3c68a") if boss else Color("#f4dfbd")
		add_child(bar)

func sync_visual(delta: float,screen_aim: Vector2) -> void:
	hit_flash = maxf(0,hit_flash-delta)
	sprite.modulate = Color(1.55,1.35,1.15) if hit_flash>0 else Color.WHITE
	if visual!=null:
		visual.aim = screen_aim
		visual.movement = Vector2(velocity.x,velocity.z)/7
		visual.walking = minf(1,velocity.length()/7)
	elif bar!=null:
		bar.text = ("霜角守望者  " if boss else "")+"%d / %d"%[ceil(hp),max_hp]
		sprite.flip_h = screen_aim.x<0

func gesture(id: String,duration: float) -> void:
	if visual!=null: visual.play_gesture(id,duration)

func set_animation_running(value: bool) -> void:
	if visual!=null: visual.set_process(value)

func damage(amount: float) -> bool:
	if not alive: return false
	hp = maxf(0,hp-amount)
	hit_flash = .12
	if hp<=0:
		alive = false
		collision_layer = 0
		collision_mask = 0
	return not alive
