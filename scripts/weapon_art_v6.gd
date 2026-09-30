extends RefCounted
## Original source pixels are retained. Regions separate six independently painted props.
const TEXTURE = preload("res://art/v6/weapons.png")
const REGIONS = [Rect2(20,226,567,229),Rect2(601,227,576,168),Rect2(1235,3,182,596),Rect2(4,646,600,204),Rect2(610,678,514,166),Rect2(1139,713,391,83)]
static func draw(canvas: CanvasItem, index: int, length: float, col: Color = Color.WHITE) -> void:
	var r: Rect2=REGIONS[index]
	var h=length*r.size.y/r.size.x
	# Blade centerline differs from alpha bounds because the ordinary sword has a tassel.
	var center=.30 if index==0 else (.25 if index==1 else .5)
	canvas.draw_texture_rect_region(TEXTURE,Rect2(-length*.5,-h*center,length,h),r,col)
