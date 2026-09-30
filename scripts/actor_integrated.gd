@tool
extends "res://scripts/actor_v6.gd"
## Default route: body, hands and weapon share one painted animation frame.
## The joint rig remains available only in the inspection scene for comparison.
@export var articulated_preview: bool = false
static var whole_textures: Dictionary={}
static var whole_regions: Dictionary={}
static var frame_meshes: Dictionary={}
var selected_row: int=0
var last_move: float=0
var motion_phase: float=0
var last_facing: int=0
var lulu_duration: float=.7
const LULU=preload("res://art/v6/lulu-original.webp")
const LULU_BATTLE=preload("res://art/v6/lulu-battle.png")
const MUZZLES=[Vector2(44,-73),Vector2(37,-58),Vector2(8,-49),Vector2(-35,-59),Vector2(-44,-73),Vector2(-28,-94),Vector2(0,-101),Vector2(36,-95)]
const TIP_UV=[
	[Vector2(.98,.30),Vector2(.98,.55),Vector2(.98,.60),Vector2(.98,.53),Vector2(.01,.29),Vector2(.01,.32),Vector2(.02,.39),Vector2(.98,.25)],
	[Vector2(.98,.34),Vector2(.98,.49),Vector2(.72,.67),Vector2(.01,.47),Vector2(.01,.34),Vector2(.16,.24),Vector2(.55,.22),Vector2(.98,.14)],
	[Vector2(.93,.40),Vector2(.94,.43),Vector2(.50,.46),Vector2(.07,.40),Vector2(.09,.42),Vector2(.11,.42),Vector2(.50,.12),Vector2(.14,.42)]]
func facing_mirror() -> float:
	# Preserve the complete grip while correcting the two reversed diagonal drawings.
	return -1.0 if (kind==2 and facing_index==7) or (kind==0 and facing_index==3) else 1.0
func full_texture() -> Texture2D:
	if not whole_textures.has(kind):whole_textures[kind]=load("res://art/v6/%s-integrated.png"%["sword","gunner","ranger"][kind])
	return whole_textures[kind]
func play_gesture(id: String,duration: float=.35) -> void:
	super.play_gesture(id,duration)
	if clip==id and id in ["attack","skill_0","skill_1","skill_2","ultimate_gather","ultimate_finish","combo"]:selected_row=3
func frame_data() -> Dictionary:
	if whole_regions.is_empty():whole_regions=JSON.parse_string(FileAccess.get_file_as_string("res://art/v6/integrated_regions.json"))
	return whole_regions[str(kind)][selected_row*8+facing_index]
func frame_mesh() -> ArrayMesh:
	var key=str(kind)+":"+str(selected_row*8+facing_index)
	if frame_meshes.has(key):return frame_meshes[key]
	var data=frame_data();var r=data.rect
	var anchor=Vector2(data.anchor[0],data.anchor[1]);var size=full_texture().get_size()
	var verts=PackedVector2Array();var uvs=PackedVector2Array();var indices=PackedInt32Array()
	for b in data.bands:
		var n=verts.size()
		for v in [Vector2(b[0],b[1]),Vector2(b[2],b[1]),Vector2(b[2],minf(b[3],b[1]+4)),Vector2(b[0],minf(b[3],b[1]+4))]:
			verts.append((v-anchor)*(126.0/275)*Vector2(facing_mirror(),1));uvs.append((v+Vector2(r[0],r[1]))/size)
		indices.append_array(PackedInt32Array([n,n+1,n+2,n,n+2,n+3]))
	var arrays=[];arrays.resize(Mesh.ARRAY_MAX);arrays[Mesh.ARRAY_VERTEX]=verts;arrays[Mesh.ARRAY_TEX_UV]=uvs;arrays[Mesh.ARRAY_INDEX]=indices
	var mesh=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	frame_meshes[key]=mesh;return mesh
