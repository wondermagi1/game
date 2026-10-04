@tool
extends "res://scripts/actor_v6.gd"
## Default route: body, hands and weapon share one painted animation frame.
## The joint rig remains available only in the inspection scene for comparison.
@export var articulated_preview: bool = false
@export var action_keyframes_enabled: bool = true
static var whole_textures: Dictionary={}
static var whole_regions: Dictionary={}
static var frame_meshes: Dictionary={}
const WALK_PHASE_COUNT: int=8
const WALK_ROWS=[0,1,1,0,0,2,2,0]
const ACTION_PHASE_COUNT: int=6
const ACTION_KEYFRAME_CELL:=Vector2(256,256)
# Generated v9 action atlases: 6 columns (wind-up -> recovery) by 4 rows
# (right, down, left, up). They are AI-assisted raster source art, then wired
# and validated locally; they are not described as hand-drawn animation.
const ACTION_KEYFRAME_SHEETS=[
	preload("res://art/v9/sword-attack-keyframes-source.png"),
	preload("res://art/v9/gunner-attack-keyframes-source.png"),
	preload("res://art/v9/ranger-attack-keyframes-source.png")]
const ACTION_KEYFRAME_ROW_BY_FACING=[0,1,1,2,2,3,3,0]
# Keep the raster attack silhouettes at the same perceived height as the
# integrated idle/run art. Per-role enlargement caused visible size pumping.
const ACTION_KEYFRAME_SCALE=[.50,.50,.50]
const ACTION_SOCKET_DISTANCE=[
	[38.0,55.0,76.0,86.0,64.0,48.0],
	[67.0,73.0,78.0,72.0,61.0,69.0],
	[52.0,66.0,78.0,82.0,68.0,54.0]]
const MOTION_CLIPS=["start","stop","turn","attack","dash","hurt","reload_open","reload_insert","reload_close","skill_0","skill_1","skill_2","ultimate_gather","ultimate_sustain","ultimate_finish","combo","victory","death"]
var selected_row: int=0
var last_move: float=0
var motion_phase: float=0
var last_facing: int=0
var turn_from_facing: int=0
var last_motion_direction := Vector2.RIGHT
var lulu_duration: float=.7
const LULU=preload("res://art/v6/lulu-original.webp")
const LULU_BATTLE=preload("res://art/v6/lulu-battle.png")
const MUZZLES=[Vector2(44,-73),Vector2(37,-58),Vector2(8,-49),Vector2(-35,-59),Vector2(-44,-73),Vector2(-28,-94),Vector2(0,-101),Vector2(36,-95)]
const TIP_UV=[
	[Vector2(.98,.30),Vector2(.98,.55),Vector2(.98,.60),Vector2(.98,.53),Vector2(.01,.29),Vector2(.01,.32),Vector2(.02,.39),Vector2(.98,.25)],
	[Vector2(.98,.34),Vector2(.98,.49),Vector2(.72,.67),Vector2(.01,.47),Vector2(.01,.34),Vector2(.16,.24),Vector2(.55,.22),Vector2(.98,.14)],
	[Vector2(.93,.40),Vector2(.94,.43),Vector2(.50,.46),Vector2(.07,.40),Vector2(.09,.42),Vector2(.11,.42),Vector2(.50,.12),Vector2(.14,.42)]]
func facing_mirror(direction_index: int=-1) -> float:
	# Preserve the complete grip while correcting the two reversed diagonal drawings.
	var direction=facing_index if direction_index<0 else direction_index
	return -1.0 if (kind==2 and direction==7) or (kind==0 and direction==3) else 1.0
func full_texture() -> Texture2D:
	if not whole_textures.has(kind):whole_textures[kind]=load("res://art/v6/%s-integrated.png"%["sword","gunner","ranger"][kind])
	return whole_textures[kind]
func play_gesture(id: String,duration: float=.35) -> void:
	super.play_gesture(id,duration)
	if clip==id and id in ["attack","skill_0","skill_1","skill_2","ultimate_gather","ultimate_finish","combo"]:selected_row=3
func frame_data(row: int=-1, direction_index: int=-1) -> Dictionary:
	if whole_regions.is_empty():whole_regions=JSON.parse_string(FileAccess.get_file_as_string("res://art/v6/integrated_regions.json"))
	var source_row=selected_row if row<0 else row
	var direction=facing_index if direction_index<0 else direction_index
	return whole_regions[str(kind)][source_row*8+direction]
