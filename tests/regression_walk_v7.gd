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
		actor.aim=Vector2.RIGHT
		actor.movement=Vector2.RIGHT
		actor.clip="run_forward"
		actor.forced_clip="run_forward"
		var meshes: Dictionary={}
		var rows: Array=[]
		var sockets: Array=[]
		for phase in range(8):
			actor.override_phase=(phase+.01)/8.0
			actor._process(0.0)
			check(actor.walk_frame_index()==phase,"role %d gait phase %d"%[role,phase])
			rows.append(actor.selected_row)
			meshes[actor.frame_mesh(actor.selected_row,phase).get_rid()]=true
			sockets.append(actor.muzzle_local())
		check(rows==Array(actor.WALK_ROWS),"role %d authored gait sequence"%role)
		check(meshes.size()==8,"role %d owns eight rendered in-between meshes"%role)
		check(sockets.all(func(p):return p.y<-35 and p.y>-135),"role %d weapon socket follows gait"%role)
		actor.movement=Vector2.ZERO
		actor.forced_clip="ready"
		actor.override_phase=-1
		actor._process(0.0)
		check(actor.gait_offset()==Vector2.ZERO and actor.gait_scale()==Vector2.ONE,"role %d idle stays grounded"%role)
	actor.queue_free()
	var report={"checks":checks,"failures":failures}
	var file=FileAccess.open("res://tests/regression_walk_v7_results.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"  "))
	print("WALK_V7_REGRESSION="+JSON.stringify(report))
	await process_frame
	quit(0 if failures.is_empty() else 1)
