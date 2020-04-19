tool
extends EditorPlugin

var palette_scene
var editor_interface:EditorInterface
var base_control:Control
var enabled_check_box
var panel_enabled = false
var panel_instance
var drawer:CanvasItem
var current_scene:Node
var last_tile = Vector2()
var drawing_tiles = false
var transformed_rect = PoolVector2Array()
var selected_node

func _enter_tree():
	transformed_rect.resize(4)
	palette_scene = load("res://addons/fabianlc_scene_palette/Scenes/UIScenePalette.tscn")
	editor_interface = get_editor_interface()
	base_control = editor_interface.get_base_control()
	enabled_check_box = CheckBox.new()
	enabled_check_box.text = "enable scene palette panel"
	enabled_check_box.pressed = false
	enabled_check_box.connect("toggled",self,"set_panel_enabled")
	add_control_to_container(EditorPlugin.CONTAINER_CANVAS_EDITOR_MENU,enabled_check_box)
	set_input_event_forwarding_always_enabled()

func _exit_tree():
	set_panel_enabled(false)
	if is_instance_valid(enabled_check_box):
		remove_control_from_container(EditorPlugin.CONTAINER_CANVAS_EDITOR_MENU, enabled_check_box)
		enabled_check_box.free()
	if is_instance_valid(drawer):
		drawer.free()
		drawer = null
	
func handles(obj):
	return true
	
func edit(obj):
	selected_node = obj
	
func make_visible(visible):
	if !visible:
		selected_node = null
	
func set_panel_enabled(value):
	if value:
		if !panel_enabled:
			panel_instance = palette_scene.instance()
			panel_instance.set_plugin_instance(self)
			add_control_to_container(EditorPlugin.CONTAINER_CANVAS_EDITOR_SIDE_LEFT,panel_instance)
			panel_enabled = true
	else:
		if is_instance_valid(panel_instance):
			remove_control_from_container(EditorPlugin.CONTAINER_CANVAS_EDITOR_SIDE_LEFT,panel_instance)
			panel_instance.queue_free()
			panel_instance = null
		panel_enabled = false
		if is_instance_valid(drawer):
			drawer.queue_free()
			drawer = null
			
func drawer_parent_exiting_tree(scene):
	if is_instance_valid(drawer):
		drawer.queue_free()
		drawer = null

func _process(delta):
	if !panel_enabled:
		return
	var scene = editor_interface.get_edited_scene_root()
	if !Input.is_mouse_button_pressed(BUTTON_LEFT):
		drawing_tiles = false
	if !is_instance_valid(drawer):
		if is_instance_valid(scene):
			drawer = Node2D.new()
			drawer.z_as_relative = false
			drawer.z_index = 100
			drawer.connect("draw",self,"_draw_overlay", [drawer])
			scene.add_child(drawer)
			drawer.global_position = Vector2()
			current_scene = scene
			if !scene.is_connected("tree_exiting",self,"drawer_parent_exiting_tree" ):
				scene.connect("tree_exiting",self,"drawer_parent_exiting_tree",[scene],CONNECT_ONESHOT)
			drawer.modulate = Color(1,1,1,0.35)
	else:
		drawer.update()
		

func _draw_overlay(obj:CanvasItem):
	obj.global_transform = Transform2D.IDENTITY
	if is_instance_valid(selected_node) && is_instance_valid(panel_instance) && is_instance_valid(panel_instance.selected_item):
		var rect = panel_instance.selected_item.get_meta("ognode_rect")
		var tr = panel_instance.palette_transform
		var og_pos = panel_instance.selected_item.get_meta("ognode_initial_pos")
		var gpos =  panel_instance.snap_pos(tr.xform(og_pos-rect.size*0.5) + obj.get_global_mouse_position())
		
		transformed_rect[0] = gpos + tr.xform(rect.position)
		transformed_rect[1] = gpos + tr.xform(rect.position + Vector2(rect.size.x,0))
		transformed_rect[2] = gpos + tr.xform(rect.position + rect.size)
		transformed_rect[3] = gpos + tr.xform(rect.position + Vector2(0,rect.size.y))
		obj.draw_colored_polygon(transformed_rect,Color.cyan)
		

var last_instance_made

func make_instance(source_node, position, parent,undo_stuff):
	if !is_instance_valid(source_node) || !is_instance_valid(parent):
		last_instance_made = null
		return
	var new_instance = source_node.duplicate(DUPLICATE_USE_INSTANCING)
	parent.add_child(new_instance)
	new_instance.owner = current_scene
	var tr:Transform2D = panel_instance.palette_transform
	if new_instance is Node2D:
		new_instance.scale = panel_instance.palette_scale
		new_instance.rotation_degrees = panel_instance.palette_rotation
		new_instance.global_position = position
	elif new_instance is Control:
		new_instance.rect_scale = panel_instance.palette_scale
		new_instance.rect_rotation = deg2rad(panel_instance.palette_rotation)
		new_instance.rect_global_position = position
	last_instance_made = new_instance
	undo_stuff[1] = [new_instance]
	
#hack to add undo info after commiting the action
var do_stuff = [] setget set_do_stuff
func set_do_stuff(value):
	do_stuff = value
	var func_ref = do_stuff[0] as FuncRef
	func_ref.call_funcv(do_stuff[1])
	
func undo_make_instance(instance):
	if is_instance_valid(instance):
		instance.queue_free()

func forward_canvas_gui_input(event):
	if !is_instance_valid(panel_instance) || !is_instance_valid(panel_instance.selected_item):
		return false
		
	var make_instance = false
	if event is InputEventMouse && is_instance_valid(drawer) && is_instance_valid(current_scene):
		var rect = panel_instance.selected_item.get_meta("ognode_rect")
		var og_pos = panel_instance.selected_item.get_meta("ognode_initial_pos")
		var tr = panel_instance.palette_transform
		var instance_pos = panel_instance.snap_pos(tr.xform(og_pos-rect.size*0.5) + drawer.get_global_mouse_position())
		if event is InputEventMouseButton && event.button_index == BUTTON_LEFT:
			if event.pressed:
				make_instance = true
				if panel_instance.is_snap_enabled():
					drawing_tiles = true
			else:
				drawing_tiles = false
		elif drawing_tiles && panel_instance.is_snap_enabled() && event is InputEventMouseMotion:
			if instance_pos != last_tile:
				make_instance = true
		
		if make_instance:
			var undo_redo = get_undo_redo()
			undo_redo.create_action("Instance from palette")
			#we can use funcrefs to pass undo information after committing the action
			var undo_args = []
			var prev_do_stuff = [funcref(self, "undo_make_instance"),undo_args]
			do_stuff = prev_do_stuff
			var new_do_stuff_func = funcref(self,"make_instance")
			var target_node = current_scene
			if panel_instance.to_selection && is_instance_valid(selected_node):
				target_node = selected_node
			var new_do_stuff = [new_do_stuff_func,[panel_instance.selected_item.get_child(0), instance_pos, target_node,prev_do_stuff]]
			undo_redo.add_do_property(self,"do_stuff",new_do_stuff)
			undo_redo.add_undo_property(self,"do_stuff",prev_do_stuff)
			last_instance_made = null
			undo_redo.commit_action()
			
			if panel_instance.is_snap_enabled():
				last_tile = instance_pos
			return true
