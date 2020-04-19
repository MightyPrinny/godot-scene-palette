tool
extends Control

onready var instance_parent = $VBoxContainer/ScrollContainer/Instances
onready var tool_bar = $VBoxContainer/ToolBar
onready var grid_snap_box = $VBoxContainer/ToolBar/CGSnap/GridSnap
onready var grid_width_spin = $VBoxContainer/ToolBar/CGWidth/GridWidth
onready var grid_height_spin = $VBoxContainer/ToolBar/CGHeight/GridHeight
onready var zoom_slider = $VBoxContainer/ToolBar/CZoom/Zoom
onready var rotation_spin = $VBoxContainer/ToolBar/CRot/Rotation
onready var flip_box_h = $VBoxContainer/ToolBar/CFlipH/FlipH
onready var flip_box_v = $VBoxContainer/ToolBar/CFlipV/FlipV
onready var to_selection_box = $VBoxContainer/ToolBar/CSelectedNode/ToSelection

var minimum_item_rect = Vector2(16,16)

var item_just_pressed = false
var file_menu_popup:PopupMenu

var file_dialog_open = false

var selected_item = null
var plugin_instance = null
var palette_transform = Transform2D()
var palette_rotation = 0
var palette_scale = Vector2(1,1)
var flip_x_tr = Transform2D()
var flip_y_tr = Transform2D()
var to_selection = false

func set_plugin_instance(var obj):
	plugin_instance = obj

enum {
	OpenFile
}

var file_popup_menu_position
var file_button:ToolButton


func _ready():
	if !is_instance_valid(plugin_instance):
		return
	flip_x_tr = flip_x_tr.scaled(Vector2(-1,1))
	flip_y_tr = flip_y_tr.scaled(Vector2(1,-1))
	file_button = tool_bar.get_node("File")
	file_menu_popup = tool_bar.get_node("File/PopupMenu")
	file_popup_menu_position = file_menu_popup.rect_position
	file_menu_popup.connect("id_pressed",self, "_file_menu_id_pressed")
	file_menu_popup.add_item("Open File", OpenFile)
	tool_bar.get_node("File").connect("pressed",self,"open_file_popup_menu")
	instance_parent.connect("draw",self,"_draw_selection")
	zoom_slider.connect("value_changed",self,"set_zoom")
	rotation_spin.connect("value_changed",self, "set_rotation")
	flip_box_h.connect("toggled",self,"set_flip_x")
	flip_box_v.connect("toggled",self,"set_flip_y")
	to_selection_box.connect("toggled",self,"set_to_selection")
	
func is_snap_enabled():
	return grid_snap_box.pressed
	
func _draw_selection():
	if is_instance_valid(selected_item):
		instance_parent.draw_rect(selected_item.get_rect(),Color.white, false, 1.5)

func open_file_popup_menu():
	file_menu_popup.popup()
	file_menu_popup.rect_global_position = file_button.rect_global_position + Vector2(0,32)

func _file_menu_id_pressed(id):
	match id:
		OpenFile:
			_open_file_dialog()

func set_to_selection(value):
	to_selection = value

func set_flip_x(value):
	if value:
		if palette_scale.x > 0:
			palette_scale *= Vector2(-1,1)
	else:
		if palette_scale.x < 0:
			palette_scale *= Vector2(-1,1)
	palette_transform = Transform2D.IDENTITY.scaled(palette_scale).rotated(deg2rad(palette_rotation))
	
func set_flip_y(value):
	if value:
		if palette_scale.y > 0:
			palette_scale *= Vector2(1,-1)
	else:
		if palette_scale.y < 0:
			palette_scale *= Vector2(1,-1)
	palette_transform = Transform2D.IDENTITY.scaled(palette_scale).rotated(deg2rad(palette_rotation))
	
func set_rotation(value):
	palette_rotation = value
	palette_transform = Transform2D.IDENTITY.scaled(palette_scale).rotated(deg2rad(palette_rotation))

