extends SceneTree

var checks: int=0
var failures: Array=[]

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok:
		failures.append(label)
		push_error(label)

func run() -> void:
	var actor=preload("res://scripts/actor_visual.gd").new()
	root.add_child(actor)
	actor.set_process(false)
	for role in range(3):
		actor.kind=role
		actor.movement=Vector2.ZERO
		actor.clip="attack"
		actor.forced_clip="attack"
		for direction in range(8):
			actor.aim=Vector2.from_angle(direction*PI/4.0)
			actor.facing_index=direction
			var meshes: Dictionary={}
			var sockets: Array=[]
			for phase in range(6):
				actor.override_phase=(phase+.01)/6.0
				actor._process(0.0)
				meshes[actor.frame_mesh(3,-1,direction,"attack",phase).get_rid()]=true
				sockets.append(actor.muzzle_local())
			check(meshes.size()==6,"role %d direction %d has six attack deformation phases"%[role,direction])
			check(sockets.all(func(p):return p.length()<180 and p.y<5),"role %d direction %d socket remains attached"%[role,direction])
	actor.kind=0
	actor.aim=Vector2.RIGHT
	actor.facing_index=0
	actor.movement=Vector2.RIGHT
	actor.last_motion_direction=Vector2.RIGHT
	for id in ["start","stop","dash","hurt","skill_0","ultimate_gather","combo"]:
		actor.forced_clip=id
		actor.clip=id
		actor.override_phase=.35
		actor._process(0.0)
		check(actor.frame_mesh(actor.selected_row,-1,0,id,actor.action_frame_index()).get_surface_count()==1,"motion clip %s renders"%id)
	actor.forced_clip="turn"
	actor.clip="turn"
	actor.turn_from_facing=0
	actor.facing_index=4
	actor.override_phase=.25
	actor._process(0.0)
	check(actor.frame_mesh(0,-1,actor.turn_from_facing,"turn",actor.action_frame_index()).get_surface_count()==1,"turn keeps previous facing for crossfade")
	actor.forced_clip="ready"
	actor.clip="ready"
	actor.override_phase=-1
	actor.movement=Vector2.ZERO
	actor._process(0.0)
	check(actor.frame_offset()==Vector2.ZERO and actor.frame_scale()==Vector2.ONE,"ready pose has no action displacement")
	var report={"checks":checks,"failures":failures}
	var file=FileAccess.open("res://tests/regression_motion_v8_results.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"  "))
	print("MOTION_V8_REGRESSION="+JSON.stringify(report))
	actor.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
