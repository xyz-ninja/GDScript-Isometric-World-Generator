extends "res://scripts/entity.gd"

export var is_floor = false

var texture_x_offset_mul
var texture_y_offset_mul
# дополнительное значения для наложения разных текстур стен внутри одного здания
# значение означает смещение от изначальных значений
var texture_r_x_offset_params = {l = 0, r = 0, f = 0, b = 0}


var r # renderer
var game
var tile_size

var icons_node

var is_l_wall = false
var is_r_wall = false
var is_b_wall = false
var is_f_wall = false
var is_door = false

var is_wall_z_setup_end = false

var is_outside_floor = false

enum DIR {FRONT, BACK, LEFT, RIGHT}

var id
var dir
var map_pos

var tile_map_symbol = null

var is_selected = false
var is_path = false
var is_has_furniture = false

# если тайл находится с края комнаты, меняют соотв. переменную на true
var in_left_edge_of_room = false
var in_top_edge_of_room = false

var tile_center_pos = Vector2()

var need_opacity_hide = false
var fur_opacity_hide = false

var test_custom_color = null

var Connected = {
	data_pack = null,		# ХРАНИЛИЩЕ ДАННЫХ ДЛЯ ИССЛЕДОВАНИЯ
	plant = null, 			# ПРОИЗВОДСТВО, НАПРИМЕР ПР-ВО НАТУР ТРАВ
	local_storage = null, 	# ЛОКАЛЬНОЕ ХРАНИЛИЩЕ В ТАЙЛЕ (например тайл-склад)
	storage_tile = null, 	# ПРИКРЕПЛЕННЫЙ К ТАЙЛУ ДРУГОЙ ТАЙЛ С ХРАНИЛЕЩЕМ
	storage_of_tile = null 	# ТАЙЛ К КОТОРОМУ ПРИКРЕПЛЕННО ХРАНИЛИЩЕ
}

# обрабатывается в gui_system
class OntileIcons:
	var icons_node

	# иконка показывающее направление передвижения юнита
	var show = {
		attack_range = false,

		move_start = false,
		move_finish = false,
		move_to_left = false,
		move_to_right = false,
		move_to_up = false,
		move_to_down = false,
		# иконка атаки 
		attack_range = false
	}

	var move_range_block_n
	var move_icons_nodes = {
		start = null, finish = null,
		to_left = null, to_right = null, to_up = null, to_down = null
	}

	var attack_range_n

	func _init():
		pass

	func update():
		if icons_node:
			# ATTACK RANGE
			if show.attack_range:
				attack_range_n.show()
			else:
				attack_range_n.hide()

			# MOVEMENT DIRECTIONS
			move_range_block_n.show()

			if show.move_start:
				move_icons_nodes.start.show()
			else:
				move_icons_nodes.start.hide()
			if show.move_finish:
				move_icons_nodes.finish.show()
			else:
				move_icons_nodes.finish.hide()
			if show.move_to_left:
				move_icons_nodes.to_left.show()
			else:
				move_icons_nodes.to_left.hide()
			if show.move_to_right:
				move_icons_nodes.to_right.show()
			else:
				move_icons_nodes.to_right.hide()
			if show.move_to_up:
				move_icons_nodes.to_up.show()
			else:
				move_icons_nodes.to_up.hide()
			if show.move_to_down:
				move_icons_nodes.to_down.show()
			else:
				move_icons_nodes.to_down.hide()
			
			var show_move_range_block = false
			for n in move_icons_nodes.values():
				if n.is_visible():
					show_move_range_block = true
					break

			if show_move_range_block:
				move_range_block_n.show()
			else:
				move_range_block_n.hide()

	func set_icons_node(_icons_node):
		icons_node = _icons_node
		move_range_block_n = icons_node.get_node("move_range")
		move_icons_nodes.start = move_range_block_n.get_node("icon_start")
		move_icons_nodes.finish = move_range_block_n.get_node("icon_start")

		move_icons_nodes.to_left = move_range_block_n.get_node("icon_l")
		move_icons_nodes.to_right = move_range_block_n.get_node("icon_r")
		move_icons_nodes.to_up = move_range_block_n.get_node("icon_u")
		move_icons_nodes.to_down = move_range_block_n.get_node("icon_d")

		attack_range_n = icons_node.get_node("attack_range")
	
	func disable_all_icons():
		for k in show.keys():
			show[k] = false

	func disable_icon_by_key(_icon_key):
		if show.has(_icon_key):
			show[_icon_key] = false
		else:
			print("gui_system error! _icon_key not found!")

