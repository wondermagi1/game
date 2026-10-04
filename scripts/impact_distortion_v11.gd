extends Sprite2D
## One short-lived local back-buffer ripple. ScreenFX caps these to one instance.
var life: float = 0.24
var maximum: float = 0.24
var initial_strength: float = 5.0

func setup(radius: float, strength: float) -> void:
	texture = preload("res://art/v11/distortion_mask.svg")
	centered = true
	scale = Vector2.ONE*(radius*2.0/512.0)
	initial_strength = strength
	var shader_material := ShaderMaterial.new()
	shader_material.shader = preload("res://art/v11/impact_distortion.gdshader")
	material = shader_material
	z_index = 27
	life = maximum
	visible = true
	set_process(true)

func reset() -> void:
	life = 0
	visible = false
	set_process(false)

func _process(delta: float) -> void:
	life -= delta
	var phase := clampf(1.0-life/maximum,0.0,1.0)
	var shader_material := material as ShaderMaterial
	shader_material.set_shader_parameter("progress",phase)
	shader_material.set_shader_parameter("strength",initial_strength)
	modulate.a = 1.0-phase
	if life<=0: reset()
