extends SceneTree

var checks:=0
var failures:Array[String]=[]
var game

func _initialize()->void:call_deferred("run")
func check(value:bool,message:String)->void:
	checks+=1
	if not value:failures.append(message)
func frames(count:int)->void:
	for i in range(count):await process_frame

func run()->void:
	var Timeline=preload("res://scripts/skill_vfx_timeline.gd")
	check(Timeline.PHASES==["anticipation","release","sustain","impact","residue"],"five presentation phases are explicit")
	check(ResourceLoader.exists("res://art/v11/impact_distortion.gdshader"),"local distortion shader exists")
	check(ResourceLoader.exists("res://art/v11/radial_light.svg"),"radial light texture exists")
	game=load("res://scenes/Main.tscn").instantiate();game.test_mode=true;root.add_child(game);game.sound.volume=0
	game.profile.data.unlocked=6;game.effects_intensity=1.0
	for role in range(3):
		game.profile.data.checkpoint={};game.profile.data.exploration={}
		game.profile.data.roles[role].level=30;game.profile.data.roles[role].skills=[10,10,10,10]
		game.start_run(role,11100+role,role+1);game.pending.clear();game.player.manual_control=true;game.player.aim=Vector2.RIGHT
		var skills=game.player.skills
		check(skills.use(3),"role %d ultimate starts"%role)
		check(game.vfx_timeline.active.get("phase","")=="anticipation","role %d enters anticipation"%role)
		check(game.screen_fx.pulses.size()>0,"role %d anticipation has screen pulse"%role)
		skills.tick(.24)
		check(game.vfx_timeline.active.get("phase","")=="release","role %d enters release"%role)
		check(game.screen_fx.lights.size()<=5,"role %d dynamic lights stay capped"%role)
		game.vfx_timeline.sustain_ultimate(game.player.global_position+Vector2(180,0),Vector2.RIGHT,role,10)
		check(game.vfx_timeline.active.get("phase","")=="sustain","role %d enters sustain"%role)
		check(game.presentation_fx.materials.bits.size()<=80,"role %d textured particles stay capped"%role)
		skills.ultimate.finish()
		check(game.vfx_timeline.active.get("phase","")=="residue","role %d reaches residue"%role)
		check(game.ground_residue.residues.size()==1,"role %d creates one visual-only ground residue"%role)
		check(int(game.ground_residue.residues[0].role)==role,"role %d residue keeps role identity"%role)
		check(game.screen_fx.pulses.size()<=8,"role %d screen pulses stay capped"%role)
		game.clear_attacks();game.profile.data.exploration={};game.profile.data.checkpoint={}
	game.reduced_motion=true;game.effects_intensity=1.0
	game.screen_fx.impact(Vector2(960,540),0,4,true)
	check(not game.screen_fx.distortion.visible,"reduced motion disables distortion")
	game.screen_fx.clear();game.reduced_motion=false;game.effects_intensity=.3
	game.screen_fx.impact(Vector2(960,540),1,4,true)
	check(game.screen_fx.lights.is_empty(),"low effects quality disables dynamic lights")
	check(game.screen_fx.pulses.size()<=8,"low quality keeps bounded pulse feedback")
	check(game.screen_fx.light_pool.size()==5,"dynamic light pool owns five reusable nodes")
	for quality in [.3,.65,1.0]:
		game.effects_intensity=quality
		game.ground_residue.clear();game.ground_residue.add(Vector2(960,540),2,160)
		var expected_branches:=5 if quality<.5 else (8 if quality<.8 else 11)
		check(game.ground_residue.residues[0].branches.size()==expected_branches,"quality %.2f selects expected residue density"%quality)
		game.presentation_fx.clear();game.presentation_fx.emit("v11_finish",Vector2(960,540),Vector2.RIGHT,2,3)
		var expected_cap:=24 if quality<.5 else (48 if quality<.8 else 80)
		check(game.presentation_fx.materials.bits.size()<=expected_cap,"quality %.2f runs within the material cap"%quality)
	game.fx.clear();game.show_numbers=true
	game.fx.number(Vector2(960,540),999,Color.WHITE,true,.07)
	check(game.fx.texts.size()==1 and game.fx.texts[0].delay>0,"heavy damage number starts with a short delay")
	game.fx._process(.05)
	check(is_equal_approx(float(game.fx.texts[0].t),.75),"delayed damage number does not age before appearing")
	game.fx._process(.03);game.fx._process(.01)
	check(game.fx.texts[0].delay<=0 and game.fx.texts[0].t<.75,"delayed damage number appears and resumes normally")
	var result={"checks":checks,"failures":failures}
	var file=FileAccess.open("res://tests/regression_vfx_v11_results.json",FileAccess.WRITE);file.store_string(JSON.stringify(result,"\t"));file.close()
	print("VFX_V11_REGRESSION="+JSON.stringify(result))
	game.free();quit(0 if failures.is_empty() else 1)