var contains_car

var faded_opacity = 0.15

# по окончанию этого таймера тайл показывается если он скрыт
var wall_opacity_show_timer = TIME.create_timer("wall_opacity_show_timer", 0.25) 

# временные переменные
var temp_visual_path

var click_addit_time = 0.1
var click_addit_timer = click_addit_time
var mouse_over_delayed_timer = 0.2

var is_mouse_over_tile = false # нужно для tile_storage_view

# ИКОНКИ ПЕРЕДВИЖЕНИЯ, АТАКИ И Т.Д. КЛАСС - OntileIcons
var ontile_icons = OntileIcons.new()

var tile_has_items_icon

var tile_storage_view  # просмотр local_storage тайла

var wall_opacity_params = {
	change_to_max = true, change_to_min = false,
	change_speed_mul = 2.1, 
	max_v = 1.0, min_v = 0.2
}

# уже взятые с тайла предметы которые больше не должны появляться
var taken_tile_items = []

var par_collider

func _ready():
	r = get_parent().get_parent()
	game = r.game
	tile_size = r.tile_size

	# СОЗДАНИЕ ИКОНОК
	if is_floor or is_outside_floor:
		icons_node = r.scn_tile_icons.instance()
		add_child(icons_node)
		icons_node.set_global_pos(get_global_pos())
		icons_node.set_z(get_z() + 150)

		ontile_icons.set_icons_node(icons_node)

	if has_node("tile_has_items_icon"):
		tile_has_items_icon = get_node("tile_has_items_icon")

	set_process(true)

