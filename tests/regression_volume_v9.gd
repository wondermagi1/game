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
	var system=preload("res://scripts/material_fx.gd").new()
	for role in range(3):
		for path in ["res://art/v9/fx/sword-volume.png","res://art/v9/fx/gunner-volume.png","res://art/v9/fx/ranger-volume.png"]:
			var texture: Texture2D=load(path)
			check(texture.get_size().x>=1200 and texture.get_size().y>=1200,"volume texture has high-resolution source: "+path)
		system.bits.clear()
		system.emit("v8_gather",Vector2(300,300),Vector2.RIGHT,role,2.4,1.0)
		check(system.bits.any(func(bit):return bit.type=="volume" and int(bit.variant)==role),"role %d gather uses its volume core"%role)
		system.emit("v8_sustain",Vector2(300,300),Vector2.RIGHT,role,1.8,1.0)
		check(system.bits.filter(func(bit):return bit.type=="volume").size()>=2,"role %d sustain layers volume over gather"%role)
		system.emit("v8_finish",Vector2(300,300),Vector2.RIGHT,role,4.2,1.0)
		check(system.bits.any(func(bit):return bit.type=="volume" and int(bit.variant)==role and bit.size.x>=250),"role %d finish has large volume payoff"%role)
		check(system.bits.size()<=80,"role %d material budget remains bounded"%role)
		system.tick(.18)
		check(system.bits.all(func(bit):return bit.life>0 and bit.life<=bit.max),"role %d volume lifetime advances safely"%role)
	var report={"checks":checks,"failures":failures}
	var file=FileAccess.open("res://tests/regression_volume_v9_results.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"  "))
	print("VOLUME_V9_REGRESSION="+JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)
