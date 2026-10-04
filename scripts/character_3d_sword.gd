@tool
extends Node2D
## First 2.5D player presentation. Gameplay stays in CharacterBody2D while a
## transparent SubViewport renders an articulated 3D sword hero.

const VIEWPORT_SIZE := Vector2i(384,384)
const ROLE_SWORD := 0

var state_source: Node
var role: int = ROLE_SWORD
var viewport: SubViewport
var camera: Camera3D
var model_root: Node3D
var body_root: Node3D
var hips: Node3D
var torso: Node3D
var head: Node3D
var arm_l: Node3D
var arm_r: Node3D
var forearm_l: Node3D
var forearm_r: Node3D
var leg_l: Node3D
var leg_r: Node3D
var shin_l: Node3D
var shin_r: Node3D
var weapon_pivot: Node3D
var weapon_tip: Marker3D
var portrait: Sprite2D
var target_yaw: float = 0.0
var local_clock: float = 0.0
var current_state: String = "ready"
var accent := Color("#8ee4ce")
var cloth := Color("#d9ebe6")
var dark := Color("#173743")
var metal := Color("#d9edf0")

func _ready() -> void:
	if viewport!=null:return
	build_viewport()
	build_character()
	apply_quality()

func set_enabled(value: bool) -> void:
	visible=value
	set_process(value)
	if viewport!=null:
		viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS if value else SubViewport.UPDATE_DISABLED

func build_viewport() -> void:
	viewport=SubViewport.new()
	viewport.name="SwordCharacterViewport"
	viewport.size=VIEWPORT_SIZE
	viewport.transparent_bg=true
	viewport.own_world_3d=true
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	viewport.render_target_clear_mode=SubViewport.CLEAR_MODE_ALWAYS
	viewport.msaa_3d=Viewport.MSAA_4X
	add_child(viewport)

	var world:=Node3D.new()
	world.name="CharacterWorld"
	viewport.add_child(world)
	model_root=Node3D.new()
	model_root.name="ModelRoot"
	world.add_child(model_root)

	var environment_node:=WorldEnvironment.new()
	var environment:=Environment.new()
	environment.background_mode=Environment.BG_COLOR
	environment.background_color=Color(0,0,0,0)
	environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color=Color("#bfe5e2")
	environment.ambient_light_energy=1.05
	environment_node.environment=environment
	world.add_child(environment_node)

	var key:=DirectionalLight3D.new()
	key.name="KeyLight"
	key.light_color=Color("#f4fbff")
	key.light_energy=1.45
	key.rotation_degrees=Vector3(-42,-28,0)
	key.shadow_enabled=true
	world.add_child(key)
	var rim:=OmniLight3D.new()
	rim.name="RimLight"
	rim.light_color=accent
	rim.light_energy=3.2
	rim.omni_range=5.0
	rim.position=Vector3(-2.0,2.5,1.8)
	world.add_child(rim)

	camera=Camera3D.new()
	camera.name="CharacterCamera"
	camera.projection=Camera3D.PROJECTION_ORTHOGONAL
	camera.size=3.45
	camera.position=Vector3(0,3.25,6.4)
	camera.look_at_from_position(camera.position,Vector3(0,1.12,0))
	camera.current=true
	world.add_child(camera)

	portrait=Sprite2D.new()
	portrait.name="RenderedCharacter"
	portrait.texture=viewport.get_texture()
	portrait.position=Vector2(0,-59)
	portrait.scale=Vector2.ONE*.48
	portrait.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR
	add_child(portrait)

func material(color: Color, metallic_value: float=0.0, emission: float=0.0) -> StandardMaterial3D:
	var result:=StandardMaterial3D.new()
	result.albedo_color=color
	result.roughness=.48 if metallic_value<=0 else .24
	result.metallic=metallic_value
	if emission>0:
		result.emission_enabled=true
		result.emission=color
		result.emission_energy_multiplier=emission
	return result

func pivot(parent: Node3D, node_name: String, at: Vector3) -> Node3D:
	var result:=Node3D.new()
	result.name=node_name
	result.position=at
	parent.add_child(result)
	return result

