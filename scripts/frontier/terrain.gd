extends Node3D
## A continuous 130 x 130 metre region. Every rock, tree and building is 3D.
const LIMIT = 64.0
const PATHS = [
	[Vector2(-48,42),Vector2(-38,30),Vector2(-28,18),Vector2(-9,10),Vector2(12,-6),Vector2(7,-27),Vector2(5,-48)],
	[Vector2(-28,18),Vector2(-40,4),Vector2(-42,-12),Vector2(-51,-29),Vector2(-50,-45)],
	[Vector2(12,-6),Vector2(30,2),Vector2(34,24)],
	[Vector2(12,-6),Vector2(33,-18),Vector2(35,-35),Vector2(5,-48)]
]
const SITES = [Vector2(-48,42),Vector2(-28,18),Vector2(12,-6),Vector2(-42,-12),Vector2(34,24),Vector2(35,-35),Vector2(5,-48),Vector2(-50,-45)]
var rng = RandomNumberGenerator.new()
var materials: Dictionary = {}
var obstacles: Array[Vector3] = []
var markers: Dictionary = {}
var hearth_lights: Array[OmniLight3D] = []
var scenery_clock: float = 0.0
const BRIDGE_CENTER = Vector2(30.2,1.7)

static func base_height(x: float,z: float) -> float:
	var ridge = pow(maxf(0,maxf(absf(x),absf(z))-52.0),2)*.009
	return sin(x*.065)*.7+cos(z*.078)*.6+sin((x+z)*.044)*.6+ridge

static func stream_x(z: float) -> float:
	return 30.0+sin(z*.035)*3.0

static func height_at(x: float,z: float) -> float:
	var height = base_height(x,z)
	var stream = (1.0-smoothstep(1.6,3.3,absf(x-stream_x(z))))
	stream *= smoothstep(-14,-6,z)*(1.0-smoothstep(32,40,z))
	height -= stream*.38
	# Continuous approaches make the bridge walkable without a jump mechanic.
	var bridge = (1.0-smoothstep(3.6,6.2,absf(x-BRIDGE_CENTER.x)))*(1.0-smoothstep(1.7,2.8,absf(z-BRIDGE_CENTER.y)))
	return lerpf(height,base_height(BRIDGE_CENTER.x,BRIDGE_CENTER.y)+.18,bridge)

static func ground(p: Vector2) -> Vector3:
	return Vector3(p.x,height_at(p.x,p.y),p.y)

func material(color: Color, metal: float = 0.0, glow: float = 0.0) -> StandardMaterial3D:
	var key = str(color)+str(metal)+str(glow)
	if materials.has(key): return materials[key]
	var result = StandardMaterial3D.new()
	result.albedo_color = color
	result.roughness = .87 if metal==0 else .4
	result.metallic = metal
	if glow>0:
		result.emission_enabled = true
		result.emission = color
		result.emission_energy_multiplier = glow
	materials[key] = result
	return result

func mesh_node(mesh: Mesh, pos: Vector3, color: Color, parent: Node = self) -> MeshInstance3D:
	var node = MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = material(color)
	node.position = pos
	parent.add_child(node)
	return node

func box(pos: Vector3, size_value: Vector3, color: Color, parent: Node = self) -> MeshInstance3D:
	var mesh = BoxMesh.new()
	mesh.size = size_value
	return mesh_node(mesh,pos,color,parent)

func cylinder(pos: Vector3, bottom: float, top: float, height: float, color: Color, parent: Node = self) -> MeshInstance3D:
	var mesh = CylinderMesh.new()
	mesh.bottom_radius = bottom
	mesh.top_radius = top
	mesh.height = height
	mesh.radial_segments = 7
	return mesh_node(mesh,pos,color,parent)

func segment(a: Vector3,b: Vector3,radius: float,color: Color,parent: Node = self) -> void:
	var node = cylinder((a+b)*.5,radius,radius*.65,a.distance_to(b),color,parent)
	node.quaternion = Quaternion(Vector3.UP,(b-a).normalized())

func collider(pos: Vector3, radius: float,height: float,parent: Node = self) -> void:
	var body = StaticBody3D.new()
	body.position = pos
	var shape = CollisionShape3D.new()
	var cylinder_shape = CylinderShape3D.new()
	cylinder_shape.radius = radius
	cylinder_shape.height = height
	shape.shape = cylinder_shape
	body.add_child(shape)
	parent.add_child(body)
	obstacles.append(Vector3(pos.x,pos.z,radius))

