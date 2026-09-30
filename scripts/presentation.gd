extends RefCounted
## The same ID selects the portrait, weapon, label and accent everywhere.
const HEROES = preload("res://art/v5/heroes.png")
const ENEMIES = preload("res://art/v5/enemies-cute.png")
const LULU = preload("res://art/v5/lulu.png")
const BACKGROUND = preload("res://art/v5/menu.png")
const FLOORS = preload("res://art/v5/floors.png")
const ROLES = [
	{"id":0,"word":"御剑","name":"剑修","color":Color("#8ee4ce"),"tag":"剑意流转 · 贯穿与剑阵","front":Rect2(120,0,430,516),"back":Rect2(120,516,430,508)},
	{"id":1,"word":"火药","name":"火枪手","color":Color("#efb576"),"tag":"炼金重火力 · 爆破与装填","front":Rect2(610,0,360,516),"back":Rect2(610,516,360,508)},
	{"id":2,"word":"长弓","name":"游侠","color":Color("#a4dcd4"),"tag":"星月追猎 · 远射与连携","front":Rect2(1040,0,400,516),"back":Rect2(1040,516,400,508)}
]
const ENEMY_REGIONS = [Rect2(0,0,420,474),Rect2(420,0,360,474),Rect2(780,0,359,474),Rect2(1139,0,397,474),Rect2(0,477,412,547),Rect2(412,477,302,547),Rect2(714,477,425,547),Rect2(1139,477,397,547)]
const ENEMY_LOOKS = [0,1,2,3,6,7,3,6,7,4,5,4,6,7]
const QUALITY = [Color("#b0b9c4"),Color("#77b9f1"),Color("#c392ef"),Color("#f2c76e")]
static func gear_texture(role: int, slot: int) -> Texture2D:
	return load("res://art/v5/gear_%d_%d.svg"%[role,slot])
