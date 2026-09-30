extends RefCounted
## Separate drop probability from conditional quality. Only boss MAIN drops count pity.
const C = preload("res://scripts/catalog.gd")
static func weights(tier: int, chapter: int) -> Array:
	if tier==3: return [0.0,0.0,35.0,65.0]
	if chapter>=5: return [[10.0,40.0,40.0,10.0],[0.0,25.0,50.0,25.0],[0.0,0.0,60.0,40.0]][tier]
	if chapter>=3: return [[35.0,45.0,18.0,2.0],[10.0,45.0,38.0,7.0],[0.0,20.0,65.0,15.0]][tier]
	return [[60.0,34.0,5.0,1.0],[20.0,60.0,18.0,2.0],[0.0,65.0,30.0,5.0]][tier]
static func roll(profile, tier: int, role: int, chapter: int, rng: RandomNumberGenerator) -> Dictionary:
	var pity_key = "%d_%d"%[role,chapter]
	var pity = int(profile.data.chapter_pity.get(pity_key,0))
	var forced = pity>=7 and tier<2
	if not forced and rng.randf()>=C.DROP_CHANCE[tier]:
		if tier<2:
			profile.data.chapter_pity[pity_key] = pity+1
			profile.dirty = true
		return {}
	var roll_value = rng.randf()*100
	var quality = 3
	var chances = weights(tier,chapter)
	for i in range(4):
		roll_value -= chances[i]
		if roll_value<=0:
			quality = i
			break
	if forced: quality = maxi(1,quality)
	if tier==2 and chapter>=5:
		if int(profile.data.legend_misses)>=3: quality = 3
		profile.data.legend_misses = 0 if quality==3 else int(profile.data.legend_misses)+1
		profile.dirty = true
	var owner = role if tier>=2 or rng.randf()<0.90 else (role+rng.randi_range(1,2))%3
	var level = mini(int(profile.data.roles[owner].level),int(C.CHAPTERS[chapter-1].level))
	var slot = 5 if tier==3 else ((chapter+role)%6 if tier>=2 or forced else rng.randi_range(0,5))
	var item = profile.make_item(owner,slot,quality,level,rng,tier==3)
	item.drop_source = "隐藏首领" if tier==3 else ("第%d章首领"%chapter if tier>=2 else ("章节保底" if forced else "普通掉落"))
	profile.data.chapter_pity[pity_key] = 0 if quality>=1 else pity+1
	profile.dirty = true
	return item