func _ready() -> void:
	rng.seed = 73126
	build_ground()
	build_stream()
	build_distant_ridges()
	for i in range(90):
		var p = Vector2(rng.randf_range(-61,61),rng.randf_range(-61,61))
		if path_distance(p)<3.7 or near_site(p,9): continue
		tree(p,rng.randf_range(.8,1.6),i%4==0)
	for i in range(45):
		var p = Vector2(rng.randf_range(-60,60),rng.randf_range(-60,60))
		if path_distance(p)<3.5 or near_site(p,9): continue
		rock(p,rng.randf_range(.7,2.0))
	for i in range(18):
		var angle = i*TAU/18
		rock(Vector2(cos(angle),sin(angle))*70,rng.randf_range(2.5,4.8))
	build_grass()
	build_ruins()
	build_camp()
	build_hearth("hearth_bridge",Vector2(24,9))
	build_landmarks()
	for pair in [["rune_west",Vector2(-42,-12)],["rune_east",Vector2(34,24)],["rune_north",Vector2(35,-35)]]:
		shrine(pair[0],pair[1])
	chest("hidden_chest",Vector2(-50,-45))
	chest("trail_chest",Vector2(45,5))
	for p in [Vector2(-34,25),Vector2(-16,12),Vector2(14,-17),Vector2(8,-35)]: lantern(p)

func near_site(p: Vector2, distance_value: float) -> bool:
	for site in SITES:
		if p.distance_to(site)<distance_value: return true
	return false

func path_distance(p: Vector2) -> float:
	var result = 999.0
	for path in PATHS:
		for i in range(path.size()-1):
			result = minf(result,p.distance_to(Geometry2D.get_closest_point_to_segment(p,path[i],path[i+1])))
	return result

func build_ground() -> void:
	var surface = SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for x in range(-80,80,2):
		for z in range(-80,80,2):
			# Godot uses clockwise front faces. Upward faces also make collision
			# normals support the character instead of letting it fall through.
			for p in [Vector2(x,z),Vector2(x+2,z),Vector2(x,z+2),Vector2(x+2,z),Vector2(x+2,z+2),Vector2(x,z+2)]:
				var h = height_at(p.x,p.y)
				var col = Color("#7894ad").lerp(Color("#b2c5d1"),clampf((h+1.5)/4,0,1))
				col = col.lerp(Color("#a9b5bb"),clampf((3.1-path_distance(p))/2.0,0,.55))
				surface.set_color(col)
				surface.add_vertex(ground(p))
	surface.generate_normals()
	var mesh = surface.commit()
	var ground_node = mesh_node(mesh,Vector3.ZERO,Color.WHITE)
	var ground_mat = ShaderMaterial.new()
	ground_mat.shader = preload("res://shaders/frontier_snow.gdshader")
	ground_node.material_override = ground_mat
	ground_node.create_trimesh_collision()
	ground_node.name = "SnowTerrain"

func build_stream() -> void:
	var surf = SurfaceTool.new()
	surf.begin(Mesh.PRIMITIVE_TRIANGLES)
	for z in range(-10,36):
		for uv in [Vector2(-1,z),Vector2(1,z),Vector2(-1,z+1),Vector2(1,z),Vector2(1,z+1),Vector2(-1,z+1)]:
			var width = 1.9*smoothstep(-12,-5,uv.y)*(1-smoothstep(31,38,uv.y))
			var p = Vector2(stream_x(uv.y)+uv.x*width,uv.y)
			surf.add_vertex(Vector3(p.x,base_height(p.x,p.y)-.26,p.y))
	surf.generate_normals()
	var stream = mesh_node(surf.commit(),Vector3.ZERO,Color.WHITE)
	stream.name = "Frostbrook"
	var mat = ShaderMaterial.new()
	mat.shader = preload("res://shaders/frontier_ice.gdshader")
	stream.material_override = mat
	for i in range(12):
		var z = -7+i*3.5
		if absf(z-BRIDGE_CENTER.y)<3: continue
		rock(Vector2(stream_x(z)+(2.4 if i%2 else -2.4),z),rng.randf_range(.35,.75))