func mesh_part(parent: Node3D, node_name: String, mesh: PrimitiveMesh, color: Color, at:=Vector3.ZERO, rotation:=Vector3.ZERO, metallic_value: float=0.0, emission: float=0.0) -> MeshInstance3D:
	var result:=MeshInstance3D.new()
	result.name=node_name
	result.mesh=mesh
	result.material_override=material(color,metallic_value,emission)
	result.position=at
	result.rotation=rotation
	parent.add_child(result)
	return result

func capsule(radius: float, height: float) -> CapsuleMesh:
	var result:=CapsuleMesh.new();result.radius=radius;result.height=height;result.radial_segments=16;result.rings=8
	return result
func sphere(radius: float) -> SphereMesh:
	var result:=SphereMesh.new();result.radius=radius;result.height=radius*2;result.radial_segments=20;result.rings=10
	return result
func box(size: Vector3) -> BoxMesh:
	var result:=BoxMesh.new();result.size=size
	return result
func cylinder(top: float, bottom: float, height: float) -> CylinderMesh:
	var result:=CylinderMesh.new();result.top_radius=top;result.bottom_radius=bottom;result.height=height;result.radial_segments=20
	return result

func build_character() -> void:
	body_root=pivot(model_root,"CharacterRig",Vector3.ZERO)
	hips=pivot(body_root,"Bone_Hips",Vector3(0,.82,0))
	mesh_part(hips,"Waist",cylinder(.27,.34,.34),dark,Vector3(0,.05,0))
	mesh_part(hips,"Robe",cylinder(.30,.53,.88),cloth,Vector3(0,-.20,0))
	mesh_part(hips,"RobeAccent",cylinder(.315,.55,.10),accent,Vector3(0,-.60,0),Vector3.ZERO,0.15,.18)

	torso=pivot(hips,"Bone_Spine",Vector3(0,.50,0))
	mesh_part(torso,"Torso",cylinder(.31,.25,.68),cloth,Vector3(0,.22,0))
	mesh_part(torso,"ChestGuard",box(Vector3(.62,.20,.18)),dark,Vector3(0,.30,.17),Vector3(-.08,0,0))
	mesh_part(torso,"ChestLight",box(Vector3(.40,.055,.205)),accent,Vector3(0,.31,.20),Vector3(-.08,0,0),.15,.8)
	mesh_part(torso,"Cape",box(Vector3(.67,.78,.055)),dark,Vector3(0,.05,-.22),Vector3(.12,0,0))

	head=pivot(torso,"Bone_Head",Vector3(0,.78,0))
	mesh_part(head,"Face",sphere(.245),Color("#f2d3bd"),Vector3(0,.10,.02))
	mesh_part(head,"HairBack",sphere(.285),Color("#15262c"),Vector3(0,.14,-.07))
	mesh_part(head,"FaceMask",sphere(.225),Color("#f2d3bd"),Vector3(0,.075,.095))
	mesh_part(head,"HairCrown",capsule(.12,.50),Color("#17313a"),Vector3(0,.41,-.08),Vector3(0,0,.18))
	mesh_part(head,"HairPin",box(Vector3(.46,.035,.035)),accent,Vector3(.12,.30,.04),Vector3(0,0,-.18),.4,.45)

	arm_l=pivot(torso,"Bone_UpperArm_L",Vector3(-.36,.48,0))
	arm_r=pivot(torso,"Bone_UpperArm_R",Vector3(.36,.48,0))
	mesh_part(arm_l,"UpperArm_L",capsule(.105,.53),cloth,Vector3(0,-.23,0))
	mesh_part(arm_r,"UpperArm_R",capsule(.105,.53),cloth,Vector3(0,-.23,0))
	forearm_l=pivot(arm_l,"Bone_Forearm_L",Vector3(0,-.48,0))
	forearm_r=pivot(arm_r,"Bone_Forearm_R",Vector3(0,-.48,0))
	mesh_part(forearm_l,"Forearm_L",capsule(.09,.46),dark,Vector3(0,-.19,0))
	mesh_part(forearm_r,"Forearm_R",capsule(.09,.46),dark,Vector3(0,-.19,0))

	leg_l=pivot(hips,"Bone_Thigh_L",Vector3(-.19,-.25,0))
	leg_r=pivot(hips,"Bone_Thigh_R",Vector3(.19,-.25,0))
	mesh_part(leg_l,"Thigh_L",capsule(.13,.66),dark,Vector3(0,-.29,0))
	mesh_part(leg_r,"Thigh_R",capsule(.13,.66),dark,Vector3(0,-.29,0))
	shin_l=pivot(leg_l,"Bone_Shin_L",Vector3(0,-.59,0))
	shin_r=pivot(leg_r,"Bone_Shin_R",Vector3(0,-.59,0))
	mesh_part(shin_l,"Shin_L",capsule(.105,.59),Color("#274754"),Vector3(0,-.25,0))
	mesh_part(shin_r,"Shin_R",capsule(.105,.59),Color("#274754"),Vector3(0,-.25,0))
	mesh_part(shin_l,"Boot_L",box(Vector3(.20,.16,.39)),dark,Vector3(0,-.55,.10))
	mesh_part(shin_r,"Boot_R",box(Vector3(.20,.16,.39)),dark,Vector3(0,-.55,.10))

	weapon_pivot=pivot(forearm_r,"Bone_Weapon",Vector3(0,-.43,0))
	weapon_pivot.rotation=Vector3(0,0,-1.05)
	mesh_part(weapon_pivot,"Hilt",cylinder(.055,.055,.43),Color("#31434b"),Vector3(0,-.16,0),Vector3.ZERO,.75)
	mesh_part(weapon_pivot,"Guard",box(Vector3(.48,.06,.10)),Color("#d7b66d"),Vector3(0,-.37,0),Vector3.ZERO,.75,.12)
	mesh_part(weapon_pivot,"Blade",box(Vector3(.105,1.45,.055)),metal,Vector3(0,-1.10,0),Vector3.ZERO,.82,.20)
	mesh_part(weapon_pivot,"BladeCore",box(Vector3(.026,1.30,.064)),accent,Vector3(0,-1.08,.005),Vector3.ZERO,.30,1.6)
	weapon_tip=Marker3D.new();weapon_tip.name="WeaponTip";weapon_tip.position=Vector3(0,-1.85,0);weapon_pivot.add_child(weapon_tip)

	var shadow_mesh:=CylinderMesh.new();shadow_mesh.top_radius=.55;shadow_mesh.bottom_radius=.55;shadow_mesh.height=.012;shadow_mesh.radial_segments=32
	mesh_part(model_root,"GroundShadow",shadow_mesh,Color(0,0,0,.30),Vector3(0,.015,0))

