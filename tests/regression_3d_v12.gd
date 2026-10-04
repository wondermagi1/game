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
	var source=preload("res://scripts/actor_visual.gd").new()
	source.kind=0;source.aim=Vector2.RIGHT;source.movement=Vector2.RIGHT
	source.clip="run_forward";source.forced_clip="run_forward";source.override_phase=.125
	root.add_child(source);source.set_process(false);source._process(0.0)
	var adapter=preload("res://scripts/character_3d_sword.gd").new()
	adapter.state_source=source
	root.add_child(adapter)
	await process_frame
	adapter._process(.016)
	check(adapter.viewport!=null,"3D adapter owns a SubViewport")
	check(adapter.viewport.transparent_bg,"3D viewport keeps the 2D battlefield visible")
	check(adapter.viewport.size==Vector2i(384,384),"3D viewport has bounded render cost")
	check(adapter.camera!=null and adapter.camera.projection==Camera3D.PROJECTION_ORTHOGONAL,"3D character uses an orthographic tactical camera")
	check(adapter.weapon_pivot.get_parent()==adapter.forearm_r,"sword is attached to the right-hand hierarchy")
	check(adapter.weapon_tip.get_parent()==adapter.weapon_pivot,"weapon VFX socket follows the sword")
	check(adapter.current_state=="run_forward","locomotion state reaches the 3D rig")
	check(absf(adapter.leg_l.rotation.x)>0.01,"locomotion animates the leg hierarchy")
	check(adapter.muzzle_local().is_finite(),"projectile socket projects back into 2D space")
	check(adapter.muzzle_local().length()<260,"projectile socket remains near the character")
	adapter.set_enabled(false)
	check(not adapter.is_processing() and adapter.viewport.render_target_update_mode==SubViewport.UPDATE_DISABLED,"disabled 3D mode stops its render cost")
	adapter.set_enabled(true)
	check(adapter.is_processing() and adapter.viewport.render_target_update_mode==SubViewport.UPDATE_ALWAYS,"enabled 3D mode resumes rendering")

	source.forced_clip="attack";source.clip="attack";source.clip_time=.15;source.clip_length=.3
	adapter._process(.016)
	check(adapter.current_state=="attack","attack state reaches the 3D rig")
	check(absf(adapter.arm_r.rotation.x)>0.2,"attack drives the weapon arm")
	source.forced_clip="dash";source.clip="dash"
	adapter._process(.016)
	check(adapter.current_state=="dash","dash state reaches the 3D rig")
	check(adapter.torso.rotation.x<-.2,"dash applies forward body lean")
	source.forced_clip="hurt";source.clip="hurt"
	adapter._process(.016)
	check(adapter.current_state=="hurt","hurt state reaches the 3D rig")
	source.forced_clip="death";source.clip="death";source.override_phase=.8;source.clip_time=.8;source.clip_length=1
	adapter._process(.016)
	check(adapter.current_state=="death","death state reaches the 3D rig")
	check(adapter.body_root.rotation.z>0.5,"death pose tips the full rig")

	print("THREED_V12_REGRESSION="+JSON.stringify({"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
