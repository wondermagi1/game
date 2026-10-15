extends RefCounted
## Shared painted atlas. Regions are alpha-trimmed once, not stretched placeholder shapes.
const PROP_PATH = "res://art/western/props.png"
const MONSTER_PATH = "res://art/western/monsters.png"
const HERO_PATHS = ["res://art/western/sword.png","res://art/western/gunner.png","res://art/western/ranger.png"]
const MONSTER_CELLS = [0,1,2,3,4,5,6,7,8,9,10,11,12,13,0,14,15,1,11]
static var textures: Dictionary = {}
static var regions: Dictionary = {}
static var images: Dictionary = {}
static var hero_metadata: Dictionary = {}
static var hero_meshes: Dictionary = {}

static func hero_frame(path: String, cell: int) -> Dictionary:
	if hero_metadata.is_empty():
		hero_metadata = JSON.parse_string(FileAccess.get_file_as_string("res://art/western/hero_regions.json"))
	return hero_metadata[path.get_file()].frames[cell]

static func hero_mesh(path: String, cell: int) -> ArrayMesh:
	var key = path+":"+str(cell)
	if hero_meshes.has(key): return hero_meshes[key]
	var frame = hero_frame(path,cell)
	var origin = Vector2(frame.anchor[0],frame.anchor[1])
	var factor = 126.0/float(hero_metadata[path.get_file()].height)
	var tex_size = texture(path).get_size()
	var vertices = PackedVector2Array()
	var uvs = PackedVector2Array()
	var indices = PackedInt32Array()
	# Static UV strips isolate each authored figure, including weapon tips that
	# extend beyond nominal grid cells. No deformation or bitmap resampling.
	for band in frame.bands:
		var n = vertices.size()
		for point in [Vector2(band[0],band[1]),Vector2(band[2],band[1]),Vector2(band[2],band[3]),Vector2(band[0],band[3])]:
			vertices.append((point-origin)*factor)
			uvs.append(point/tex_size)
		indices.append_array(PackedInt32Array([n,n+1,n+2,n,n+2,n+3]))
	var arrays = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	hero_meshes[key] = mesh
	return mesh

static func texture(path: String) -> Texture2D:
	if not textures.has(path): textures[path] = load(path)
	return textures[path]

static func region(path: String, cell: int, columns: int, rows: int) -> Rect2:
	var key = path+":"+str(cell)
	if not regions.has(key):
		var tex = texture(path)
		var dims = Vector2i(tex.get_size())/Vector2i(columns,rows)
		var origin = Vector2i(cell%columns,floori(float(cell)/columns))*dims
		if not images.has(path): images[path] = tex.get_image()
		var img: Image = images[path]
		var low = dims
		var high = Vector2i.ZERO
		# Ignore almost transparent matte pixels when determining foot registration.
		for y in range(dims.y):
			for x in range(dims.x):
				if img.get_pixelv(origin+Vector2i(x,y)).a<.18: continue
				low = low.min(Vector2i(x,y))
				high = high.max(Vector2i(x+1,y+1))
		var used = Rect2i(low,high-low) if high.x>low.x else Rect2i(Vector2i.ZERO,dims)
		regions[key] = Rect2(Vector2(origin+used.position),Vector2(used.size))
	return regions[key]

static func prop(canvas: CanvasItem, cell: int, destination: Rect2, tint: Color = Color.WHITE, fit: bool = true) -> void:
	var source = region(PROP_PATH,cell,4,3)
	if fit:
		var ratio = minf(destination.size.x/source.size.x,destination.size.y/source.size.y)
		var size = source.size*ratio
		destination = Rect2(destination.get_center()-size*.5,size)
	canvas.draw_texture_rect_region(texture(PROP_PATH),destination,source,tint)

static func obstacle(canvas: CanvasItem, rect: Rect2) -> void:
	# Match the authored collision footprint; long walls use repeated stone sections.
	var vertical = rect.size.y>rect.size.x*1.5
	var horizontal = rect.size.x>rect.size.y*1.3
	var count = maxi(1,ceili((rect.size.y if vertical else rect.size.x)/190.0))
	if not vertical and not horizontal: count = 1
	for i in range(count):
		var tile = rect
		if vertical:
			tile.size.y /= count
			tile.position.y += tile.size.y*i
		elif horizontal:
			tile.size.x /= count
			tile.position.x += tile.size.x*i
		canvas.draw_texture_rect_region(texture(PROP_PATH),Rect2(tile.position+Vector2(5,7),tile.size),region(PROP_PATH,11 if vertical else 10,4,3),Color(0,0,0,.28))
		prop(canvas,11 if vertical else (10 if horizontal else 8),tile,Color("#d5d9dd"),false)

static func event_cell(event: String, used: bool) -> int:
	match event:
		"chest": return 1 if used else 0
		"altar","secret": return 2
		"fountain": return 3
		"forge": return 4
		"merchant","traveler": return 5
	return 2