func set_zoom(var zoom):
	var child_count = instance_parent.get_child_count()
	if child_count == 0:
		return
	var i = 0
	var child
	var instance
	var item_rect
	var initial_pos
	while i < child_count:
		child = instance_parent.get_child(i)
		instance = child.get_child(0)
		initial_pos = child.get_meta("ognode_initial_pos")
		item_rect = child.get_meta("ognode_rect")
		child.rect_min_size = item_rect.size*zoom
		child.rect_size = child.rect_min_size
		if instance is Node2D:
			instance.scale = Vector2(zoom,zoom)
			instance.position = initial_pos*zoom
		elif instance is Control:
			instance.rect_scale = Vector2(zoom,zoom)
			instance.rect_position = initial_pos*zoom
		i += 1
	
func _open_file_dialog():
	if file_dialog_open || !is_instance_valid(plugin_instance):
		return
	var popup = EditorFileDialog.new()
	popup.access = EditorFileDialog.ACCESS_RESOURCES
	popup.mode = EditorFileDialog.MODE_OPEN_FILE
	popup.add_filter("*.tscn")
	popup.add_filter("*.scn")
	popup.add_filter("*.tres")
	popup.connect("popup_hide",self,"popup_closed",[popup])
	popup.connect("file_selected",self,"_file_selected",[popup])
	plugin_instance.base_control.add_child(popup)
	file_dialog_open = true
	popup.popup_centered_ratio()
	
func popup_closed(dialog):
	file_dialog_open = false
	dialog.queue_free()
	dialog = null
	print("file dialog closed")

func _file_selected(file,dialog):
	var scene = load(file) as PackedScene
	if scene != null:
		populate_palette(scene)

func rect_union(rect1,rect2):
	var left = min(rect1.position.x,rect2.position.x)
	var top = min(rect1.position.y,rect2.position.y)
	var right = max(rect1.position.x + rect1.size.x, rect2.position.x + rect2.size.x)
	var bottom = max(rect1.position.y + rect1.size.y, rect2.position.y + rect2.size.y)

	return Rect2(left,top,right-left,bottom-top)

func local_rect_to_global(canvas_item:CanvasItem, rect:Rect2):
	var tr = canvas_item.get_global_transform()
	var p0 = tr.xform(rect.position)
	var p1 = tr.xform(rect.position + rect.size*Vector2(1,0))
	var p2 = tr.xform(rect.position + rect.size*Vector2(0,1))
	var p3 = tr.xform(rect.position + rect.size)
	
	var left = min(min(min(p0.x,p1.x),p2.x),p3.x)
	var top = min(min(min(p0.y,p1.y),p2.y),p3.y)
	var right = max(max(max(p0.x,p1.x),p2.x),p3.x)
	var bottom = max(max(max(p0.y,p1.y),p2.y),p3.y)
	return Rect2(left,top,right-left,bottom-top)
	
func snap_pos(vec:Vector2):
	if !grid_snap_box.pressed:
		return vec
	return Vector2(round(vec.x/grid_width_spin.value)*grid_width_spin.value, round(vec.y/grid_height_spin.value)*grid_height_spin.value)

func transform_rect(tr:Transform2D, rect:Rect2):
	
	var p0 = tr.xform(rect.position)
	var p1 = tr.xform(rect.position + rect.size*Vector2(1,0))
	var p2 = tr.xform(rect.position + rect.size*Vector2(0,1))
	var p3 = tr.xform(rect.position + rect.size)
	
	var left = min(min(min(p0.x,p1.x),p2.x),p3.x)
	var top = min(min(min(p0.y,p1.y),p2.y),p3.y)
	var right = max(max(max(p0.x,p1.x),p2.x),p3.x)
	var bottom = max(max(max(p0.y,p1.y),p2.y),p3.y)
	return Rect2(left,top,right-left,bottom-top)