func active_clip() -> String:
	return forced_clip if not forced_clip.is_empty() else clip
func action_phase() -> float:
	var id=active_clip()
	if override_phase>=0 and not id.begins_with("run"):return clampf(override_phase,0.0,.999)
	return clampf(clip_time/maxf(.01,clip_length),0.0,.999)
func action_frame_index() -> int:
	return mini(ACTION_PHASE_COUNT-1,int(action_phase()*ACTION_PHASE_COUNT))
func uses_attack_keyframes() -> bool:
	return action_keyframes_enabled and is_hero() and active_clip()=="attack" and kind>=0 and kind<ACTION_KEYFRAME_SHEETS.size()
func action_keyframe_row(direction_index: int=-1) -> int:
	var direction=facing_index if direction_index<0 else posmod(direction_index,8)
	return ACTION_KEYFRAME_ROW_BY_FACING[direction]
func action_keyframe_source(frame: int=-1,direction_index: int=-1) -> Rect2:
	var phase=action_frame_index() if frame<0 else clampi(frame,0,ACTION_PHASE_COUNT-1)
	return Rect2(Vector2(phase,action_keyframe_row(direction_index))*ACTION_KEYFRAME_CELL,ACTION_KEYFRAME_CELL)
func action_keyframe_destination() -> Rect2:
	var scale_factor=ACTION_KEYFRAME_SCALE[clampi(kind,0,ACTION_KEYFRAME_SCALE.size()-1)]
	# Every authored cell is normalized to the same 252 px foot line, so attack frames no
	# longer skate even when the torso and weapon silhouette changes strongly.
	return Rect2(Vector2(-ACTION_KEYFRAME_CELL.x*.5,-252.0)*scale_factor,ACTION_KEYFRAME_CELL*scale_factor)
func action_warp(point: Vector2, id: String="", frame: int=-1) -> Vector2:
	if frame<0 or not id in MOTION_CLIPS:return point
	var p=(frame+.5)/ACTION_PHASE_COUNT
	var upper=clampf(-point.y/118.0,0.0,1.0)
	var wave=sin(p*PI)
	var shift=Vector2.ZERO
	match id:
		"start":shift=-last_motion_direction*(1.0-p)*3.0*upper
		"stop":shift=last_motion_direction*(1.0-p)*4.0*upper
		"turn":shift=Vector2(sin(p*TAU)*2.0*upper,0)
		"attack":
			if kind==0:shift=aim*wave*7.5*upper+aim.orthogonal()*sin(p*TAU)*1.25*upper
			elif kind==1:shift=-aim*pow(1.0-p,2.0)*9.5*upper+aim.orthogonal()*wave*.8*upper
			else:shift=-aim*(1.0-p)*6.5*upper+Vector2(0,-wave*2.0*upper)
		"dash":shift=last_motion_direction*5.0*upper+Vector2(0,2.5*upper)
		"hurt":shift=-aim*wave*4.5*upper
		"reload_open","reload_insert","reload_close":shift=aim.orthogonal()*sin(p*TAU)*1.4*upper
		"skill_0","skill_1","skill_2":shift=aim*wave*2.5*upper+Vector2(0,-wave*2.0*upper)
		"ultimate_gather","ultimate_sustain","ultimate_finish","combo":shift=Vector2(0,-wave*4.0*upper)+aim*wave*2.0*upper
		"victory":shift=Vector2(0,-wave*3.0*upper)
		"death":shift=Vector2(0,p*12.0*upper)
	return point+shift
func walk_phase() -> float:
	var id=forced_clip if not forced_clip.is_empty() else clip
	if override_phase>=0 and id.begins_with("run"):return fposmod(override_phase,1.0)
	return fposmod(motion_phase,1.0)
func walk_frame_index() -> int:
	return mini(WALK_PHASE_COUNT-1,int(walk_phase()*WALK_PHASE_COUNT))
func walk_render_active() -> bool:
	var id=forced_clip if not forced_clip.is_empty() else clip
	return is_hero() and not dying and movement.length()>.08 and id!="dash" and selected_row<3
