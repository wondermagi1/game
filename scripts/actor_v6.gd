@tool
extends "res://scripts/actor_v5.gd"
## Eight authored views + two-link articulated limbs. Foot origin stays on the ground.
const Poses = preload("res://scripts/pose_library.gd")
static var layouts: Dictionary = {}
static var textures: Dictionary = {}
var clip: String = "ready"
var clip_time: float = 0
var clip_length: float = .3
var forced_clip: String = ""
var playback_speed: float = 1
var debug_joints: bool = false
var movement := Vector2.ZERO
var facing_index: int = 0
var pose: Dictionary = {}
var previous_walk: float = 0
var event_sequence: int = 0
var override_phase: float = -1
var lulu_animation: String = "idle"
var lulu_time: float = 0

func is_hero() -> bool: return kind<3 and enemy_id<0
func texture() -> Texture2D:
	var role = clampi(kind,0,2)
	if not textures.has(role): textures[role] = load("res://art/v6/%s-parts.png"%["sword","gunner","ranger"][role])
	return textures[role]
func regions() -> Array:
	if layouts.is_empty(): layouts=JSON.parse_string(FileAccess.get_file_as_string("res://art/v6/rig_regions.json"))
	return layouts.get(str(clampi(kind,0,2)),[])
func play_gesture(id: String, duration: float = .35) -> void:
	if not is_hero(): return
	if clip.begins_with("ultimate") and id=="attack": return
	clip=id; clip_time=0; clip_length=maxf(.04,duration); event_sequence+=1
	update_pose()
func update_pose() -> void:
	if not is_hero(): return
	var direction = aim.normalized() if aim.length_squared()>.001 else Vector2.RIGHT
	var current_angle = facing_index*PI/4
	if absf(angle_difference(current_angle,direction.angle()))>PI/8+.055:
		facing_index = posmod(roundi(direction.angle()/(PI/4)),8)
	var phase = override_phase if override_phase>=0 else clampf(clip_time/maxf(.01,clip_length),0,1)
	pose=Poses.pose(kind,direction,movement,clock,forced_clip if not forced_clip.is_empty() else clip,phase)
func muzzle_local() -> Vector2:
	update_pose()
	return pose.get("muzzle",Vector2(40,-58))
func _process(delta: float) -> void:
	if not is_hero():
		super._process(delta)
		if enemy_id==14: lulu_time+=delta
		return
	var owner_node = get_parent()
	var allowed = true
	if owner_node!=null and "game" in owner_node and owner_node.game!=null:
		var game = owner_node.game
		reduced=game.reduced_motion
		allowed=game.state in ["combat","end"]
		if "velocity" in owner_node: movement=owner_node.velocity/280.0
		if "reload_time" in owner_node and owner_node.reload_time>0 and not clip.begins_with("ultimate"):
			var ratio=1-owner_node.reload_time/maxf(.01,owner_node.reload_duration())
			clip=["reload_open","reload_insert","reload_close"][mini(2,int(ratio*3))]
			clip_time=fposmod(ratio*3,1);clip_length=1
	if allowed:
		clock+=delta*playback_speed
		clip_time+=delta*playback_speed
		action=maxf(0,action-delta);flash=maxf(0,flash-delta);dash_trail=maxf(0,dash_trail-delta)
		if dying: clip="death";death_time=minf(1,death_time+delta);clip_time=death_time;clip_length=1
		elif clip_time>=clip_length:
			if movement.length()>.08:
				var along=aim.dot(movement.normalized())
				clip="run_forward" if along>.45 else ("run_back" if along<-.45 else ("strafe_left" if aim.cross(movement)<0 else "strafe_right"))
			else: clip="ready"
	update_pose();queue_redraw()
func piece(index: int, a: Vector2, b: Vector2, col: Color) -> void:
	var cells=regions()
	if cells.size()<16: return
	var cell: Dictionary=cells[index]
	var data: Array=cell.rect
	var rect=Rect2(data[0],data[1],data[2],data[3])
	var ja=Vector2(cell.joint_a[0],cell.joint_a[1])
	var jb=Vector2(cell.joint_b[0],cell.joint_b[1])
	var scale_value=a.distance_to(b)/maxf(1,ja.distance_to(jb))
	var angle=(b-a).angle()-(jb-ja).angle()
	draw_set_transform(a,angle,Vector2.ONE*scale_value)
	draw_texture_rect_region(texture(),Rect2(-ja,rect.size),rect,col)
	draw_set_transform(Vector2.ZERO)
func torso(col: Color) -> void:
	var cells=regions()
	if cells.size()<8:return
	var r: Array=cells[facing_index].rect
	var rect=Rect2(r[0],r[1],r[2],r[3])
	var h=86.0 if kind!=0 else 91.0
	var w=h*rect.size.x/rect.size.y
	draw_set_transform(pose.body)
	draw_texture_rect_region(texture(),Rect2(-w/2,-112,w,h),rect,col)
	draw_set_transform(Vector2.ZERO)
func arm(left: bool, col: Color) -> void:
	var suffix="l" if left else "r"
	piece(8 if left else 9,pose["shoulder_"+suffix],pose["elbow_"+suffix],col)
	piece(10 if left else 11,pose["elbow_"+suffix],pose["hand_"+suffix],col)
func weapon_v6(col: Color) -> void:
	draw_set_transform(pose.weapon,pose.angle,Vector2(pose.foreshorten,1))
	if kind==1:
		draw_texture_rect_region(Art.WEAPONS,Rect2(-24,-7,76,14),Rect2(45,378,1460,265),col)
	elif kind==0:
		Art.weapon(self,0,76,4,Color(col))
	else:
		var pull: float=pose.draw*17
		draw_arc(Vector2(0,0),32,-1.14,1.14,24,Color("#ac875a"),4,true)
		draw_arc(Vector2(1,0),30,-1.12,1.12,24,Color("#eddaab"),1.5,true)
		draw_line(Vector2(13,-29),Vector2(-8-pull,0),Color("#e8ddc4"),1,true)
		draw_line(Vector2(13,29),Vector2(-8-pull,0),Color("#e8ddc4"),1,true)
		Art.weapon(self,2,70,2,col)
	draw_set_transform(Vector2.ZERO)
func _draw() -> void:
	if not is_hero():
		super._draw()
		return
	if pose.is_empty():update_pose()
	var fade=1-death_time
	var white=1.15 if flash>0 else 1.0
	var col=Color(white,white,white,fade)
	draw_set_transform(Vector2(0,7),0,Vector2(1,.26));draw_circle(Vector2.ZERO,24,Color(0,0,0,.32*fade));draw_set_transform(Vector2.ZERO)
	for left in [true,false]:
		var suffix="l" if left else "r"
		var hip: Vector2=pose["hip_"+suffix]
		var foot: Vector2=pose["foot_"+suffix]
		var knee=hip.lerp(foot,.52)+Vector2(movement.x*5, -absf(movement.y)*3)
		piece(12 if left else 13,hip,knee,col)
		piece(14 if left else 15,knee,foot,col)
	var back = facing_index in [5,6,7]
	arm(true,col)
	if back: arm(false,col);weapon_v6(col)
	torso(col)
	if not back:weapon_v6(col);arm(false,col)
	if debug_joints:
		for key in ["shoulder_l","elbow_l","hand_l","shoulder_r","elbow_r","hand_r","muzzle","foot_l","foot_r"]:
			draw_circle(pose[key],2.2,Color.GREEN if key!="muzzle" else Color.RED)
		draw_line(pose.hand_r,pose.weapon,Color.GOLD,1)
		draw_circle(Vector2.ZERO,3,Color.CYAN)