func make_node(original_node:CanvasItem):
	if original_node is Node2D:
		original_node.transform = Transform2D.IDENTITY
	elif original_node is Control:
		original_node.rect_position = Vector2()
		original_node.rect_scale = Vector2(1,1)
		original_node.rect_rotation = 0
		
	var item_rect = Rect2(- minimum_item_rect*0.5, minimum_item_rect)
	var child_count = original_node.get_child_count()
	var i = 0
	
	var root = original_node
	original_node.get_transform().origin = Vector2()
	var node_roots = [original_node]
	var child
	var affine_inv = original_node.get_global_transform().affine_inverse()
	var has_rect = false
	while !node_roots.empty():
		root = node_roots.pop_back()
		child_count = root.get_child_count()
		i = 0
		while i < child_count:
			child = root.get_child(i)
			node_roots.append(child)
			if child is Control || child is Sprite:
				var rect = local_rect_to_global(child,child.get_rect())
				var local_rect = Rect2(affine_inv.xform(rect.position),affine_inv.basis_xform(rect.size))
				if has_rect:
					item_rect = rect_union(item_rect, local_rect)
				else:
					item_rect = local_rect
					has_rect = true
				
			i += 1
	print(item_rect)
	var node_center = item_rect.position + item_rect.size*0.5
	original_node.get_parent().remove_child(original_node)
	var newNode = Control.new()
	original_node.set_meta("local_rect_center",node_center)
	original_node.set_meta("local_rect",item_rect)
	newNode.set_meta("ognode",original_node)
	newNode.set_meta("ognode_rect",item_rect)
	newNode.set_meta("ognode_center",node_center)
	newNode.size_flags_vertical =  SIZE_SHRINK_END | SIZE_FILL
	newNode.size_flags_horizontal =  SIZE_SHRINK_END | SIZE_FILL
	newNode.name = "UI" + original_node.name
	newNode.rect_min_size = item_rect.size
	newNode.rect_size = item_rect.size
	newNode.rect_position = Vector2()
	newNode.add_child(original_node)
	
	newNode.mouse_filter = Control.MOUSE_FILTER_STOP
	var new_center = newNode.rect_position + newNode.rect_size*0.5
	
	if original_node is Node2D:
		original_node.position = new_center - (node_center)
		newNode.set_meta("ognode_initial_pos", original_node.position)
	elif original_node is Control:
		original_node.rect_position = new_center - (node_center)
		newNode.set_meta("ognode_initial_pos", original_node.rect_position)
	
	return newNode

func populate_palette(scene:PackedScene, clear_palette = true):
	if !is_instance_valid(plugin_instance):
		return
	if clear_palette:
		for child in instance_parent.get_children():
			child.free()
		selected_item = null
	var instance = scene.instance()
	if !instance is Node2D:
		instance.queue_free()
		return
	instance = instance as Node2D
	
	plugin_instance.editor_interface.add_child(instance)
	instance.force_update_transform()
	#instance_parent.rect_size = Vector2(1,1)
	
	var children = instance.get_children()
	var child_count = children.size()
	var i = 0
	while i<child_count:
		var child = children[i] as CanvasItem
		if is_instance_valid(child):
			var new_node = make_node(child) as Control
			new_node.set_process_input(true)
			new_node.connect("gui_input", self, "palette_item_gui_input", [new_node])
			instance_parent.add_child(new_node)
		i += 1
	
	instance.queue_free()
	set_zoom(zoom_slider.value)
	
func palette_item_clicked(item:Control):
	selected_item = item
	instance_parent.update()
	print("item clicked: " + item.name)
	
func palette_item_gui_input(event:InputEvent, item:Control):
	if event is InputEventMouseButton:
		if !item_just_pressed && event.pressed:
			item.accept_event()
			item_just_pressed = true
			palette_item_clicked(item)
			
func _process(delta):
	if item_just_pressed:
		item_just_pressed = false