func gait_warp(point: Vector2, frame: int=-1) -> Vector2:
	if frame<0:return point
	var phase=float(frame)/WALK_PHASE_COUNT
	var upper=clampf(-point.y/112.0,0.0,1.0)
	var stride=sin(phase*TAU)
	var double_step=sin(phase*TAU*2.0)
	# Keep the integrated character and weapon together while the horizontal
	# bands provide eight subtle in-between silhouettes. Feet stay anchored.
	return point+Vector2((stride*1.35+double_step*.45)*upper,-absf(stride)*1.05*upper)
func gait_offset() -> Vector2:
	if not walk_render_active() or reduced:return Vector2.ZERO
	var phase=walk_phase()
	return Vector2(sin(phase*TAU)*.35,-absf(sin(phase*TAU))*1.4)
func gait_rotation() -> float:
	if not walk_render_active() or reduced:return 0.0
	return sin(walk_phase()*TAU)*.009
func gait_scale() -> Vector2:
	if not walk_render_active() or reduced:return Vector2.ONE
	var lift=absf(sin(walk_phase()*TAU))
	return Vector2(1.0+lift*.005,1.0-lift*.009)
func gait_point(point: Vector2) -> Vector2:
	if not walk_render_active():return point
	var warped=gait_warp(point,walk_frame_index())*gait_scale()
	return warped.rotated(gait_rotation())+gait_offset()
func frame_mesh(row: int=-1, gait_frame: int=-1, direction_index: int=-1, action_id: String="", action_frame: int=-1) -> ArrayMesh:
	var source_row=selected_row if row<0 else row
	var direction=facing_index if direction_index<0 else direction_index
	var key=str(kind)+":"+str(source_row*8+direction)+":"+str(gait_frame)+":"+action_id+":"+str(action_frame)
	if frame_meshes.has(key):return frame_meshes[key]
	var data=frame_data(source_row,direction);var r=data.rect
	var anchor=Vector2(data.anchor[0],data.anchor[1]);var size=full_texture().get_size()
	var verts=PackedVector2Array();var uvs=PackedVector2Array();var indices=PackedInt32Array()
	for b in data.bands:
		var n=verts.size()
		for v in [Vector2(b[0],b[1]),Vector2(b[2],b[1]),Vector2(b[2],minf(b[3],b[1]+4)),Vector2(b[0],minf(b[3],b[1]+4))]:
			var local=(v-anchor)*(126.0/275)*Vector2(facing_mirror(direction),1)
			local=gait_warp(local,gait_frame)
			verts.append(action_warp(local,action_id,action_frame));uvs.append((v+Vector2(r[0],r[1]))/size)
		indices.append_array(PackedInt32Array([n,n+1,n+2,n,n+2,n+3]))
	var arrays=[];arrays.resize(Mesh.ARRAY_MAX);arrays[Mesh.ARRAY_VERTEX]=verts;arrays[Mesh.ARRAY_TEX_UV]=uvs;arrays[Mesh.ARRAY_INDEX]=indices
	var mesh=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	frame_meshes[key]=mesh;return mesh
func muzzle_local() -> Vector2:
	if articulated_preview:return super.muzzle_local()
	update_pose()
	if uses_attack_keyframes():
		var distance=ACTION_SOCKET_DISTANCE[kind][action_frame_index()]
		# Vertical aim is foreshortened by the three-quarter camera. The socket
		# stays around the hands/barrel instead of sliding down to the character's feet.
		return Vector2(aim.x,aim.y*.55)*distance+Vector2(0,-66)+frame_offset()
	var data=frame_data();var r=data.rect
	var point=(Vector2(r[2],r[3])*TIP_UV[kind][facing_index]-Vector2(data.anchor[0],data.anchor[1]))*(126.0/275)*Vector2(facing_mirror(),1)
	point=gait_warp(point,walk_frame_index() if walk_render_active() else -1)
	point=action_warp(point,active_clip(),action_frame_index())
	if walk_render_active():point=(point*gait_scale()).rotated(gait_rotation())+gait_offset()
	return point+frame_offset()
func frame_offset() -> Vector2:
	var phase=action_phase()
	var id=active_clip()
	if id=="start":return -last_motion_direction*2.5*pow(1.0-phase,2.0)
	if id=="stop":return last_motion_direction*3.0*pow(1.0-phase,2.0)
	if id=="attack":
		if kind==0:return aim*3.5*sin(phase*PI)
		if kind==1:return -aim*6.0*pow(1.0-phase,2.0)
		return -aim*3.5*pow(1.0-phase,2.0)
	if id=="hurt":return -aim*4.0*sin(phase*PI)
	if id=="dash":return last_motion_direction*5.0
	if id.begins_with("ultimate"):return Vector2(0,-3.0*sin(phase*PI))
	return Vector2.ZERO
