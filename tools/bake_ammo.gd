extends SceneTree
## Bake licensed low-poly geometry into transparent 2D sprites. No 3D runtime cost.
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var viewport = SubViewport.new()
	viewport.size = Vector2i(384,384)
	viewport.transparent_bg = true
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.msaa_3d = Viewport.MSAA_4X
	root.add_child(viewport)
	var world = Node3D.new()
	viewport.add_child(world)
	var env = WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0,0,0,0)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color("#b1c3dc")
	env.environment.ambient_light_energy = .8
	world.add_child(env)
	for rot in [Vector3(-35,-30,0),Vector3(20,150,0)]:
		var light = DirectionalLight3D.new()
		light.rotation_degrees = rot
		light.light_energy = 2.4 if rot.y<0 else 1.1
		world.add_child(light)
	var camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.position = Vector3(0,.15,5)
	world.add_child(camera)
	camera.look_at(Vector3.ZERO)
	for name in ["bullet-foam-tip-thick","grenade-a"]:
		var doc = GLTFDocument.new()
		var state = GLTFState.new()
		assert(doc.append_from_file("res://art/v12/models/"+name+".glb",state)==OK)
		var model = doc.generate_scene(state)
		world.add_child(model)
		var mesh = model.find_children("*","MeshInstance3D",true,false)[0] as MeshInstance3D
		var bounds = mesh.get_aabb()
		var height = bounds.size.y
		# Copper/gold for alchemical ammunition; retain model normals and silhouette.
		var material = StandardMaterial3D.new()
		material.albedo_color = Color("#b28a4f") if name.begins_with("bullet") else Color("#4f6460")
		material.metallic = .65
		material.roughness = .29
		mesh.material_override = material
		if name.begins_with("bullet"):
			# Adapt the CC0 foam-round base into fantasy ammunition: copper ogive
			# and a brass rim. These are authored mesh details, not runtime particles.
			var nose = MeshInstance3D.new()
			var sphere = SphereMesh.new()
			sphere.radius = .0118
			sphere.height = .037
			nose.mesh = sphere
			nose.position.y = .045
			var copper = material.duplicate() as StandardMaterial3D
			copper.albedo_color = Color("#a4592f")
			copper.roughness = .22
			nose.material_override = copper
			model.add_child(nose)
			for y in [.003,.008]:
				var rim = MeshInstance3D.new()
				var cylinder = CylinderMesh.new()
				cylinder.top_radius = .0157
				cylinder.bottom_radius = .0157
				cylinder.height = .002
				rim.mesh = cylinder
				rim.position.y = y
				rim.material_override = material
				model.add_child(rim)
			height = .064
			bounds.size.y = height
		model.position = -bounds.get_center()
		camera.size = maxf(height,bounds.size.x)*1.25
		# Front view: bullet tip points upward. Runtime rotates the sprite toward aim.
		for frame in range(8): await process_frame
		await RenderingServer.frame_post_draw
		var path = "res://art/v12/"+("bullet" if name.begins_with("bullet") else "grenade")+".png"
		assert(viewport.get_texture().get_image().save_png(path)==OK)
		print("BAKED "+path+" bounds="+str(bounds))
		model.queue_free()
		await process_frame
	viewport.queue_free()
	quit()
