extends Node2D
var room
var water: ColorRect
var time: float=0
var shader_material: ShaderMaterial
func _ready() -> void:
	z_index=1
	water=ColorRect.new();water.position=Vector2(538,366);water.size=Vector2(844,368);water.mouse_filter=Control.MOUSE_FILTER_IGNORE
	shader_material=ShaderMaterial.new();shader_material.shader=preload("res://art/v6/spring_water.gdshader");water.material=shader_material;add_child(water)
func _process(delta: float) -> void:
	if room.run==null:return
	var game=room.run.game
	if game.state in ["combat","end"]:time+=delta
	shader_material.set_shader_parameter("clock",time)
	shader_material.set_shader_parameter("strength",0.0 if game.reduced_motion else game.effects_intensity)
	queue_redraw()
func _draw() -> void:
	for i in range(6):
		var y=fposmod(time*15+i*13,90)
		var p=Vector2(625+i*135+sin(time*.5+i)*15,505-y)
		var size=Vector2(75,65)*(1+y/130)
		draw_texture_rect(preload("res://art/v6/fx/smoke_01.png"),Rect2(p-size*.5,size),false,Color(.78,.92,.91,.08*(1-y/90)))
