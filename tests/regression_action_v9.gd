extends SceneTree

var checks: int=0
var failures: Array=[]

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:
		failures.append(label)
		push_error(label)

func run() -> void:
	var actor=preload("res://scripts/actor_visual.gd").new()
	root.add_child(actor)
	actor.set_process(false)
	var sheets=[
		load("res://art/v9/sword-attack-keyframes-source.png"),
		load("res://art/v9/gunner-attack-keyframes-source.png"),
		load("res://art/v9/ranger-attack-keyframes-source.png")]
	for role in range(3):
		var sheet: Texture2D=sheets[role]
		check(sheet.get_size()==Vector2(1536,1024),"role %d atlas is 6x4 cells"%role)
		var image=sheet.get_image()
		check(image!=null and image.get_pixel(0,0).a<.01,"role %d atlas keeps transparent background"%role)
		actor.kind=role
		actor.clip="attack"
		actor.forced_clip="attack"
		check(actor.uses_attack_keyframes(),"role %d routes basic attack to v9 keyframes"%role)
		var regions: Dictionary={}
		for cardinal in [0,2,4,6]:
			actor.facing_index=cardinal
			actor.aim=Vector2.from_angle(cardinal*PI/4.0)
			for phase in range(6):
				actor.override_phase=(phase+.01)/6.0
				actor._process(0.0)
				var source=actor.action_keyframe_source()
				regions[str(source.position)]=true
				check(source.position.x>=0 and source.position.y>=0 and source.end.x<=1536 and source.end.y<=1024,"role %d direction %d phase %d stays inside atlas"%[role,cardinal,phase])
				var socket=actor.muzzle_local()
				check(socket.length()<180 and socket.y<-35,"role %d direction %d phase %d socket remains at the held weapon"%[role,cardinal,phase])
		check(regions.size()==24,"role %d exposes 24 unique four-direction keyframes"%role)
		var destination=actor.action_keyframe_destination()
		check(destination.size.y>=127 and destination.size.y<=129 and absf(destination.end.y)<5,"role %d keeps a stable action foot line without enlarging"%role)
	actor.action_keyframes_enabled=false
	check(not actor.uses_attack_keyframes(),"legacy integrated renderer remains available as fallback")
	var report={"checks":checks,"failures":failures}
	var file=FileAccess.open("res://tests/regression_action_v9_results.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"  "))
	print("ACTION_V9_REGRESSION="+JSON.stringify(report))
	actor.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