func build_distant_ridges() -> void:
	var group = Node3D.new()
	group.name = "DistantRidges"
	add_child(group)
	for i in range(32):
		var angle = i*TAU/32
		var distance_value = rng.randf_range(88,110)
		var h = rng.randf_range(9,18)
		var pos = Vector3(cos(angle)*distance_value,h*.28-2,sin(angle)*distance_value)
		var ridge = cylinder(pos,rng.randf_range(9,15),.4,h,Color("#6d889f"),group)
		ridge.rotation.y = angle
		ridge.scale.z = 1.35
		var snow_cap = cylinder(pos+Vector3.UP*h*.28,5.2,.25,h*.45,Color("#b6c9d6"),group)
		snow_cap.scale.z = 1.35

func rock(p: Vector2,size_value: float) -> void:
	var origin = ground(p)
	var mesh = SphereMesh.new()
	mesh.radius = size_value
	mesh.height = size_value*1.4
	mesh.radial_segments = 6
	mesh.rings = 3
	var node = mesh_node(mesh,origin+Vector3.UP*size_value*.34,Color("#4f627b"))
	node.rotation.y = rng.randf()*TAU
	var cap = mesh_node(mesh,origin+Vector3.UP*size_value*.58,Color("#9db4c8"))
	cap.scale = Vector3(.91,.4,.91)
	cap.rotation.y = node.rotation.y
	collider(origin+Vector3.UP*size_value*.5,size_value*.8,size_value*1.4)

func tree(p: Vector2,s: float,evergreen: bool = false) -> void:
	var tree_root = Node3D.new()
	tree_root.position = ground(p)
	add_child(tree_root)
	cylinder(Vector3.UP*2.2*s,.24*s,.12*s,4.4*s,Color("#314655"),tree_root)
	if evergreen:
		for i in range(3):
			cylinder(Vector3.UP*(2.4+i*.9)*s,(1.55-i*.3)*s,0,2.4*s,Color("#335d62"),tree_root)
			cylinder(Vector3.UP*(2.62+i*.9)*s,(1.3-i*.27)*s,0,2*s,Color("#c4d8de"),tree_root)
	else:
		for i in range(6):
			var angle = i*2.4+rng.randf()*.4
			var a = Vector3(0,(1.7+i*.32)*s,0)
			var b = a+Vector3(cos(angle)*1.55,1.25,sin(angle)*1.55)*s
			segment(a,b,.085*s,Color("#334958"),tree_root)
			segment(b,b+Vector3(-sin(angle)*.65,.85,cos(angle)*.65)*s,.045*s,Color("#334958"),tree_root)
	collider(tree_root.position+Vector3.UP*2*s,.32*s,4*s)

func build_grass() -> void:
	var multi = MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.use_colors = true
	var blade = PrismMesh.new()
	blade.size = Vector3(.1,.6,.06)
	multi.mesh = blade
	multi.instance_count = 1700
	var patches = [Vector2(-37,38),Vector2(-18,23),Vector2(20,12),Vector2(42,-23),Vector2(-44,-35),Vector2(21,-43)]
	for i in range(multi.instance_count):
		var center: Vector2 = patches[i%patches.size()]
		var angle = rng.randf()*TAU
		var spread = sqrt(rng.randf())
		var p = center+Vector2(cos(angle)*4.6,sin(angle)*2.7)*spread
		var basis_value = Basis(Vector3.UP,rng.randf()*TAU).scaled(Vector3.ONE*rng.randf_range(.65,1.6))
		multi.set_instance_transform(i,Transform3D(basis_value,ground(p)+Vector3.UP*.2))
		multi.set_instance_color(i,Color("#647e65").lerp(Color("#a7b889"),rng.randf()))
	var instance = MultiMeshInstance3D.new()
	instance.multimesh = multi
	var mat = ShaderMaterial.new()
	mat.shader = preload("res://shaders/frontier_grass.gdshader")
	instance.material_override = mat
	add_child(instance)

func build_ruins() -> void:
	for p in [Vector2(-2,-48),Vector2(12,-48),Vector2(-2,-57),Vector2(12,-57)]:
		var origin = ground(p)
		cylinder(origin+Vector3.UP*2.8,1.2,1.0,5.6,Color("#72828e"))
		cylinder(origin+Vector3.UP*5.65,1.35,1.35,.25,Color("#c5d6dd"))
		for h in [1.0,2.4,3.8]: cylinder(origin+Vector3.UP*h,1.25,1.25,.18,Color("#8c9da7"))
		collider(origin+Vector3.UP*2.8,1.3,5.6)
	stone_arch(Vector2(5,-57),7.0,4.1)
	for x in [-2.0,12.0]:
		banner(ground(Vector2(x,-47))+Vector3(0,4.8,.8),1.3,3.2)
	for i in range(11):
		var p = Vector2(-1+i*1.2,-40)
		box(ground(p)+Vector3.UP*.1,Vector3(1.1,.2,2.1),Color("#a2b4be"))
	build_bridge()

