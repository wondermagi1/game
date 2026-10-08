extends Node2D
## A volume-painted sprite, anchored at its feet and sorted with the actors.
var room
var sprite: Sprite2D
var extent := Vector2.ZERO
var foliage := false

func setup(texture: Texture2D, dimensions: Vector2, leafy: bool) -> void:
	extent = dimensions
	foliage = leafy
	var shadow = Sprite2D.new()
	var gradient = Gradient.new()
	gradient.offsets = PackedFloat32Array([0,.55,1])
	gradient.colors = PackedColorArray([Color(.035,.055,.04,.32),Color(.035,.055,.04,.14),Color(.035,.055,.04,0)])
	var shadow_texture = GradientTexture2D.new()
	shadow_texture.gradient = gradient
	shadow_texture.width = 128
	shadow_texture.height = 64
	shadow_texture.fill = GradientTexture2D.FILL_RADIAL
	shadow_texture.fill_from = Vector2(.5,.5)
	shadow_texture.fill_to = Vector2(1,.5)
	shadow.texture = shadow_texture
	shadow.scale = Vector2(dimensions.x*.80/128,dimensions.x*.25/64)
	shadow.position = Vector2(14,5)
	shadow.z_as_relative = false
	shadow.z_index = 1
	add_child(shadow)
	sprite = Sprite2D.new()
	sprite.texture = texture
	sprite.centered = false
	sprite.position = Vector2(-dimensions.x*.5,-dimensions.y)
	sprite.scale = dimensions/texture.get_size()
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if leafy:
		var wind = ShaderMaterial.new()
		wind.shader = preload("res://art/v12/garden/foliage.gdshader")
		wind.set_shader_parameter("phase",position.x*.008)
		sprite.material = wind
	add_child(sprite)

func _process(delta: float) -> void:
	if sprite==null or room.run==null: return
	var game = room.run.game
	if not is_instance_valid(game.player): return
	var p: Vector2 = to_local(game.player.global_position)
	# Fade the roof/canopy only when it actually covers the player. The trunk's
	# collision remains, and enemies share the same depth sorting.
	var covered := Rect2(-extent.x*.44,-extent.y,extent.x*.88,extent.y-16).has_point(p)
	sprite.modulate.a = move_toward(sprite.modulate.a,.38 if covered else 1.0,delta*3.5)
	if foliage:
		sprite.material.set_shader_parameter("wind_strength",0.0 if game.reduced_motion else game.effects_intensity)
