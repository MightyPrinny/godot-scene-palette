tool
extends Container

export var spacing = 1

func _ready():
	connect("sort_children",self,"_sort")
	
func _sort():
	var count = get_child_count()
	var i = 0
	var child
	var max_width
	var max_height = 0
	var rect = get_rect()
	rect.grow(2)
	var child_rect
	var row_y = 0
	var column_x = 0
	var new_rect = get_rect()
	var first_in_row = true
	new_rect.size = Vector2(new_rect.size.x,0)
	while i < count:
		child = get_child(i)
		if child is Control:
			child.rect_position = Vector2(column_x,row_y)
			child_rect = child.get_rect()
			if (child_rect.position.x < rect.position.x || (child_rect.position.x + child_rect.size.x) > (rect.position.x + rect.size.x) ):
				row_y += max_height
				column_x = 0
				child.rect_position = Vector2(column_x,row_y)
				if max_height == 0:
					
					row_y += child_rect.size.y
				elif column_x > 0:
					max_height = 0
				elif child_rect.size.y > max_height:
					max_height = child_rect.size.y
				
			else:
				if child_rect.size.y > max_height:
					max_height = child_rect.size.y
					
			column_x += child_rect.size.x + spacing
			
			first_in_row = false
			new_rect = new_rect.merge(child.get_rect())
		i += 1
	rect_size = new_rect.size
	rect_min_size.y = new_rect.size.y
