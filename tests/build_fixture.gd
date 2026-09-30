extends RefCounted
## Explicit test builds use the real equip/train services, never boosted combat stats.
static func configure(game, chapter: int, role: int, build: String = "recommended") -> Dictionary:
	game.profile.fresh()
	game.rng.seed = 44100+chapter*10+role
	game.profile.data.unlocked = 6
	var developed = build=="developed" and chapter>=4
	var level: int = ([20,35,45][chapter-4] if developed else [1,5,10,15,22,30][chapter-1])
	var pieces: int = [0,2,4,6,6,6][chapter-1]
	if build=="low" and chapter>=5: level = 20; pieces = 4
	game.profile.data.roles[role].level = level
	if chapter>1:
		for slot in range(pieces):
			var gear = game.profile.make_item(role,slot,3 if developed and chapter>=5 else (1 if build=="low" else (2 if developed or chapter>=5 else 1)),mini(level,[1,5,10,15,22,30][chapter-1]),game.rng)
			gear.enhance = (10 if chapter>=5 else 5) if developed else (3 if build=="low" else [0,1,2,3,5,7][chapter-1])
			game.profile.receive_item(gear)
			game.profile.equip(role,gear.uid)
	if build!="untrained":
		var passives: Dictionary = {}
		if developed and chapter>=5:
			for n in range(7): game.profile.train_skill(role,0)
			for slot in [1,2]:
				for n in range(2): game.profile.train_skill(role,slot)
			game.profile.train_skill(role,3)
			passives = {"power":3,"guard":3,"vital":3,"flow":3}
		elif developed:
			game.profile.train_skill(role,0)
			game.profile.train_skill(role,0)
			game.profile.train_skill(role,1)
			game.profile.train_skill(role,2)
			passives = {"power":3,"focus":3,"flow":3,"guard":1}
		elif chapter>=5:
			for n in range(2 if chapter==5 else 4): game.profile.train_skill(role,0)
			for slot in [1,2,3]: game.profile.train_skill(role,slot)
			passives = {"power":3,"guard":3,"vital":3,"flow":3}
		elif chapter==4:
			game.profile.train_skill(role,0)
			game.profile.train_skill(role,1)
			passives = {"power":3,"guard":3,"vital":2,"flow":2}
		elif chapter==3:
			game.profile.train_skill(role,0)
			passives = {"power":3,"guard":2,"vital":2}
		elif chapter==2:
			passives = {"power":2,"guard":1,"vital":1}
		for id in passives:
			for n in range(passives[id]): game.profile.train(role,id)
	return {"build":build,"fixture_level":level,"fixture_set_pieces":pieces,"fixture_quality":"starter" if chapter==1 else ("legendary" if developed and chapter>=5 else ("rare" if build=="low" else ("epic" if developed or chapter>=5 else "rare"))),"fixture_enhance":((10 if chapter>=5 else 5) if developed else (3 if build=="low" else [0,1,2,3,5,7][chapter-1])),"fixture_talent_points":game.profile.data.roles[role].spent,"fixture_skill_ranks":game.profile.data.roles[role].skills.duplicate()}