func muzzle_local() -> Vector2:
	if articulated_preview:return super.muzzle_local()
	update_pose()
	var data=frame_data();var r=data.rect
	return (Vector2(r[2],r[3])*TIP_UV[kind][facing_index]-Vector2(data.anchor[0],data.anchor[1]))*(126.0/275)*Vector2(facing_mirror(),1)+frame_offset()
func frame_offset() -> Vector2:
	var phase=clampf(clip_time/maxf(.01,clip_length),0,1)
	if clip=="attack":return -aim*2*pow(1-phase,2)
	if clip=="hurt":return -aim*2*sin(phase*PI)
	if clip=="dash":return movement.limit_length(1)*3
	return Vector2.ZERO
func lulu_play(id: String, duration: float) -> void:
	lulu_animation=id;lulu_time=0;lulu_duration=duration
func lulu_battle_frame() -> Vector2i:
	var p=clampf(lulu_time/maxf(lulu_duration,.01),0,.999)
	if dying:return Vector2i(3+mini(2,int(death_time*3)),3)
	match lulu_animation:
		"blow":return Vector2i(mini(5,int(p*6)),0)
		"splash":return Vector2i(mini(5,int(p*6)),1)
		"bath":return Vector2i(mini(5,int(p*6)),2)
		"phase":return Vector2i(mini(2,int(p*3)),3)
	return Vector2i(-1,-1)
func _process(delta: float) -> void:
	if enemy_id==14:
		var parent=get_parent()
		var active=true
		if parent!=null and "game" in parent and parent.game!=null:active=parent.game.state in ["combat","end"]
		if active:
			clock+=delta;lulu_time+=delta;flash=maxf(0,flash-delta)
			if dying:death_time=minf(1,death_time+delta*.8)
			if lulu_time>=lulu_duration:lulu_animation="idle"
		queue_redraw();return
	super._process(delta)
	if not is_hero():return
	var parent=get_parent()
	if parent!=null and "game" in parent and parent.game!=null and parent.game.state not in ["combat","end"]:return
	motion_phase+=delta*playback_speed*clampf(movement.length(),.15,1.5)*8
	var id=forced_clip if not forced_clip.is_empty() else clip
	selected_row=0
	if movement.length()>.08 or id in ["run_forward","run_back","strafe_left","strafe_right"]:selected_row=[1,0,2,0][int(motion_phase)%4]
	if id in ["attack","skill_0","skill_1","skill_2","ultimate_gather","ultimate_sustain","ultimate_finish","combo","dash"]:
		# Keep the authored running frames between short attack releases at high fire rates.
		if movement.length()<=.08 or clip_time<minf(.08,clip_length*.3) or id=="dash":selected_row=3
	if override_phase>=0 and id.begins_with("run"):selected_row=1+mini(1,int(override_phase*2))
	if movement.length()>.08 and last_move<=.08 and id in ["ready","idle","run_forward"]:play_gesture("start",.12)
	if movement.length()<=.08 and last_move>.08 and id.begins_with("run"):play_gesture("stop",.12)
	last_move=movement.length()
	if facing_index!=last_facing and id in ["ready","idle"]:play_gesture("turn",.10)
	last_facing=facing_index
func _draw() -> void:
	if articulated_preview:super._draw();return
	if enemy_id==14:draw_lulu();return
	if not is_hero():super._draw();return
	if pose.is_empty():update_pose()
	var data=frame_data()
	var r=data.rect
	var rect=Rect2(r[0],r[1],r[2],r[3])
	var anchor=Vector2(data.anchor[0],data.anchor[1])
	var s=126.0/275
	var dest=Rect2(-anchor*s,rect.size*s)
	var offset=frame_offset()
	var fade=1-death_time
	draw_set_transform(Vector2(0,4),0,Vector2(1,.28));draw_circle(Vector2.ZERO,24,Color(0,0,0,.3*fade));draw_set_transform(Vector2.ZERO)
	if quality>=2:
		draw_texture_rect(preload("res://art/v6/fx/light_01.png"),Rect2(-42,-98,84,80),false,Color(P.QUALITY[clampi(quality,0,3)],.10*fade))
	if dash_trail>0 and not reduced:draw_mesh(frame_mesh(),full_texture(),Transform2D(0,-aim*18),Color(tint,.18))
	draw_set_transform(offset+Vector2(0,death_time*12),0,Vector2(1,1-death_time*.15))
	draw_mesh(frame_mesh(),full_texture(),Transform2D.IDENTITY,Color(1.15 if flash>0 else 1,1.15 if flash>0 else 1,1.15 if flash>0 else 1,fade))
	draw_set_transform(Vector2.ZERO)
	if debug_joints:
		draw_circle(Vector2.ZERO,2,Color.CYAN)
		draw_circle(muzzle_local(),2,Color.RED)
		draw_line(muzzle_local(),muzzle_local()+aim*60,Color(1,.6,.1,.65),1)
		draw_rect(dest,Color(.5,.8,1,.3),false,1)
