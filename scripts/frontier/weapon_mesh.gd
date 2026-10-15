extends RefCounted
## Reusable real 3D silhouettes. +Z is the direction of travel for every weapon.
## Visual meshes never decide damage, collision radius, spread or projectile speed.
static var blade_mesh: ArrayMesh
static var arrowhead_mesh: ArrayMesh

static func diamond_blade(length_value: float,width: float,depth: float) -> ArrayMesh:
	var points = [Vector3(0,0,length_value),Vector3(-width,0,0),Vector3(0,depth,0),Vector3(width,0,0),Vector3(0,-depth,0),Vector3(0,0,-.12)]
	var surface = SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for face in [[0,2,1],[0,3,2],[0,4,3],[0,1,4],[5,1,2],[5,2,3],[5,3,4],[5,4,1]]:
		for index in face: surface.add_vertex(points[index])
	surface.generate_normals()
	return surface.commit()

static func add_mesh(parent: Node3D,mesh: Mesh,pos: Vector3,mat: Material) -> MeshInstance3D:
	var piece = MeshInstance3D.new()
	piece.mesh = mesh
	piece.material_override = mat
	piece.position = pos
	parent.add_child(piece)
	return piece

static func sphere(radius: float) -> SphereMesh:
	var result = SphereMesh.new()
	result.radius = radius
	result.height = radius*2
	result.radial_segments = 12
	result.rings = 6
	return result

static func create(terrain,style: int,color: Color,hostile: bool = false) -> Node3D:
	var root_node = Node3D.new()
	root_node.name = "ArcaneProjectile" if hostile else ["RunicSword","RunicRound","FeatheredArrow"][style]
	var gold: Material = terrain.material(Color("#d5ba79"),.65,.05)
	var silver: Material = terrain.material(Color("#d8e8e9"),.65,.06)
	var glow: Material = terrain.material(color,.15,.8)
	if hostile:
		if arrowhead_mesh==null: arrowhead_mesh = diamond_blade(.3,.13,.10)
		add_mesh(root_node,arrowhead_mesh,Vector3.ZERO,glow)
	elif style==0:
		if blade_mesh==null: blade_mesh = diamond_blade(1.25,.16,.055)
		add_mesh(root_node,blade_mesh,Vector3(0,0,-.3),silver)
		var core = add_mesh(root_node,blade_mesh,Vector3(0,.026,-.27),glow)
		core.scale = Vector3(.3,.75,.85)
		terrain.box(Vector3(0,0,-.38),Vector3(.62,.12,.12),Color("#d5ba79"),root_node).material_override = gold
		var grip = terrain.cylinder(Vector3(0,0,-.6),.055,.055,.34,Color("#405e70"),root_node)
		grip.rotation.x = PI/2
		add_mesh(root_node,sphere(.085),Vector3(0,0,-.82),gold)
	elif style==1:
		add_mesh(root_node,sphere(.13),Vector3.ZERO,terrain.material(Color("#514b43"),.7,.04))
		var band = TorusMesh.new()
		band.inner_radius = .105
		band.outer_radius = .142
		band.rings = 12
		band.ring_segments = 6
		add_mesh(root_node,band,Vector3.ZERO,gold).rotation.x = PI/2
		add_mesh(root_node,sphere(.065),Vector3(0,0,.115),glow)
	else:
		var shaft = terrain.cylinder(Vector3(0,0,-.03),.028,.028,1.25,Color("#8c7855"),root_node)
		shaft.rotation.x = PI/2
		if arrowhead_mesh==null: arrowhead_mesh = diamond_blade(.3,.13,.10)
		add_mesh(root_node,arrowhead_mesh,Vector3(0,0,.57),silver)
		add_mesh(root_node,sphere(.048),Vector3(0,0,.5),glow)
		for i in range(3):
			var feather_root = Node3D.new()
			feather_root.rotation.z = i*TAU/3
			root_node.add_child(feather_root)
			var feather = PrismMesh.new()
			feather.size = Vector3(.22,.025,.33)
			add_mesh(feather_root,feather,Vector3(.09,0,-.5),terrain.material(Color("#c5ddc8")))
	return root_node
