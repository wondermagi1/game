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
			meshes[actor.frame_mesh(actor.selected_row,-1).get_rid()]=true
			sockets.append(actor.muzzle_local())
		check(rows.all(func(row):return row==actor.WALK_ROW),"role %d keeps one stable running silhouette"%role)
		check(meshes.size()==1,"role %d reuses one stable running mesh"%role)
		check(sockets.all(func(p):return p.y<-35 and p.y>-135),"role %d weapon socket follows gait"%role)
		var blend:=actor.walk_row_blend()
		check(blend[0]==actor.WALK_ROW and blend[1]==actor.WALK_ROW and is_zero_approx(float(blend[2])),"role %d does not crossfade incompatible body poses"%role)
		var previous_point:=Vector2.ZERO
		var maximum_step:=0.0
		var smooth_meshes: Dictionary={}
		for sample in range(actor.WALK_MESH_SAMPLE_COUNT):
			actor.override_phase=(sample+.01)/float(actor.WALK_MESH_SAMPLE_COUNT)
			actor._process(0.0)
			var point:=actor.muzzle_local()
			if sample>0:maximum_step=maxf(maximum_step,point.distance_to(previous_point))
			previous_point=point
			smooth_meshes[actor.frame_mesh(actor.selected_row,-1).get_rid()]=true
			check(actor.gait_warp(Vector2(23,-81),sample)==Vector2(23,-81),"role %d sample %d never bends the silhouette"%[role,sample])
			check(is_zero_approx(actor.gait_offset().x) and actor.gait_scale()==Vector2.ONE,"role %d sample %d has no lateral warp or scale pumping"%[role,sample])
		actor.override_phase=.0001;actor._process(0.0)
		maximum_step=maxf(maximum_step,actor.muzzle_local().distance_to(previous_point))
		check(smooth_meshes.size()==1,"role %d avoids duplicate undeformed gait meshes"%role)
		check(maximum_step<1.0,"role %d weapon socket remains stable throughout running"%role)
		actor.override_phase=.125
		actor._process(0.0)
		check(is_zero_approx(actor.gait_rotation()),"role %d walk no longer rocks the whole silhouette"%role)
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
