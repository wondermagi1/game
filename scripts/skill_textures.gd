extends RefCounted
## Licensed texture primitives. Unit quads and images are cached; no combat state.
const ROOT = "res://art/v12/"
const SEQUENCES = {"sword_slash":6,"sword_wave":6,"alchemy_slash":6,"nature_bloom":5,"nature_leaves":7,"nature_wreath":5,"arcane":7}
static var textures: Dictionary = {}
static var quads: Dictionary = {}
static var bounds: Dictionary = {}
static func texture(path: String) -> Texture2D:
	if not textures.has(path): textures[path] = load(path)
	return textures[path]
static func quad(path: String, source: Rect2) -> ArrayMesh:
	var key = path+str(source)
	if quads.has(key): return quads[key]
	var tex_size = texture(path).get_size()
	var arrays = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = PackedVector2Array([Vector2(-.5,-.5),Vector2(.5,-.5),Vector2(.5,.5),Vector2(-.5,.5)])
	arrays[Mesh.ARRAY_TEX_UV] = PackedVector2Array([source.position/tex_size,(source.position+Vector2(source.size.x,0))/tex_size,source.end/tex_size,(source.position+Vector2(0,source.size.y))/tex_size])
	arrays[Mesh.ARRAY_INDEX] = PackedInt32Array([0,1,2,0,2,3])
	var mesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	quads[key] = mesh
	return mesh
static func image_at(canvas: CanvasItem, path: String, pos: Vector2, size: Vector2, angle: float = 0.0, color: Color = Color.WHITE, source: Rect2 = Rect2()) -> void:
	if source.size==Vector2.ZERO: source = Rect2(Vector2.ZERO,texture(path).get_size())
	canvas.draw_mesh(quad(path,source),texture(path),Transform2D(angle,size,0,pos),color)
static func sequence(canvas: CanvasItem, name: String, pos: Vector2, size: Vector2, phase: float, angle: float = 0.0, color: Color = Color.WHITE) -> void:
	var frame = mini(SEQUENCES[name]-1,int(clampf(phase,0,.999)*SEQUENCES[name]))
	image_at(canvas,ROOT+name+"/%d.png"%frame,pos,size,angle,color)
static func used(path: String) -> Rect2:
	if not bounds.has(path): bounds[path] = Rect2(texture(path).get_image().get_used_rect())
	return bounds[path]
static func bullet(canvas: CanvasItem, length: float, color: Color = Color.WHITE) -> void:
	var path = ROOT+"bullet.png"
	var r = used(path)
	# Brass jacket, copper rounded nose, machined base rings. Image points upward.
	image_at(canvas,path,Vector2.ZERO,Vector2(length*r.size.x/r.size.y*.72,length),PI*.5,color,r)
static func grenade(canvas: CanvasItem, size: float, angle: float = 0.0) -> void:
	var path = ROOT+"grenade.png"
	var r = used(path)
	image_at(canvas,path,Vector2.ZERO,Vector2(size*r.size.x/r.size.y,size),angle,Color.WHITE,r)
static func muzzle(canvas: CanvasItem, length: float, phase: float) -> void:
	image_at(canvas,ROOT+"muzzle-flame.png",Vector2(length*.38,0),Vector2(length*.64,length),PI*.5,Color(1,1,1,(1-phase)*.88))
static func explosion(canvas: CanvasItem, pos: Vector2, size: float, phase: float, alpha: float = 1.0) -> void:
	# 34 authored frames, 8 columns, 300 px cells. Remaining cells are empty.
	var frame = mini(33,int(clampf(phase,0,.999)*34))
	var source = Rect2(Vector2(frame%8,floori(frame/8.0))*300,Vector2.ONE*300)
	image_at(canvas,ROOT+"explosion.png",pos,Vector2.ONE*size*1.8,0,Color(1,1,1,alpha),source)
static func glow(canvas: CanvasItem, pos: Vector2, size: Vector2, angle: float, color: Color) -> void:
	image_at(canvas,"res://art/v6/fx/light_01.png",pos,size,angle,color)
static func rune(canvas: CanvasItem, pos: Vector2, size: Vector2, angle: float, alpha: float) -> void:
	image_at(canvas,ROOT+"rune-swirl.png",pos,size,angle,Color(1,1,1,alpha))