func _process(delta):
	# SETUP OPACITY
	#if need_opacity_hide or fur_opacity_hide:
	#	set_opacity(0.2)
	#elif fur_opacity_hide:
	#	set_opacity(0.2)
	#else:
	
	# SETUP INPUT
	if !GUI.is_mouse_overlapping_buttons() and STATES.get_current_state() == STATES.NowOpened.main_menu and \
		r.game.check_current_room_id_equal(r.room_id) and r.is_active():
		
		if is_wall() or is_door():
			# НАСТРАИВАЕМ Z СТЕН
			if !is_wall_z_setup_end:
				var cur_z_data = r.get_z_data_by_map_pos_y(map_pos.y)
				var cur_z
				if is_f_wall:
					cur_z = cur_z_data.params.wall_f
				elif is_b_wall:
					cur_z = cur_z_data.params.wall_b
				elif is_l_wall or is_door():
					cur_z = cur_z_data.params.wall_l
				elif is_r_wall:
					cur_z = cur_z_data.params.wall_r
				
				set_z(cur_z)
				
				if has_node("non_bg"):
					# non bg
					get_node("non_bg").set_z(get_node("bg").get_z() - 2)
				#get_node("non_bg").set_z(cur_z - 1)

				is_wall_z_setup_end = true

			# ПЛАВНО МЕНЯЕТ ПРОЗРАЧНОСТЬ СТЕНЫ 
			var w_bg = get_node("bg")
			if wall_opacity_params.change_to_min:
				if w_bg.get_opacity() > wall_opacity_params.min_v:
					var d_o = w_bg.get_opacity()
					d_o -= wall_opacity_params.change_speed_mul * delta
					if d_o < wall_opacity_params.min_v + 0.2:
						show_non_wall_bg()
					if d_o < wall_opacity_params.min_v:
						d_o = wall_opacity_params.min_v
					w_bg.set_opacity(d_o)

			elif wall_opacity_params.change_to_max:
				if w_bg.get_opacity() < wall_opacity_params.max_v:
					var d_o = w_bg.get_opacity()
					d_o += wall_opacity_params.change_speed_mul * delta
					if d_o > wall_opacity_params.max_v:
						d_o = wall_opacity_params.max_v
					w_bg.set_opacity(d_o)

			# АВТОМАТИЧЕСКОЕ ПОЯВЛЕНИЕ СТЕН		
			if wall_opacity_show_timer.is_finish():
				if wall_opacity_params.change_to_min:
					wall_opacity_params.change_to_min = false
					wall_opacity_params.change_to_max = true
				hide_non_wall_bg()
		
		# ПОЛУЧИТЬ ЮНИТА НА ТАЙЛЕ
		var contains_unit = get_contains_unit() # ПОЛУЧАТЬ ЮНИТОВ
		# ПОЛУЧИТЬ МАШИНУ НА ТАЙЛЕ
		var contains_car = get_contains_car()

		if contains_unit != null:
			hide_around_tiles(SYS.ONTILE_OBJ_TYPE.UNIT)
		if is_has_furniture:
			hide_around_tiles(SYS.ONTILE_OBJ_TYPE.FUR)

		if is_floor():
			if tile_has_items_icon != null and weakref(tile_has_items_icon).get_ref():
				if get_tile_items().size() > 0:
					tile_has_items_icon.set_z(get_z() + 60)
					tile_has_items_icon.show()
				else:
					tile_has_items_icon.hide()

		#var corrected_mouse_pos = Vector2(
		#	get_global_mouse_pos().x - 10, get_global_mouse_pos().y - 60)

		# MOUSE OVER TILE
		if is_mouse_over():
			if is_floor:
				get_node("bg").set_modulate(Color(SYS.Colors.plum))
				hide_around_tiles(SYS.ONTILE_OBJ_TYPE.MOUSE_CURSOR)
				is_mouse_over_tile = true
			#else:
				#set_opacity(0.25)

			var selected_unit = r.get_selected_unit()

			# show car mouse tracker
			if contains_car != null:
				r.gui.infodesc_tracker.show_car_tab(contains_car.info)

			if get_tile_items().size() > 0:
				r.gui.infodesc_tracker.show_tile_loot_tab()

			# MOUSE CLICKED
			if is_mouse_clicked_and_ready():

				#print(id)
				#print(r.get_wall_by_map_pos(map_pos))
				#print(tile_map_symbol.all_layers_symbols)
				#print(get_map_pos())
				#print("tile z: " + str(get_z()))
				#if is_wall():
					#print("wall bg z:" + str(get_z()))
				#print(get_tms().WallBlockedWays)

				#print(is_furniture_blocked_all_ways())

				if in_top_edge_of_room:
					print("TOP EDGE")
				elif in_left_edge_of_room:
					print("LEFT EDGE")

				if contains_unit != null:
					r.select_unit(contains_unit)	
				else:
					#var test_around_circle_tiles = r.get_tiles_in_circle_sector_around_tile(self, 2)
					
					#for t in test_around_circle_tiles:
					#	t.test_custom_color = SYS.Colors.red

					r.select_tile(self)
				
				if is_floor:
					if tile_map_symbol == null:
						print("ERROR! TILE MAP SYMBOL OBJECT DIDNT FOUND!")
					else:
						#print(str(get_z()))

						var mt = r.gui.mouse_tracker				

						# IF NO UNIT IS SELECTED
						if selected_unit == null:
							# MOUSE TRACKER - SET FURNITURE
							if has_furniture_place() and !is_has_furniture:
								var hsi = mt.holding_storage_item
								if hsi != null:
									set_furniture(hsi.info)
									mt.clear()

							elif has_node("furniture") and is_has_furniture:
								# OPEN LOCAL STORAGE SB
								if get_node("furniture").info.is_storage:
									get_node("furniture").snap_ctx()

						# IF ROOM HAS SELECTED UNIT
						else:
							if is_has_furniture:
								# MOUSE TRACKER - SELECT STORAGE
								var fss = mt.furniture_storage_select
								if fss != null:
									if get_node("furniture").info.is_storage:
										fss.connect_storage_tile(self)
										mt.clear()
								else:
									# SHOW FURNITURE CTX MENU
									get_node("furniture").snap_ctx()
							else:
								# MOVE UNIT TO THIS TILE
								if contains_car == null:
									# FIND PATH BETWEEN TILES
									if !r.game.fight_system.is_active:
										move_selected_unit_to_this_tile()
									#pass

						# SNAP CTX CAR MENU
						if contains_car != null:
							GUI.ctx_menu.snap_to_node(self,
								GUI.CtxType.player_car, contains_car)

						#print("LEFT: " + str(tms2.AvailableWays.left))
						#print("RIGHT: " + str(tms2.AvailableWays.right))
						#print("BACK: " + str(tms2.AvailableWays.back))
						#print("FRONT: " + str(tms2.AvailableWays.front))
						#print(tms2.all_layers_symbols)
						##
						#var l_tile = r.get_tile_by_tms(tms2.NearestTiles.left)
						#var r_tile = r.get_tile_by_tms(tms2.NearestTiles.right)
						#var b_tile = r.get_tile_by_tms(tms2.NearestTiles.back)
						#var f_tile = r.get_tile_by_tms(tms2.NearestTiles.front)
						#if l_tile != null:
						#	l_tile.test_custom_color = SYS.Colors.gray
						#if r_tile != null:
						#	r_tile.test_custom_color = SYS.Colors.dark_gray
						#if b_tile != null:
						#	b_tile.test_custom_color = SYS.Colors.black
						#if f_tile != null:
						#	f_tile.test_custom_color = SYS.Colors.light_yellow
			elif is_mouse_rb_clicked_and_ready():
				if selected_unit == null:
					pass
				else:
					if Connected.local_storage != null or get_on_tile_corpses().size() > 0:
						if is_all_ways_blocked():
							selected_unit.move_to_random_nearby_tile_around_tile_with_action_code(self,
								"open_tile_storage_view")
						else:
							selected_unit.move_to_tile_with_action_code(self, "open_tile_storage_view")

			# FIGHT SYSTEM

			if r.game.fight_system.is_active:
				if is_floor and selected_unit != null and selected_unit.body.is_ready_to_new_actions():
					if click_addit_timer > 0:
						click_addit_timer -= delta

					# ON RMB CLICK
					if Input.is_action_pressed("mouse_right_click"):

						var cur_unit_tile 
						var move_fs_action = game.fight_system.get_fs_action_in_unit_info_param_with_tag(
							selected_unit.info, game.UNIT_ACTION_TAG.MOVE_TO_TILE)

						if move_fs_action == null:
							cur_unit_tile = selected_unit.get_current_tile()

						# если уже есть действия перемещения в fight_system
						# прокладываем путь с последнего тайла
						else:
							if move_fs_action.addit_params.gen_path.back() == self:
								print("ЮНИТ ПЫТАЕТСЯ ПОЙТИ НА ТОТ ЖЕ ТАЙЛ ЧТО И В ПРОШЛЫЙ РАЗ")
								return
							else:
								cur_unit_tile = move_fs_action.addit_params.gen_path.back() 

						# отображаем сгенерированный путь игроку
						var gen_path = r.get_path_between_tiles(get_tms(), cur_unit_tile.get_tms(), true)

						if temp_visual_path == null:
							temp_visual_path = GUI.visual_gen_paths.draw_path(gen_path)

						######r.show_icon_in_tiles([self], "def_cover_str")

						# в массив пути (gen_path) не входит начальный тайл
						var gen_ap_cost = game.fight_system.get_ap_count_for_unit_by_path(
							selected_unit.info, gen_path + [self])

						r.gui.infodesc_tracker.show_fight_mode_tab(
							"Переместить Персонажа", gen_ap_cost)

						#if has_node("icons"):
							#get_node("icons/def_status").show()
						#	show_icon("def_cover_str")

						# ON CLICK
						if Input.is_action_pressed("mouse_left_click") and click_addit_timer <= 0:
							move_selected_unit_to_this_tile()
							click_addit_timer = click_addit_time

							clear_temp_cache()
				else:
					# ПЕРЕМЕЩЕНИЕ В БОЮ
					if Input.is_action_pressed("mouse_left_click") and click_addit_timer <= 0:
						var cur_unit_tile 
						var move_fs_action = game.fight_system.get_fs_action_in_unit_info_param_with_tag(
							selected_unit.info, game.UNIT_ACTION_TAG.MOVE_TO_TILE)

						if move_fs_action == null:
							cur_unit_tile = selected_unit.get_current_tile()

						# если уже есть действия перемещения в fight_system
						# прокладываем путь с последнего тайла
						else:
							cur_unit_tile = move_fs_action.addit_params.gen_path.back() 

						# отображаем сгенерированный путь игроку
						var gen_path = r.get_path_between_tiles(get_tms(), cur_unit_tile.get_tms(), true)

						if temp_visual_path == null:
							temp_visual_path = GUI.visual_gen_paths.draw_path(gen_path)

						move_selected_unit_to_this_tile()
						click_addit_timer = click_addit_time

						clear_temp_cache()


		# MOUSE NOT OVER TILE
		else:
			clear_temp_cache()

			is_mouse_over_tile = false

			# debug colors
			if test_custom_color != null:
				get_node("bg").set_modulate(Color(test_custom_color))
			else:
				#if is_path and is_floor:
				#	#get_node("bg").set_modulate(Color(SYS.Colors.red))
				#	pass
				if r != null:
					if !is_selected:
						get_node("bg").set_modulate(SYS.Colors.OBJ_original)

