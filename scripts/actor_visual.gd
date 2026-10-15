@tool
extends "res://scripts/actor_integrated.gd"
## Western costume bank: body and held weapon are authored in every frame.
const Western = preload("res://scripts/western_art.gd")
const SKILL_PATHS = ["res://art/western/sword-skills.png","res://art/western/gunner-skills.png","res://art/western/ranger-skills.png"]
static var painted_library: AnimationLibrary
var painted_frame: int = 0
var pose_player: AnimationPlayer

func _ready() -> void:
	if not is_hero(): return
	pose_player = AnimationPlayer.new()
	pose_player.name = "PaintedSkillAnimation"
	pose_player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	add_child(pose_player)
	if painted_library==null:
		painted_library = AnimationLibrary.new()
		for id in ["attack","skill_0","skill_1","skill_2","ultimate_gather","ultimate_sustain","ultimate_finish","combo"]:
			var animation = Animation.new()
			animation.length = 1.0
			var track = animation.add_track(Animation.TYPE_VALUE)
			animation.track_set_path(track,NodePath(".:painted_frame"))
			animation.value_track_set_update_mode(track,Animation.UPDATE_DISCRETE)
			var frames = [0,1,2,3]
			var times = [0.0,.12,.27,.75]
			if id=="ultimate_gather": times = [0.0,.12,.366,.85]
			if id=="ultimate_sustain": frames = [2,2,2,2]
			if id=="ultimate_finish": frames = [1,2,2,3]
			for i in range(frames.size()): animation.track_insert_key(track,times[i],frames[i])
			painted_library.add_animation(id,animation)
	pose_player.add_animation_library("",painted_library)

func _process(delta: float) -> void:
	super._process(delta)
	if not is_hero() or pose_player==null: return
	var id = active_clip()
	if painted_library.has_animation(id):
		if pose_player.current_animation!=id: pose_player.play(id)
		pose_player.seek(action_phase(),true)
	else:
		pose_player.stop()
		painted_frame = 0
	queue_redraw()

func release_pose(slot: int) -> void:
	# Normal casts release at 0.12 s; C retains its existing 0.22 s release phase.
	if slot<3:
		clip_time = clip_length*.28
		painted_frame = 2
		if pose_player!=null:
			pose_player.play("skill_%d"%slot)
			pose_player.seek(.28,true)

func muzzle_local() -> Vector2:
	if not is_hero(): return Vector2.ZERO
	var distance: float = [58.0,71.0,65.0][kind]
	return Vector2(aim.x*distance,-70+aim.y*18)+frame_offset()+gait_offset()

func painted_source() -> Dictionary:
	var id = active_clip()
	var skill_row = -1
	if id.begins_with("skill_"): skill_row = clampi(int(id.trim_prefix("skill_")),0,2)
	elif id.begins_with("ultimate") or id=="combo": skill_row = 3
	elif id.begins_with("reload"): skill_row = 2
	if id=="attack": skill_row = 1 if kind==0 else 0
	if skill_row>=0:
		return {"path":SKILL_PATHS[kind],"cell":skill_row*4+clampi(painted_frame,0,3),"columns":4,"flip":aim.x<0}
	var row = action_keyframe_row()
	return {"path":Western.HERO_PATHS[kind],"cell":row,"columns":6,"flip":false}

func _draw() -> void:
	if enemy_id==14: draw_lulu(); return
	if not is_hero():
		draw_western_enemy()
		return
	var data = painted_source()
	var tex = Western.texture(data.path)
	var alpha = 1-death_time
	draw_set_transform(Vector2(0,4),0,Vector2(1,.28))
	draw_circle(Vector2.ZERO,24,Color(0,0,0,.3*alpha))
	draw_set_transform(frame_offset()+gait_offset()+Vector2(0,death_time*12),0,Vector2(-1 if data.flip else 1,1))
	# No mesh warping, body rotation or scale pulses: animate painted poses only.
	var light = 1.18 if flash>0 else 1.0
	draw_mesh(Western.hero_mesh(data.path,data.cell),tex,Transform2D.IDENTITY,Color(light,light,light,alpha))
	draw_set_transform(Vector2.ZERO)

func draw_western_enemy() -> void:
	var id = clampi(enemy_id if enemy_id>=0 else kind-3,0,18)
	var source = Western.region(Western.MONSTER_PATH,Western.MONSTER_CELLS[id],4,4)
	var height = 155.0 if id in [4,5,6,7,8,12,13] else 94.0
	var size = source.size*(height/source.size.y)
	var alpha = 1-death_time
	draw_set_transform(Vector2(0,8),0,Vector2(1,.30))
	draw_circle(Vector2.ZERO,30,Color(0,0,0,.28*alpha))
	draw_set_transform(Vector2(0,0 if reduced else -absf(sin(clock*6))*walking*1.3),0,Vector2(-1 if aim.x<0 else 1,1))
	var light = 1.25 if flash>0 else 1.0
	draw_texture_rect_region(Western.texture(Western.MONSTER_PATH),Rect2(Vector2(-size.x*.5,-height+8),size),source,Color(light,light,light,alpha))
	draw_set_transform(Vector2.ZERO)