func build_bridge() -> void:
	var deck_y = height_at(BRIDGE_CENTER.x,BRIDGE_CENTER.y)+.035
	var bridge = Node3D.new()
	bridge.name = "OldBridge"
	add_child(bridge)
	for i in range(15):
		box(Vector3(26.6+i*.51,deck_y-.09,1.7),Vector3(.48,.18,3.3),Color("#7c7468").lerp(Color("#adaba0"),rng.randf()*.35),bridge)
	for z in [.05,3.35]:
		for x in [26.7,28.5,30.2,32.0,33.7]:
			box(Vector3(x,deck_y+.65,z),Vector3(.16,1.3,.16),Color("#536571"),bridge)
			box(Vector3(x,deck_y+1.35,z),Vector3(.26,.12,.26),Color("#c7d6dc"),bridge)
		segment(Vector3(26.7,deck_y+1.1,z),Vector3(33.7,deck_y+1.1,z),.065,Color("#6e7b82"),bridge)
		var rail = StaticBody3D.new()
		var rail_shape = CollisionShape3D.new()
		var rail_box = BoxShape3D.new()
		rail_box.size = Vector3(7.1,.9,.14)
		rail_shape.shape = rail_box
		rail.position = Vector3(30.2,deck_y+.5,z)
		rail.add_child(rail_shape)
		bridge.add_child(rail)
	var deck = StaticBody3D.new()
	deck.name = "BridgeDeck"
	var shape = CollisionShape3D.new()
	var deck_shape = BoxShape3D.new()
	deck_shape.size = Vector3(7.7,.18,3.3)
	shape.shape = deck_shape
	deck.position = Vector3(30.2,deck_y-.09,1.7)
	deck.add_child(shape)
	bridge.add_child(deck)
	lantern(Vector2(26.0,4.5))
	lantern(Vector2(34.5,-1.0))

func build_camp() -> void:
	var p = ground(Vector2(-52,44))
	var tent = PrismMesh.new()
	tent.size = Vector3(5,3,4)
	mesh_node(tent,p+Vector3.UP*1.5,Color("#435b6c"))
	box(p+Vector3(0,2.98,0),Vector3(.16,.15,4.3),Color("#d2dde1"))
	# Canvas seams, bedrolls, a hanging banner and warm hearth tell the camp's story.
	for z in [-1.65,1.65]: segment(p+Vector3(-2.55,0,z),p+Vector3(0,3.0,z),.035,Color("#b7bfc0"))
	box(p+Vector3(2.8,.25,1.0),Vector3(.9,.5,1.4),Color("#987451"))
	cylinder(p+Vector3(2.9,.6,-.6),.45,.45,1.2,Color("#70614f"))
	build_hearth("hearth_home",Vector2(-44,45))
	lantern(Vector2(-47,43))
	for x in [-31.0,-25.0]:
		var pos = ground(Vector2(x,16))
		box(pos+Vector3.UP*.7,Vector3(1.5,1.4,1.5),Color("#776b5e"))
		box(pos+Vector3.UP*1.45,Vector3(1.6,.15,1.6),Color("#c4d4dc"))

func build_hearth(id: String,point: Vector2) -> void:
	var hearth_root = Node3D.new()
	hearth_root.name = id
	add_child(hearth_root)
	var hearth = ground(point)
	for i in range(7):
		var v = Vector2.from_angle(i*TAU/7)*.8
		cylinder(hearth+Vector3(v.x,.1,v.y),.23,.23,.2,Color("#60707a"),hearth_root)
	for angle in [-.5,.6]:
		var log_mesh = box(hearth+Vector3.UP*.12,Vector3(1.15,.2,.27),Color("#67513d"),hearth_root)
		log_mesh.rotation.y = angle
	for i in range(3):
		var flame = cylinder(hearth+Vector3((i-1)*.17,.4,0),.22,0,.7+i*.14,Color("#e3a76c"),hearth_root)
		flame.material_override = material(Color("#ffd59b"),0,1.4)
	var hearth_light = OmniLight3D.new()
	hearth_light.position = hearth+Vector3.UP*1.2
	hearth_light.light_color = Color("#ffd49a")
	hearth_light.light_energy = 2.3
	hearth_light.omni_range = 7
	hearth_root.add_child(hearth_light)
	hearth_lights.append(hearth_light)
	box(hearth+Vector3(1.9,.38,.7),Vector3(.5,.76,2.0),Color("#7e6955"),hearth_root)
	markers[id] = hearth_root