func set_dir(e_dir):
	dir = e_dir
	
	var x_offset_mul = 0 # select region rect by e_dir
	
	if e_dir == SYS.ISOM_WALL_DIR.FRONT:
		x_offset_mul = 0 + texture_r_x_offset_params.f
	if e_dir == SYS.ISOM_WALL_DIR.BACK:
		x_offset_mul = 1 + texture_r_x_offset_params.b
	if e_dir == SYS.ISOM_WALL_DIR.LEFT:
		x_offset_mul = 2 + texture_r_x_offset_params.l
	if e_dir == SYS.ISOM_WALL_DIR.RIGHT:
		x_offset_mul = 3 + texture_r_x_offset_params.r

	update_texture(x_offset_mul, null)

	tile_center_pos = Vector2(get_global_pos().x + 23, get_global_pos().y + 77)

func update_texture(_x_mul, _y_mul, _extra_x_off = 0):
	if _x_mul != null:
		texture_x_offset_mul = _x_mul
	if _y_mul != null:
		texture_y_offset_mul = _y_mul

	if texture_x_offset_mul == null:
		texture_x_offset_mul = 0
	if texture_y_offset_mul == null:
		texture_y_offset_mul = 0

	get_node("bg").set_region_rect(Rect2(
		tile_size * texture_x_offset_mul, tile_size * texture_y_offset_mul,
		tile_size, tile_size
	))