func apply_quality() -> void:
	if state_source==null:return
	var quality_value: int=int(state_source.get("quality")) if "quality" in state_source else 0
	var colors=[Color("#8ee4ce"),Color("#82baff"),Color("#be8cff"),Color("#ffd36c")]
	accent=colors[clampi(quality_value,0,3)]

func source_clip() -> String:
	if state_source==null:return "ready"
	if state_source.has_method("active_clip"):return str(state_source.active_clip())
	return str(state_source.get("clip")) if "clip" in state_source else "ready"

func source_phase() -> float:
	if state_source==null:return fposmod(local_clock,1.0)
	if state_source.has_method("action_phase") and source_clip() not in ["ready","run_forward","run_back","strafe_left","strafe_right"]:
		return float(state_source.action_phase())
	if state_source.has_method("walk_phase"):return float(state_source.walk_phase())
	return fposmod(local_clock,1.0)

func reset_pose() -> void:
	body_root.position=Vector3.ZERO
	body_root.rotation=Vector3.ZERO
	hips.rotation=Vector3.ZERO
	torso.rotation=Vector3.ZERO
	head.rotation=Vector3.ZERO
	arm_l.rotation=Vector3(0,0,.08)
	arm_r.rotation=Vector3(0,0,-.08)
	forearm_l.rotation=Vector3.ZERO
	forearm_r.rotation=Vector3.ZERO
	leg_l.rotation=Vector3.ZERO
	leg_r.rotation=Vector3.ZERO
	shin_l.rotation=Vector3.ZERO
	shin_r.rotation=Vector3.ZERO
	weapon_pivot.rotation=Vector3(0,0,-1.05)