func animate_scenery(delta: float, active: bool) -> void:
	if not active: return
	scenery_clock += delta
	for i in range(hearth_lights.size()):
		hearth_lights[i].light_energy = 2.1+sin(scenery_clock*5+i)*.18+sin(scenery_clock*8.7)*.08

func lantern(p: Vector2) -> void:
	var origin = ground(p)
	cylinder(origin+Vector3.UP*1.2,.07,.05,2.4,Color("#354552"))
	var lamp = box(origin+Vector3.UP*2.35,Vector3(.36,.5,.36),Color("#ffcf7e"))
	lamp.material_override = material(Color("#ffcf7e"),0,2)
	box(origin+Vector3.UP*2.68,Vector3(.52,.12,.52),Color("#b6cbd4"))
	for x in [-.2,.2]:
		for z in [-.2,.2]: box(origin+Vector3(x,2.35,z),Vector3(.045,.55,.045),Color("#64737b"))
	var light = OmniLight3D.new()
	light.position = origin+Vector3.UP*2.2
	light.light_color = Color("#ffd596")
	light.light_energy = 1.3
	light.omni_range = 5
	add_child(light)

func shrine(id: String,p: Vector2) -> void:
	var root_node = Node3D.new()
	root_node.position = ground(p)
	root_node.name = id
	add_child(root_node)
	cylinder(Vector3.UP*.18,1.45,1.45,.36,Color("#687f92"),root_node)
	cylinder(Vector3.UP*.8,.65,.48,1.25,Color("#8ba3b6"),root_node)
	var crystal = cylinder(Vector3.UP*1.8,.45,0,1.1,Color("#78d5de"),root_node)
	crystal.material_override = material(Color("#78d5de"),.2,.4)
	collider(root_node.position+Vector3.UP*.75,.72,1.5)
	for i in range(3):
		var v = Vector3(cos(i*TAU/3)*1.9,.6,sin(i*TAU/3)*1.9)
		cylinder(v,.4,.3,1.2,Color("#70899c"),root_node)
	markers[id] = root_node

func chest(id: String,p: Vector2) -> void:
	var root_node = Node3D.new()
	root_node.position = ground(p)
	root_node.name = id
	add_child(root_node)
	box(Vector3.UP*.48,Vector3(1.5,.8,1.0),Color("#715343"),root_node)
	var lid = Node3D.new()
	lid.name = "Lid"
	lid.position = Vector3(0,.85,-.48)
	root_node.add_child(lid)
	box(Vector3(0,.08,.48),Vector3(1.58,.25,1.1),Color("#a28857"),lid)
	for x in [-.58,.58]: box(Vector3(x,.5,0),Vector3(.14,.95,1.08),Color("#a89872"),root_node)
	collider(root_node.position+Vector3.UP*.5,.65,1.0)
	markers[id] = root_node

func activate(id: String) -> void:
	if not markers.has(id): return
	var node: Node3D = markers[id]
	if id.ends_with("chest"):
		node.get_node("Lid").rotation.x = -1.2
	else:
		var light = OmniLight3D.new()
		light.position.y = 2
		light.light_color = Color("#73e5cf")
		light.light_energy = 1.7
		light.omni_range = 6
		node.add_child(light)

func stone_arch(p: Vector2,radius: float,spring_height: float) -> void:
	# Individually shaped voussoirs: an actual open stone arch, not a flat backdrop.
	var origin = ground(p)
	for i in range(13):
		var a = float(i)*PI/13+.008
		var b = float(i+1)*PI/13-.008
		var points: Array[Vector3] = []
		for depth in [-.65,.65]:
			for pair in [[a,radius],[b,radius],[b,radius+.8],[a,radius+.8]]:
				points.append(Vector3(cos(pair[0])*pair[1],sin(pair[0])*pair[1]+spring_height,depth))
		var surf = SurfaceTool.new()
		surf.begin(Mesh.PRIMITIVE_TRIANGLES)
		for face in [[0,3,2,1],[4,5,6,7],[0,1,5,4],[3,7,6,2],[0,4,7,3],[1,2,6,5]]:
			for j in [0,1,2,0,2,3]: surf.add_vertex(points[face[j]])
		surf.generate_normals()
		var stone = mesh_node(surf.commit(),origin,Color("#b4bfc5").lerp(Color("#d3dcdf"),rng.randf()*.6))
		# Both faces are intentional on the weathered, open arch.
		var stone_mat = stone.material_override.duplicate()
		stone_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		stone.material_override = stone_mat