func select(_need_select):
	if _need_select:
		is_selected = true
		get_node("bg").set_modulate(Color(SYS.Colors.red))
		
		#print(r.get_def_cover_str_in_tile(self))

		#if r.get_tile_g_room(self):
		#	print("TILE IN ROOM ID: " + str(r.get_tile_g_room(self).id))
	else:
		is_selected = false
		get_node("bg").set_modulate(SYS.Colors.OBJ_original)

func move_selected_unit_to_this_tile():
	var selected_unit_tile = r.get_selected_unit().get_astar_corrected_current_tile()

	var selected_unit = r.get_selected_unit()

	var unit_tms = selected_unit_tile.tile_map_symbol
	var cur_tms = tile_map_symbol

	var tile_path

	# temp_display_path_obj нужен для визуального отображения пути юнита
	if temp_visual_path == null:
		tile_path = r.get_path_between_tiles(unit_tms, cur_tms, true)
	else:
		# если зажата ПКМ юнит составит свой путь по заданной траектории 
		tile_path = [self]
		tile_path += temp_visual_path
		tile_path.invert()
		
	var ap_count = game.fight_system.get_ap_count_for_unit_by_path(selected_unit.info, tile_path)

	if r.game.fight_system.is_active:
		var is_action_added = r.game.fight_system.add_fs_unit_action(
			selected_unit.info, r.game.UNIT_ACTION_TAG.MOVE_TO_TILE, ap_count,
			{gen_path = tile_path})

		if is_action_added:
			GUI.visual_gen_paths.draw_path(tile_path)

	else:
		selected_unit.set_astar_move_path(tile_path)

	return tile_path