func apply_pose(state: String, phase: float, motion_strength: float) -> void:
	var facing_yaw:=body_root.rotation.y
	reset_pose()
	body_root.rotation.y=facing_yaw
	var wave:=sin(phase*TAU)
	var breath:=sin(local_clock*2.6)
	torso.rotation.z=breath*.012
	head.rotation.z=-breath*.009
	body_root.position.y=breath*.008
	if motion_strength>.06 and state.begins_with("run"):
		var stride:=wave*.55*motion_strength
		leg_l.rotation.x=stride;leg_r.rotation.x=-stride
		shin_l.rotation.x=maxf(0,-stride)*.72;shin_r.rotation.x=maxf(0,stride)*.72
		arm_l.rotation.x=-stride*.52;arm_r.rotation.x=stride*.38
		forearm_l.rotation.x=-.12;forearm_r.rotation.x=-.20
		body_root.position.y+=absf(wave)*.055*motion_strength
		torso.rotation.x=-.08*motion_strength
	elif state=="attack":
		var strike:=sin(clampf(phase,0,1)*PI)
		torso.rotation.y=-.28*strike
		torso.rotation.z=-.13*strike
		arm_r.rotation=Vector3(-1.15*strike,0,-.25-.60*strike)
		forearm_r.rotation.x=-.75*strike
		weapon_pivot.rotation.z=-1.05+1.62*strike
		arm_l.rotation.x=-.30*strike
	elif state.begins_with("skill") or state.begins_with("ultimate") or state=="combo":
		var charge:=sin(clampf(phase,0,1)*PI)
		torso.rotation.x=-.10*charge
		arm_r.rotation=Vector3(-1.25*charge,0,-.85*charge)
		forearm_r.rotation.x=-.55*charge
		weapon_pivot.rotation.z=-1.05+1.35*charge
		arm_l.rotation=Vector3(-.72*charge,0,.55*charge)
	elif state=="dash":
		torso.rotation.x=-.42
		body_root.rotation.z=-.10
		arm_l.rotation.x=.72;arm_r.rotation.x=-.82
		leg_l.rotation.x=-.72;leg_r.rotation.x=.46
	elif state=="hurt":
		body_root.rotation.z=sin(phase*PI)*.22
		torso.rotation.x=.18
	elif state=="victory":
		arm_r.rotation.x=-1.25
		weapon_pivot.rotation.z=.15
	elif state=="death":
		body_root.rotation.z=clampf(phase,0,1)*1.35
		body_root.position.y=-clampf(phase,0,1)*.18

func _process(delta: float) -> void:
	if viewport==null:_ready()
	if state_source==null:return
	local_clock+=delta
	current_state=source_clip()
	var aim_value: Vector2=state_source.get("aim") if "aim" in state_source else Vector2.RIGHT
	if aim_value.length_squared()>.001:
		target_yaw=PI*.5-aim_value.angle()
	var movement_value: Vector2=state_source.get("movement") if "movement" in state_source else Vector2.ZERO
	apply_pose(current_state,source_phase(),clampf(movement_value.length(),0,1))
	# Facing is continuous even when the current action pose is rebuilt.
	body_root.rotation.y=lerp_angle(body_root.rotation.y,target_yaw,1.0-exp(-delta*13.0))
	var source_alpha: float=state_source.modulate.a if state_source is CanvasItem else 1.0
	portrait.modulate=Color(1.18,1.18,1.18,source_alpha) if float(state_source.get("flash"))>0 else Color(1,1,1,source_alpha)

func muzzle_local() -> Vector2:
	if camera==null or weapon_tip==null:return Vector2(42,-62)
	var pixel:=camera.unproject_position(weapon_tip.global_position)
	return portrait.position+(pixel-Vector2(VIEWPORT_SIZE)*.5)*portrait.scale