func banner(origin: Vector3,width: float,height: float) -> void:
	var surf = SurfaceTool.new()
	surf.begin(Mesh.PRIMITIVE_TRIANGLES)
	for y in range(10):
		for x in range(4):
			for uv in [Vector2(x,y),Vector2(x+1,y),Vector2(x,y+1),Vector2(x+1,y),Vector2(x+1,y+1),Vector2(x,y+1)]:
				uv /= Vector2(4,10)
				surf.set_uv(uv)
				surf.add_vertex(Vector3((uv.x-.5)*width,-uv.y*height,0))
	surf.generate_normals()
	var cloth = mesh_node(surf.commit(),origin,Color.WHITE)
	var mat = ShaderMaterial.new()
	mat.shader = preload("res://shaders/frontier_cloth.gdshader")
	cloth.material_override = mat
	segment(origin+Vector3(-width*.65,0,0),origin+Vector3(width*.65,0,0),.045,Color("#a08e64"))

func build_landmarks() -> void:
	# Warm, visible landmarks break up long snowy walks without filling paths.
	stone_arch(Vector2(-40,30),2.3,2.2)
	for x in [-42.7,-37.3]:
		var origin = ground(Vector2(x,30))
		cylinder(origin+Vector3.UP*1.3,.65,.53,2.6,Color("#acbac4"))
		collider(origin+Vector3.UP*1.3,.65,2.6)
		lantern(Vector2(x,31))
	banner(ground(Vector2(-42.7,30))+Vector3(0,2.6,.8),.65,1.45)
	# Shallow frozen pool, walkable at exactly the terrain's collision height.
	var center = Vector2(-23,-15)
	var surf = SurfaceTool.new()
	surf.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(64):
		for p in [center,center+Vector2(cos((i+1)*TAU/64)*7,sin((i+1)*TAU/64)*4.5),center+Vector2(cos(i*TAU/64)*7,sin(i*TAU/64)*4.5)]:
			surf.add_vertex(ground(p)+Vector3.UP*.035)
	surf.generate_normals()
	var ice = mesh_node(surf.commit(),Vector3.ZERO,Color("#79bfc6"))
	var ice_mat = material(Color("#79bfc6"),.12).duplicate()
	ice_mat.roughness = .25
	ice_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	ice.material_override = ice_mat
	for i in range(9):
		var angle = i*TAU/9
		rock(center+Vector2(cos(angle)*7.4,sin(angle)*5),rng.randf_range(.45,.85))
	# Winter meadow flowers: tiny warm notes, not bright combat markers.
	var flowers = MultiMesh.new()
	flowers.transform_format = MultiMesh.TRANSFORM_3D
	flowers.use_colors = true
	var petal = SphereMesh.new()
	petal.radius = .09
	petal.height = .1
	petal.radial_segments = 5
	petal.rings = 2
	flowers.mesh = petal
	flowers.instance_count = 180
	var patches = [Vector2(-37,38),Vector2(-18,23),Vector2(20,12),Vector2(42,-23),Vector2(-44,-35),Vector2(21,-43)]
	for i in range(180):
		var a = rng.randf()*TAU
		var p: Vector2 = patches[i%6]+Vector2(cos(a)*4,sin(a)*2.3)*sqrt(rng.randf())
		flowers.set_instance_transform(i,Transform3D(Basis(),ground(p)+Vector3.UP*rng.randf_range(.3,.65)))
		flowers.set_instance_color(i,Color("#f9e5ba") if i%3 else Color("#dceaf1"))
	var meadow = MultiMeshInstance3D.new()
	meadow.multimesh = flowers
	var mat = material(Color.WHITE).duplicate()
	mat.vertex_color_use_as_albedo = true
	meadow.material_override = mat
	add_child(meadow)