func show_around_tiles(_sys_ontile_obj_type):
	var obj_type = _sys_ontile_obj_type	

	var around_tiles = r.get_all_tiles_in_sector_around_tile(self, 50)
	for a_t in around_tiles:
		if obj_type == SYS.ONTILE_OBJ_TYPE.FUR:
			a_t.fur_opacity_hide = false

		elif obj_type == SYS.ONTILE_OBJ_TYPE.UNIT:
			a_t.need_opacity_hide = false

func hide_around_tiles(_sys_ontile_obj_type):
	var obj_type = _sys_ontile_obj_type	

	var around_tiles
	var cur_tms = tile_map_symbol

	if obj_type == SYS.ONTILE_OBJ_TYPE.MOUSE_CURSOR:
		around_tiles = r.get_all_tiles_in_sector_around_tile(self, 30)
	else:
		around_tiles = r.get_all_tiles_in_sector_around_tile(self, 60)

	for a_t in around_tiles:
		var a_t_tms = a_t.tile_map_symbol
		
		if a_t.is_wall() or a_t.is_door():
			if obj_type == SYS.ONTILE_OBJ_TYPE.MOUSE_CURSOR:
				a_t.hide_wall_tile()
			
			elif obj_type == SYS.ONTILE_OBJ_TYPE.FUR:
				# hide front/right walls
				if a_t.dir == DIR.FRONT or a_t.dir == DIR.RIGHT:
					a_t.hide_wall_tile()

				# if need hide left wall
				if cur_tms.WallBlockedWays.right and a_t_tms.all_layers_symbols.has(
					r.g.BLOCKS.WALL_L):
				
					a_t.hide_wall_tile()

			elif obj_type == SYS.ONTILE_OBJ_TYPE.UNIT:
				if cur_tms.WallBlockedWays.front:
					if a_t_tms.all_layers_symbols.has(r.g.BLOCKS.WALL_B) or \
						a_t_tms.all_layers_symbols.has(r.g.BLOCKS.WALL_F):

						a_t.hide_wall_tile()

				if cur_tms.WallBlockedWays.right:
					if a_t_tms.all_layers_symbols.has(r.g.BLOCKS.WALL_R):

						a_t.hide_wall_tile()

					elif cur_tms.all_layers_symbols.has(r.g.BLOCKS.WALL_R) and \
						a_t_tms.all_layers_symbols.has(r.g.BLOCKS.WALL_L):

						a_t.hide_wall_tile()

				if cur_tms.NearestTiles.left.all_layers_symbols.has(r.g.BLOCKS.WALL_B) or \
					cur_tms.NearestTiles.right.all_layers_symbols.has(r.g.BLOCKS.WALL_B):

						a_t.hide_wall_tile()

				# hide doors in tiles-sector anyway
				if a_t_tms.all_layers_symbols.has(r.g.BLOCKS.DOOR_OPENED):
					a_t.hide_wall_tile()

func disconnect_from_ways_web():
	var around_tiles = r.get_tiles_around_tile(self, true)

	for t in around_tiles:
		r.g.ways_web.remove_A_STAR_way_between_tiles(get_tms(), t.get_tms())

	r.render_debug_graphics()

func clear_temp_cache():
	# clear cache
	if temp_visual_path != null:
		GUI.visual_gen_paths.remove_path(temp_visual_path)
		temp_visual_path = null