func draw_lulu() -> void:
	var battle_frame=lulu_battle_frame()
	if battle_frame.x>=0:
		draw_set_transform(Vector2(0,9),0,Vector2(1,.3));draw_circle(Vector2.ZERO,52,Color(0,0,0,.22*(1-death_time)));draw_set_transform(Vector2.ZERO)
		# Authored rows have different ground lines. Keep bathing feet on the water;
		# the jump/wave row begins slightly above the nominal grid and needs its hat intact.
		var shade=1.12 if flash>0 else 1.0
		var starts=[0,256,512,744];var heights=[256,256,232,280];var ground=[247,238,230,248]
		var row=battle_frame.y;var scale_factor=200.0/256
		var source=Rect2(battle_frame.x*256,starts[row],256,heights[row])
		var destination=Rect2(-100,8-ground[row]*scale_factor,200,heights[row]*scale_factor)
		draw_texture_rect_region(LULU_BATTLE,destination,source,Color(shade,shade,shade,1-death_time*.7))
		return
	var row=0;var frames=7;var rate=6.0
	var parent=get_parent()
	if walking>.05:row=1 if aim.x>=0 else 2;frames=8;rate=9
	if lulu_animation=="phase":row=4;frames=5;rate=7
	if lulu_animation=="bath":row=6;frames=6;rate=3
	if lulu_animation in ["blow","splash"]:row=0;frames=7;rate=5
	if dying:row=3;frames=4;rate=4
	var frame=posmod(int((lulu_time if lulu_animation!="idle" else clock)*rate),frames)
	var rect=Rect2(frame*192,row*208,192,208)
	var h=190.0;var w=h*192/208
	var squash=1.0
	if lulu_animation=="blow":squash=1+sin(minf(1,lulu_time/lulu_duration)*PI)*.035
	if lulu_animation=="splash":squash=1-sin(minf(1,lulu_time/lulu_duration)*PI)*.08
	if lulu_animation=="bath":squash=.85
	draw_set_transform(Vector2(0,9),0,Vector2(1,.3));draw_circle(Vector2.ZERO,52,Color(0,0,0,.22));draw_set_transform(Vector2.ZERO)
	draw_set_transform(Vector2.ZERO,0,Vector2(1/squash,squash))
	draw_texture_rect_region(LULU,Rect2(-w*.5,-h+8,w,h),rect,Color(1.1 if flash>0 else 1,1.1 if flash>0 else 1,1.1 if flash>0 else 1,1-death_time*.7))
	draw_set_transform(Vector2.ZERO)
	if lulu_animation=="blow":
		var p=Vector2(0,-106)
		var radius=5+8*absf(sin(lulu_time*8))
		draw_circle(p,radius,Color(.5,.86,1,.25));draw_arc(p,radius,0,TAU,24,Color(.8,1,1,.8),1.5,true)
	if lulu_animation in ["splash","bath"]:
		draw_set_transform(Vector2(0,-3),0,Vector2(1,.38))
		for i in range(3):draw_arc(Vector2.ZERO,40+fposmod(lulu_time*32+i*22,68),0,TAU,40,Color(.62,.9,1,.42),2,true)
		draw_set_transform(Vector2.ZERO)