func frame_rotation() -> float:
	if reduced:return 0.0
	var phase=action_phase();var id=active_clip();var wave=sin(phase*PI)
	if id=="attack":return [-.03,-.042,.024][kind]*wave
	if id=="hurt":return .035*wave*(-1.0 if aim.x>=0 else 1.0)
	if id=="dash":return -.02*last_motion_direction.x
	if id=="turn":return sin(phase*TAU)*.018
	return 0.0
func frame_scale() -> Vector2:
	if reduced:return Vector2.ONE
	var phase=action_phase();var id=active_clip();var wave=sin(phase*PI)
	if id=="attack" and kind==1:return Vector2(1.0+wave*.02,1.0-wave*.016)
	if id=="attack" and kind==2:return Vector2(1.0-wave*.014,1.0+wave*.02)
	if id.begins_with("ultimate"):return Vector2(1.0+wave*.012,1.0-wave*.018)
	return Vector2.ONE
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
	var id=forced_clip if not forced_clip.is_empty() else clip
	var move_strength=clampf(movement.length(),0.0,1.25)
	if move_strength>.08:last_motion_direction=movement.normalized()
	if move_strength>.08 and not (override_phase>=0 and id.begins_with("run")):
		# Eight visual phases yield about 13-19 gait updates each second at normal speed.
		var cadence=lerpf(1.55,2.35,clampf((move_strength-.08)/.92,0.0,1.0))
		motion_phase=fposmod(motion_phase+delta*playback_speed*cadence,1.0)
	selected_row=0
	if movement.length()>.08 or id in ["run_forward","run_back","strafe_left","strafe_right"]:selected_row=WALK_ROWS[walk_frame_index()]
	if id in ["attack","skill_0","skill_1","skill_2","ultimate_gather","ultimate_sustain","ultimate_finish","combo","dash"]:
		# Keep the authored running frames between short attack releases at high fire rates.
		if movement.length()<=.08 or clip_time<minf(.08,clip_length*.3) or id=="dash":selected_row=3
	if movement.length()>.08 and last_move<=.08 and id in ["ready","idle","run_forward"]:play_gesture("start",.12)
	if movement.length()<=.08 and last_move>.08 and id.begins_with("run"):play_gesture("stop",.12)
	last_move=movement.length()
	if facing_index!=last_facing and id in ["ready","idle"]:
		turn_from_facing=last_facing
		play_gesture("turn",.12)
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
	var id=active_clip()
	var action_sample=action_frame_index() if id in MOTION_CLIPS else -1
	var gait_sample=walk_frame_index() if walk_render_active() else -1
	draw_set_transform(Vector2(0,4),0,Vector2(1,.28));draw_circle(Vector2.ZERO,24,Color(0,0,0,.3*fade));draw_set_transform(Vector2.ZERO)
	if quality>=2:
		draw_texture_rect(preload("res://art/v6/fx/light_01.png"),Rect2(-42,-98,84,80),false,Color(P.QUALITY[clampi(quality,0,3)],.10*fade))
	if dash_trail>0 and not reduced:draw_mesh(frame_mesh(),full_texture(),Transform2D(0,-aim*18),Color(tint,.18))
	draw_set_transform(offset+gait_offset()+Vector2(0,death_time*12),gait_rotation()+frame_rotation(),gait_scale()*frame_scale()*Vector2(1,1-death_time*.15))
	var shade=1.15 if flash>0 else 1.0
	if uses_attack_keyframes():
		draw_texture_rect_region(ACTION_KEYFRAME_SHEETS[kind],action_keyframe_destination(),action_keyframe_source(),Color(shade,shade,shade,fade))
	else:
		if id=="turn" and turn_from_facing!=facing_index:
			var old_alpha=(1.0-action_phase())*.42*fade
			draw_mesh(frame_mesh(selected_row,-1,turn_from_facing,"turn",action_sample),full_texture(),Transform2D.IDENTITY,Color(1,1,1,old_alpha))
		draw_mesh(frame_mesh(selected_row,gait_sample,facing_index,id,action_sample),full_texture(),Transform2D.IDENTITY,Color(shade,shade,shade,fade))
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