# _is_large_blot - если нужно большое пятно крови
func spawn_blood(_is_large_blot = false, _is_death_animation = false): 
	var blood_blot = r.scn_blood.instance()
	var init_rect2 = Rect2(40,40,40,40)
	var spawn_pos = get_global_pos()

	var is_death_animation = _is_death_animation

	if is_death_animation:
		spawn_pos.x += 50
		spawn_pos.y += 55
	else:
		spawn_pos.x += 50
		spawn_pos.y += 45

		randomize()
		spawn_pos.x += randi() % 5 - 5
		spawn_pos.y += randi() % 5 - 5

	get_node("all_blood").add_child(blood_blot)
	blood_blot.set_z(get_parent().get_z())
	blood_blot.set_global_pos(spawn_pos)

	var x_rect_mul = 0
	var y_rect_mul = 0

	randomize()
	x_rect_mul = randi() % 4

	if is_floor or is_outside_floor:
		if is_death_animation:
			y_rect_mul = 2
		else:
			if _is_large_blot:
				y_rect_mul = 1
			else:
				y_rect_mul = 0
	else: # if its is wall
		x_rect_mul *= 2
		if _is_large_blot:
			y_rect_mul = 1
		else:
			y_rect_mul = 0

		blood_blot.is_on_wall = true

	#x_rect_mul = 1

	init_rect2.pos.x *= x_rect_mul
	init_rect2.pos.y *= y_rect_mul

	#test_custom_color = SYS.Colors.black

	blood_blot.get_node("tex").set_region_rect(init_rect2)
	blood_blot.start_fade_on(is_death_animation)

func spawn_bullet_hole():
	# spawn bullet hole
	var hole = r.scn_bullet_hole.instance()
	var init_rect2 = Rect2(15,0,15,15)
	var spawn_pos = get_global_pos()

	var x_rect_mul = 0

	if is_floor or is_outside_floor:
		x_rect_mul = 0

		spawn_pos.x += 50
		spawn_pos.y += 60

		spawn_pos.x += SYS.get_random_int(-15, 15)
		spawn_pos.y += SYS.get_random_int(-5, 5)

	else: # IF WALL
		randomize()
		x_rect_mul = randi() % 5 + 1

		spawn_pos.x += 30
		spawn_pos.y += 40

		spawn_pos.x += SYS.get_random_int(-25, 25)
		spawn_pos.y += SYS.get_random_int(-20, 20)
	
	add_child(hole)
	hole.set_z(get_parent().get_z())
	hole.set_global_pos(spawn_pos)

	init_rect2.pos.x *= x_rect_mul
	hole.get_node("tex").set_region_rect(init_rect2)

	# spawn particles
	var p = r.scn_part_bullet_hit.instance()
	add_child(p)
	p.set_z(get_parent().get_z()+ 2)
	p.set_global_pos(spawn_pos)

	if is_floor or is_outside_floor:
		pass
	else:
		p.set_rotd(180)

	p.set_autodestroy_and_emit_timer(0.25)

	return spawn_pos

func hide_wall_tile():
	if is_wall() or is_door():
		wall_opacity_params.change_to_min = true
		wall_opacity_params.change_to_max = false

		wall_opacity_show_timer.reload()

func show_non_wall_bg():
	if has_node("non_bg"):
		var x_offset = 0
		if is_l_wall or is_door() and dir == SYS.ISOM_WALL_DIR.LEFT:
			x_offset = 2
		elif is_r_wall or is_door() and dir == SYS.ISOM_WALL_DIR.RIGHT:
			x_offset = 3
		elif is_b_wall:
			x_offset = 1
		elif is_f_wall:
			x_offset = 0
		
		var non_bg = get_node("non_bg")
		var non_bg_rect = non_bg.get_region_rect()
		non_bg_rect.pos.x = 80 * x_offset
		non_bg.set_region_rect(non_bg_rect)
		#non_bg.set_z(get_z())
		non_bg.show()

func hide_non_wall_bg():
	if has_node("non_bg"):
		get_node("non_bg").hide()

# показать sb блок с содержимым local_storage тайла
func snap_tile_storage_view(_by_human):
	if tile_storage_view == null:
		tile_storage_view = r.scn_tile_storage_view.instance()
		add_child(tile_storage_view)
		tile_storage_view.anchor_to_tile(self, _by_human)

func set_furniture(_info):
	var f_info = _info

	if f_info.obj == ENV.FUR_OBJ.damage_scarecrow:
		r.spawn_unit(HUMANS.generate_random_human(10, HUMANS.HUMAN_TYPE.IDDQD_MAN, null), get_map_pos())
		return

	f_info.set_parent_tile(self)

	var furniture_n = get_node("furniture")
	
	furniture_n.show()
	furniture_n.setup_furniture(f_info)

	#r.tiles_with_furniture.append(self)

	is_has_furniture = true

	# ежемесячный убыток
	if f_info.price_in_month > 0:
		PLAYER.bank_account.add_month_less(f_info.price_in_month)

	# данные
	if f_info.has_data_pack:
		connect_data_pack()

	#disconnect_from_ways_web()

func set_contains_car(_car_node):
	contains_car = _car_node
	# удаляем все пути в тайле
	tile_map_symbol.remove_ways_in_all_dirs()
	#test_custom_color = SYS.Colors.red

func remove_contains_car():
	contains_car = null
	tile_map_symbol.return_init_ways()
	#test_custom_color = null

func get_contains_car():
	return contains_car
	#return r.get_car_with_current_tile(self)

func get_contains_unit():
	return r.get_unit_with_current_tile(self)

func get_tms():
	return tile_map_symbol

func get_map_pos():
	return map_pos

func get_furniture():
	if has_node("furniture") and is_has_furniture:
		return get_node("furniture")
	else:
		return null

func has_furniture_place():
	if is_floor and has_node("furniture") and r.get_unit_with_current_tile(self) == null:
		var f = get_node("furniture")
		if f.is_empty:
			return true
	return false

func get_contain_unit_z():
	return r.get_z_data_by_map_pos_y(map_pos.y).params.unit

func get_tile_items():
	var items = []
	if Connected.local_storage != null and Connected.local_storage.all.size() > 0:
		items += Connected.local_storage.all

	if get_on_tile_corpses().size() > 0:
		for corpse in get_on_tile_corpses():
			items += corpse.corpse_loot_items

	for taken_item in taken_tile_items:
		items.erase(taken_item)

	return items

# получает трупы на тайле
func get_on_tile_corpses():
	var cur_units = r.get_units_with_current_tile(self)
	var corpses = []
	for u in cur_units:
		if u.is_dead():
			corpses.append(u)
	return corpses

func is_floor(_include_outside_floor = true):
	if _include_outside_floor:
		if is_floor or is_outside_floor:
			return true
		else:
			return false
	else:
		if is_floor:
			return true
		else:
			return false

func is_wall():
	if is_l_wall or is_r_wall or is_f_wall or is_b_wall:
		return true
	else:
		return false

func is_door(): # возможно понадобится потом
	return is_door

func is_mouse_over():
	if SYS.get_dist_between_points(get_global_mouse_pos(), get_global_pos()) < 100:
		if par_collider != null:
			if par_collider.is_mouse_inside_parallelogram():
				return true
			else:
				return false
		else:
			return false
	else:
		return false

func is_all_ways_blocked():
	var tms = tile_map_symbol
	if tms.AvailableWays.left or tms.AvailableWays.right or \
		tms.AvailableWays.back or tms.AvailableWays.front:
		return false
	else:
		return true

func connect_storage_tile(_tile):
	var storage_tile = _tile

	Connected.storage_tile = storage_tile
	storage_tile.Connected.storage_of_tile = self

func disconnect_storage_tile():
	Connected.storage_tile.Connected.storage_of_tile = null
	Connected.storage_of_tile = null

func connect_local_storage(_storage_max_capacity):
	Connected.local_storage = PLAYER.Storage.new(self)
	Connected.local_storage.set_max_capacity(_storage_max_capacity)

	#PLAYER.add_item_to_storage(
	#	PLAYER.ITEM_TYPE.WEAPON, 
	#	HUMANS.get_new_weapon(HUMANS.WEAPON_TYPE.F_MAC_USI), 1, 
	#null, Connected.local_storage)

func connect_plant(_item_type, _addit_item_type = null):
	Connected.plant = PLAYER.add_plant(_item_type, _addit_item_type)

func connect_data_pack():
	Connected.data_pack = PLAYER.data_system.create_data_pack(get_furniture())
	Connected.data_pack.set_room(r.room)