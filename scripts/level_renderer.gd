extends Node2D

# TILES
var scn_outside_plate = preload("res://rpg/tiles/level_outside_plate.tscn")
var scn_floor_plate = preload("res://rpg/tiles/level_plate.tscn")
var scn_wall = preload("res://rpg/tiles/level_wall.tscn")
var scn_door = preload("res://rpg/tiles/level_door.tscn")
var scn_tile_icons = load("res://rpg/tiles/plate_icons.tscn")

# TILE ADDIT
var scn_tile_storage_view = load("res://gui/tile_storage_view.tscn")

# ENV EFFECTS
var scn_blood = load("res://environment/blood_floor.tscn")
var scn_bullet_hole = load("res://environment/bullet_hole.tscn")
var scn_part_bullet_hit = load("res://particles/part_bullet_hit_solid.tscn")

# CARS
var scn_car = preload("res://rpg/iso_car.tscn")

# UNITS
var scn_human = preload("res://rpg/rpg_human.tscn")

onready var game = get_tree().get_nodes_in_group("game")[0]
onready var gui = get_tree().get_nodes_in_group("gui")[0]

onready var g = null # generator object
onready var generator = null # generator file

onready var draw_en = get_node("draw_engine")
onready var ctx_node = get_node("context_menu")
onready var tile_storage_view = get_node("tile_storage_view")

var room = null
var room_id = null

var iso_x_off = 0  # isometric x offset
var iso_x_mul = 18.5 # isometric x offset multiplier 18.5

# расстояние между тайлами по x и y
var dist_between_tiles = Vector2()

var global_iso_off_x = 0.62
var global_iso_off_y = 0.23

var loop_pos = Vector2(0,0) # same as map pos

var tile_size = 80

var tiles = []
var cars = []
var units = []
var walls = []

var map_rendered = false

# FOR SETUP CAMERA LIMITS
var start_cam_pos = null
var exemplary_width = 0
var exemplary_height = 0
var ex_start_x = 0
var ex_start_y = 0
var ex_final_x = 0
var ex_final_y = 0

# TEST PARAMETRES
var DebugParams = {
	is_debug_enable = false,
	need_draw_way_paths = true
}

enum ISO_OBJ_TYPE {TILE_PLATE, TILE_WALL, UNIT, CAR}

#var tiles_with_furniture = []

# содержит z координаты для определенных объектов
class Z_Data:
	var r
	var prev_z_data  # z_data из прошлой итерации цикла
	var map_pos_y

	# заполняются в зависимости от init_z из for цикла в analyze_map()
	var params = {
		init_z = 1,

		tile = 1,
		unit = 10,
		fur_l = 11, fur_b = 11, fur_r = 23, fur_f = 23,
		wall_l = 10, wall_b = 10, wall_r = 26, wall_f = 26
	}

	# 1 + 0 = 1; max : 4/5/6 [максимальное значение из параметров прибавляется к params.tile]
	# 1 + (prev_max) = 5; max: 4 + 5 = 9/10/11
	# 1 + (prev_max) = 10; max: 10 + 5 = 15/16/17
	# вроде формула правильная!

	func _init(_r, _map_pos_y):
		r = _r
		map_pos_y = _map_pos_y

		if _map_pos_y > 0:
			prev_z_data = r.z_datas[map_pos_y - 1]

			for p_k in params.keys():
				params[p_k] += prev_z_data.get_max_z_val()
			
	func get_max_z_val():
		var max_v = 0
		for p_v in params.values():
			if p_v > max_v:
				max_v = p_v
		return max_v + 1

var z_datas = []
var is_z_datas_filled = false

func _ready():
	set_process(false)

func _process(delta):
	pass

func render():
	clear_renderer()

	# GENERATE OUTSIDE
	analyze_map(g.maps_layers.map_outside)

	# ANALYZE OBJECTS
	analyze_map(g.maps_layers.map_floor)
	analyze_map(g.maps_layers.map)
	analyze_map(g.maps_layers.map_units)

	# DISPLAY WALLS
	parallel_analyze_maps(g.maps_layers.map_walls_v, g.maps_layers.map_walls_h)
	
	# save init ways in tms of all tiles
	for t in tiles:
		t.get_tms().save_init_ways()

	if DebugParams.is_debug_enable:
		render_debug_graphics()

	if start_cam_pos == null:
		start_cam_pos = Vector2(50, 50)

	get_parent().get_node("cam").set_global_pos(start_cam_pos)

	if PLAYER.PARAMS.HIDE_F_R_WALLS:
		for w in walls:
			if w.is_f_wall or w.is_r_wall:
				w.hide()

	# setup dist between tiles
	# назначаем дистанцию между тайлами сравнивая самый первый с нижним и правом тайлом для x и y соответственно
	var main_tile = get_tile_by_map_pos(init_map_pos)
	var r_tile = get_tile_by_map_pos(Vector2(init_map_pos.x + 1, init_map_pos.y))
	var d_tile = get_tile_by_map_pos(Vector2(init_map_pos.x, init_map_pos.y + 1))
	
	dist_between_tiles.x = SYS.get_dist_between_points_in_detail(
		main_tile.get_global_pos(), r_tile.get_global_pos()).horizontal
	dist_between_tiles.y = SYS.get_dist_between_points_in_detail(
		main_tile.get_global_pos(), d_tile.get_global_pos()).vertical

	map_rendered = true

func render_debug_graphics():
	draw_en.clear_graphics()

	# DRAW WAY PATHS
	if DebugParams.need_draw_way_paths:
		for way_path in g.ways_web.way_paths:
			var t1 = get_tile_by_map_pos(way_path.from_tile.map_pos)
			var t2 = get_tile_by_map_pos(way_path.to_tile.map_pos)

			var draw_t_offset = Vector2(20,-20)
			draw_en.paint_line(
				t1.tile_center_pos + draw_t_offset,
				t2.tile_center_pos + draw_t_offset, 
				SYS.Colors.green, false)

# clear some important variables
func clear_info():
	iso_x_off = 0
	loop_pos.x = 0
	loop_pos.y = 0

func clear_renderer():
	for tile in tiles:
		tile.queue_free()
	tiles.clear()

#func setup_tiles_pos(_map):

func analyze_map(_map):
	clear_info()

	if g != null:
		if _map.size() > 0:
			for row in _map:
				loop_pos.x = 0

				if !is_z_datas_filled:
					z_datas.append(Z_Data.new(self, loop_pos.y))

				for col in row:
					if (col != g.BLOCKS.WALL_R and
						col != g.BLOCKS.WALL_L and
						col != g.BLOCKS.WALL_F and
						col != g.BLOCKS.WALL_B):
							
						analyze_obj(col)

					loop_pos.x += 1

				iso_x_off += iso_x_mul
				
				loop_pos.y += 1

			is_z_datas_filled = true
		else:
			print("ERROR! MAP NOT GENERATED!")
	else:
		print("ERROR! GENERATOR NOT FOUND!")

func parallel_analyze_maps(_map1, _map2):
	var m1 = _map1
	var m2 = _map2
	if m1.size() == m2.size() and m1.size() != 0:
		clear_info()

		var current_line = 0
		var line_change_counter = 0

		for i in range(m1.size() * 2):

			line_change_counter += 1

			loop_pos.x = 0

			var current_map
			if i % 2 == 0:
				current_map = m1
			else:
				if m2 == null:
					return
				else:
					current_map = m2
				
			for col in current_map[int(i / 2)]:
				analyze_obj(col)
				loop_pos.x += 1
			# this means that cycle finished analyze line in both arrays
			if line_change_counter == 2:
				current_line += 1
				iso_x_off += iso_x_mul
				loop_pos.y += 1	

				line_change_counter = 0
	else:
		print("ERROR! MAPS HAVE DIFFERENT SIZE")

var prev_dir = null

# map pos начинает координатную ось не с 0 а с других значений например x:3 y:5
# эти переменные запоминают их
var init_map_pos = Vector2(-1, -1)

func analyze_obj(_symbol):
	# ANALYZE ALL SYMBOL LAYERS
	var symbol = _symbol

	# ISOMETRIC FLOOR, OUTSIDE AND WALLS
	if symbol == g.BLOCKS.NONE:
		pass

	# OUTSIDE FLOOR
	elif symbol == g.BLOCKS.OUTSIDE_FLOOR_PLATE:
		var o = spawn_obj(SYS.ISOM_WALL_DIR.FRONT, scn_outside_plate, ISO_OBJ_TYPE.TILE_PLATE)
		o.is_outside_floor = true
		setup_tile_textures_by_room_type(o, false, false, symbol)

	elif symbol == g.BLOCKS.OUTSIDE_FLOOR_PLATE_ROAD:
		var o = spawn_obj(SYS.ISOM_WALL_DIR.BACK, scn_outside_plate, ISO_OBJ_TYPE.TILE_PLATE)
		o.is_outside_floor = true
		setup_tile_textures_by_room_type(o, false, false, symbol)

	# WALLS
	elif symbol == g.BLOCKS.WALL_L:
		var o = spawn_obj(SYS.ISOM_WALL_DIR.LEFT, scn_wall, ISO_OBJ_TYPE.TILE_WALL)
		walls.append(o)
		setup_tile_textures_by_room_type(o, true)
		o.is_l_wall = true

	elif symbol == g.BLOCKS.WALL_R:
		var o = spawn_obj(SYS.ISOM_WALL_DIR.RIGHT, scn_wall, ISO_OBJ_TYPE.TILE_WALL)
		setup_tile_textures_by_room_type(o, true)
		o.is_r_wall = true

		walls.append(o)
		var r_t_tms = o.tile_map_symbol.NearestTiles.right
		if r_t_tms.all_layers_symbols.has(g.BLOCKS.WALL_L):
			o.hide()

	elif symbol == g.BLOCKS.WALL_B:
		var o = spawn_obj(SYS.ISOM_WALL_DIR.BACK, scn_wall, ISO_OBJ_TYPE.TILE_WALL)
		setup_tile_textures_by_room_type(o, true)
		o.is_b_wall = true
		walls.append(o)

	elif symbol == g.BLOCKS.WALL_F:
		var o = spawn_obj(SYS.ISOM_WALL_DIR.FRONT, scn_wall, ISO_OBJ_TYPE.TILE_WALL)
		setup_tile_textures_by_room_type(o, true)
		o.is_f_wall = true
		walls.append(o)

	# FLOOR
	elif symbol == g.BLOCKS.FLOOR_PLATE:
		var o = spawn_obj(SYS.ISOM_WALL_DIR.FRONT, scn_floor_plate, ISO_OBJ_TYPE.TILE_PLATE)
		setup_tile_textures_by_room_type(o)

	# DOORS
	elif symbol == g.BLOCKS.DOOR_OPENED:
		var o 
		var dir = g.get_dir_by_pos_in_wall(loop_pos)
		
		if dir == null:
			o = spawn_obj(SYS.ISOM_WALL_DIR.BACK, scn_door)
			print(str(loop_pos) + " DIR IN WALL NOT FOUND!")
		else:
			o = spawn_obj(dir, scn_door)
		setup_tile_textures_by_room_type(o, false, true)
		o.is_door = true

		if start_cam_pos == null:
			start_cam_pos = o.get_global_pos()
			
	# BASIC FURNITURE
	elif symbol == g.BLOCKS.RFO_BARMAN_TABLE:
		get_tile_by_map_pos(loop_pos).set_furniture(
			ENV.Furnitures.get_furniture_info_by_obj(ENV.FUR_OBJ.barman_table))
	
	elif symbol == g.BLOCKS.RFO_OLD_PARAPET:
		get_tile_by_map_pos(loop_pos).set_furniture(
			ENV.Furnitures.get_furniture_info_by_obj(ENV.FUR_OBJ.old_parapet))
	
	# BASIC UNITS
	elif symbol == g.BLOCKS.UNIT_PLAYER:
		var u = room.add_human(HUMANS.generate_random_human(
			SYS.get_random_int(8,10), HUMANS.HUMAN_TYPE.PLAYER_UNIT, HUMANS.HUMAN_ADDIT_TYPE.BANDIT), loop_pos)

	elif symbol == g.BLOCKS.UNIT_POLICE:
		var u = room.add_human(HUMANS.get_basic_policeman(), loop_pos)
	
	elif symbol == g.BLOCKS.UNIT_BAND_PATRIOTS:
		var u = room.add_human(HUMANS.generate_random_human(
			SYS.get_random_int(1, 6), HUMANS.HUMAN_TYPE.ENEMY_BAND_UNIT, HUMANS.HUMAN_ADDIT_TYPE.BAND_PATRIOTS_MEMBER), loop_pos)

	# BASIC CAR
	
	#elif symbol == g.BLOCKS.CAR_PARKING:
	#	spawn_obj(null, scn_car, ISO_OBJ_TYPE.CAR)

func spawn_obj(dir,scn, _custom_iso_obj_type = null, _custom_info = null):

	#var prev_tile = get_tile_by_map_pos(loop_pos)
	#if prev_tile != null:
	#	tiles.erase(prev_tile)

	var custom_o_type = _custom_iso_obj_type
	var custom_info = _custom_info

	var obj = scn.instance()

	var cur_obj_arr

	var custom_map_pos

	if custom_o_type == ISO_OBJ_TYPE.CAR:
		get_node("cars").add_child(obj)
		cur_obj_arr = cars

		var car_p_tile = get_available_car_parking_tile()

		if car_p_tile == null:
			print("NO AVAILABLE PARKING PLACE!!!")
			obj.queue_free()
			return
		else:
			custom_map_pos = car_p_tile.get_tms().map_pos

		var car_info
		if custom_info == null:
			car_info = ENV.Cars.add_player_car_model(0)
		else:
			car_info = custom_info
			
		obj.set_info(car_info)
		
	elif custom_o_type == ISO_OBJ_TYPE.TILE_WALL:
		get_node("tiles").add_child(obj)
		cur_obj_arr = walls
	else:
		get_node("tiles").add_child(obj)
		cur_obj_arr = tiles

	var ts = obj.tile_size

	if custom_map_pos == null:
		obj.map_pos = Vector2(loop_pos.x, loop_pos.y)
	else:
		obj.map_pos = custom_map_pos

	# запоминаем изначальную map pos
	if cur_obj_arr == tiles:
		if init_map_pos.x == -1 and init_map_pos.y == -1:
			init_map_pos = obj.map_pos
			obj.in_left_edge_of_room = true
			obj.in_top_edge_of_room = true
		else:
			if obj.map_pos.x == init_map_pos.x:
				obj.in_left_edge_of_room = true
			elif obj.map_pos.y == init_map_pos.y:
				obj.in_top_edge_of_room = true

	var obj_pos = get_obj_pos_with_iso_off(ts, custom_map_pos)

	if custom_o_type == ISO_OBJ_TYPE.CAR:
		var parent_tile = get_tile_by_map_pos(obj.map_pos)
		obj.set_current_tile(parent_tile)
	else:
		obj.set_global_pos(obj_pos)

		#obj.set_z(obj_pos.y)
		var z_data = get_z_data_by_map_pos_y(obj.map_pos.y)
		if z_data == null:
			print("wtf y pos: " + str(obj.map_pos.y))
			obj.set_z(0)
		else:
			obj.set_z(z_data.params.init_z)

	obj.tile_map_symbol = g.get_tile_map_symbol_by_pos(obj.map_pos)

	if dir != null:
		prev_dir = dir
		obj.set_dir(dir)

		# calculating exemplary size
		# setting start position
		if ex_start_x == 0:
			ex_start_x = obj_pos.x
		if ex_start_y == 0:
			ex_start_y = obj_pos.y
		# setting final coords

		if ex_final_y < obj_pos.y:
			ex_final_y = obj_pos.y

	cur_obj_arr.append(obj)

	return obj

# SPAWN UNIT IN GENERATION PROCESS 
func spawn_unit(_info, _custom_map_pos = null):
	var info = _info
	info.cur_room = room
	var c_m_pos = _custom_map_pos

	var type = info.type
	var scn = scn_human

	var obj = scn.instance()
	get_node("units").add_child(obj)
	
	# SET UNIT POSITION 
	var ts = 80

	var obj_pos = get_obj_pos_with_iso_off(ts, _custom_map_pos)

	obj.set_global_pos(obj_pos)
	
	obj.set_z(obj_pos.y)
	obj.set_z(get_z_data_by_map_pos_y(_custom_map_pos.y).params.unit)

	# SET PARENT TILE
	var parent_tile
	
	if c_m_pos == null:
		parent_tile = get_nearest_tile_to_unit(obj)
	else:
		parent_tile = get_tile_by_map_pos(c_m_pos)

	obj.init_info(info)

	obj.set_current_tile(parent_tile)
	obj.teleport_to_tile(parent_tile)

	#obj.set_global_pos(parent_tile.tile_center_pos)
	#get_parent().set_cam_pos(obj.get_global_pos())

	units.append(obj)

	return obj

# CHANGE TEXTURE OF TILES BY ROOM TYPE
func setup_tile_textures_by_room_type(_obj, _is_wall = false, _is_door = false, _g_block = null):
	var o = _obj

	# у каждого типа объекта в рендерере свои текстуры
	var wall_y_offset_mul
	var door_y_offset_mul	
	var floor_x_offset_mul
	var floor_y_offset_mul

	var g_block = _g_block # g block (symbol)

	# в некоторых уровнях текстуры стен в разных комнатах тоже разные
	# они смещаются на некоторое число от изначального mul-значения
	# (например: 3 кадр + смещение 2 = 5 кадр с другой внутренней текстурой)
	var r_x_offset_params = {l = 0, r = 0, f = 0, b = 0}

	var cur_g_room = g.get_room_by_pos(o.map_pos, true)

	if g.type == g.TYPES.P_HOLDING_GARAGE:
		wall_y_offset_mul = 4
		door_y_offset_mul = 5
		floor_y_offset_mul = 2
		
	elif g.type == g.TYPES.P_HOLDING_GYM:
		wall_y_offset_mul = 6
		door_y_offset_mul = 7
		floor_y_offset_mul = 3

	elif g.type == g.TYPES.P_HOLDING_SMALL_CLINIC:
		wall_y_offset_mul = 3
		door_y_offset_mul = 9
		
		if cur_g_room != null and cur_g_room.mode == g.ROOM_MODE.FIRST:
			r_x_offset_params.l = 3
			r_x_offset_params.b = 3
			floor_y_offset_mul = 3
		else:
			floor_x_offset_mul = 1
			floor_y_offset_mul = 3
		#	r_x_offset = 0

	elif g.type == g.TYPES.P_HOLDING_BAR:
		wall_y_offset_mul = 8
		door_y_offset_mul = 7
		floor_y_offset_mul = 4
		
	# SETUP OUTSIDE TEXTURES
	if o.is_outside_floor:
		if g_block == g.BLOCKS.OUTSIDE_FLOOR_PLATE:
			floor_x_offset_mul = 0
			floor_y_offset_mul = 1
		elif g_block == g.BLOCKS.OUTSIDE_FLOOR_PLATE_ROAD:
			floor_x_offset_mul = 1
			floor_y_offset_mul = 1

	# если есть смещение текстуры для другой комнаты
	if _is_wall or o.is_outside_floor:
		var is_have_r_x_offset = false
		for dir_off in r_x_offset_params.values():
			if dir_off != 0:
				is_have_r_x_offset = true
				break

		# перенастраиваем тайл по dir с этими параметрами (они проверяются в set_dir())
		if is_have_r_x_offset:
			o.texture_r_x_offset_params.l = r_x_offset_params.l
			o.texture_r_x_offset_params.r = r_x_offset_params.r
			o.texture_r_x_offset_params.b = r_x_offset_params.b
			o.texture_r_x_offset_params.f = r_x_offset_params.f

			o.set_dir(o.dir)

	var x_mul
	var y_mul

	if o.is_floor or o.is_outside_floor:
		if floor_x_offset_mul == null:
			x_mul = 0
		else:
			x_mul = floor_x_offset_mul
		y_mul = floor_y_offset_mul
	elif _is_wall:
		y_mul = wall_y_offset_mul
	elif _is_door:
		y_mul = door_y_offset_mul

	o.update_texture(x_mul, y_mul)

# MOVE UNIT FROM TILE <start> TO TILE <finish>
func move_unit_between_tiles(_unit, _start_tile, _finish_tile):
	var u = _unit
	var start_t_tms = _start_tile.tile_map_symbol
	var finish_t_tms = _finish_tile.tile_map_symbol

	var gen_path_corrected = get_path_between_tiles(
		start_t_tms, finish_t_tms, true)

	u.set_astar_move_path(gen_path_corrected)
	# отображение пути
	u.set_visual_move_path(gen_path_corrected)

	u.astar_start_tile = _start_tile
	u.astar_finish_tile = _finish_tile

# MOVE UNIT FROM HIS CURRENT TILE TO TILE <target>
func move_unit_to_tile(_unit, _target_tile):
	move_unit_between_tiles(_unit, _unit.get_astar_corrected_current_tile(), _target_tile)

func select_tile(_obj_tile):
	for t in tiles:
		t.select(false)

	_obj_tile.select(true)

func select_unit(_obj_unit):
	# deselect_all_units() это не нужно

	var u = _obj_unit
		
	u.select()

func deselect_all_units():
	for u in units:
		u.is_selected = false

func check_is_unit_inner_room(_unit, _tile):
	var u = _unit
	var t = _tile

	var cur_room = null

	for room in g.rooms:
		if g.is_pos_inside_room(t.tile_map_symbol.map_pos, room):
			cur_room = room

	if cur_room == null:
		return false
	else:
		var in_tiles = get_all_tiles_in_room(cur_room)

func set_generator(_g):
	g = _g

func get_obj_pos_with_iso_off(_tile_size, _custom_map_pos = null):
	var ts = _tile_size
	var c_m_pos =  _custom_map_pos

	var obj_pos = Vector2()	

	if c_m_pos == null:
		obj_pos.x = ts * global_iso_off_x * loop_pos.x - iso_x_off # 0.68
		obj_pos.y = ts * (loop_pos.y * global_iso_off_y) # 0.25
	else:
		obj_pos.x = ts * global_iso_off_x * c_m_pos.x - iso_x_off # 0.68
		obj_pos.y = ts * (c_m_pos.y * global_iso_off_y) # 0.25

	return obj_pos

# tms - tile map symbol
# is_corrected_result - true means that result path would contain only node-tiles
func get_path_between_tiles(_tms1, _tms2, _is_corrected_result = false):
	var tms1 = _tms1
	var tms2 = _tms2

	var is_corrected_result = _is_corrected_result

	var path = g.ways_web.get_A_STAR_path_between_tiles(tms1, tms2)
	if path != null:
		var result_path = []
	
		for t in tiles:
			if t.is_path:
				t.is_path = false
	
		for t in tiles:
			for path_tile_id in path:
				if t.tile_map_symbol.id == path_tile_id and t.is_floor:
					t.is_path = true
	
		if is_corrected_result:
			for path_tile_id in path:
				for t in tiles:
					if t.tile_map_symbol.id == path_tile_id and t.is_floor:
						result_path.append(t)
		else:
			result_path = path
	
		return result_path
	else:
		return null

func get_all_tiles_in_room(_room):
	var inner_tiles = []

	var positions_inner = _room.get_all_positions_inner_room(g)
	for pos in positions_inner:
		var t = get_tile_by_map_pos(pos)
		inner_tiles.append(t)
		#t.test_custom_color = SYS.Colors.gray

	return inner_tiles		

func get_nearest_tile_to_unit(_unit):
	var min_dist = 300
	var min_t = null

	for t in tiles:
		var cur_dist = SYS.get_dist_between_points(
			t.get_global_pos(), _unit.get_global_pos())
		
		if cur_dist < min_dist or min_t == null:
			min_t = t
			min_dist = cur_dist

	return min_t

func get_selected_unit():
	#for unit in units:
	#	if unit.is_selected:
	#		return unit
	#print("Fsdfsdf")
	return PLAYER.get_selected_human_in_current_room()

func get_selected_tile():
	for t in tiles:
		if t.is_selected:
			return t
	return null

func get_dirs_from_tile_to_tile(_from_tile, _other_tile):
	var cur_tile = _from_tile
	var other_tile = _other_tile

	var h_dir_to_other_tile # с какой стороны находится другой тайл по горизонтали 
	var v_dir_to_other_tile # с какой стороны находится другой тайл по вертикали
	var h_dir_from_other_tile_to_cur
	var v_dir_from_other_tile_to_cur

	if other_tile.get_map_pos().x < cur_tile.get_map_pos().x:
		h_dir_to_other_tile = SYS.DIR.LEFT
		h_dir_from_other_tile_to_cur = SYS.DIR.RIGHT
	else:
		h_dir_to_other_tile = SYS.DIR.RIGHT
		h_dir_from_other_tile_to_cur = SYS.DIR.LEFT

	if other_tile.get_map_pos().y < cur_tile.get_map_pos().y:
		v_dir_to_other_tile = SYS.DIR.UP
		v_dir_from_other_tile_to_cur = SYS.DIR.DOWN
	else:
		v_dir_to_other_tile = SYS.DIR.DOWN
		v_dir_from_other_tile_to_cur = SYS.DIR.UP
	
	return {
		h_dir_to_other_tile = h_dir_to_other_tile, h_dir_from_other_tile_to_cur = h_dir_from_other_tile_to_cur,
		v_dir_to_other_tile = v_dir_to_other_tile, v_dir_from_other_tile_to_cur = v_dir_from_other_tile_to_cur
	}

func get_def_cover_str_in_tile(_t):
	var t = _t
	var t_tms = t.tile_map_symbol

	var def_cov_str = {up = null, down = null, left = null, right = null}

	# nullify prev def_cov_str values
	for k in def_cov_str.keys():
		def_cov_str[k] = null

	# ПРОВЕРЯЕМ FURNITURE СОСЕДНИХ ТАЙЛОВ
	# back
	if t_tms.NearestTiles.back != null:
		var near_t = get_tile_by_tms(t_tms.NearestTiles.back)
		if near_t.is_has_furniture and near_t.get_node("furniture").closed_dirs.front:
			def_cov_str.up = near_t.get_node("furniture").info.def_cov_str
	# front		
	if t_tms.NearestTiles.front != null:
		var near_t = get_tile_by_tms(t_tms.NearestTiles.front)
		if near_t.is_has_furniture and near_t.get_node("furniture").closed_dirs.back:
			def_cov_str.down = near_t.get_node("furniture").info.def_cov_str
	# left
	if t_tms.NearestTiles.left != null:
		var near_t = get_tile_by_tms(t_tms.NearestTiles.left)
		if near_t.is_has_furniture and near_t.get_node("furniture").closed_dirs.right:
			def_cov_str.left = near_t.get_node("furniture").info.def_cov_str
	# right
	if t_tms.NearestTiles.right != null:
		var near_t = get_tile_by_tms(t_tms.NearestTiles.right)
		if near_t.is_has_furniture and near_t.get_node("furniture").closed_dirs.left:
			def_cov_str.right = near_t.get_node("furniture").info.def_cov_str

	# ПРОВЕРЯЕМ FURNITURE В ТЕКУЩЕМ ТАЙЛЕ
	if t.is_has_furniture:
		var t_fur = t.get_node("furniture")

		if t_fur.closed_dirs.back:
			def_cov_str.up = t_fur.info.def_cov_str
		if t_fur.closed_dirs.front:
			def_cov_str.down = t_fur.info.def_cov_str
		if t_fur.closed_dirs.left:
			def_cov_str.left = t_fur.info.def_cov_str
		if t_fur.closed_dirs.right:
			def_cov_str.right = t_fur.info.def_cov_str

	# ПРОВЕРЯЕМ СТЕНЫ
	if t_tms.WallBlockedWays.back:
		def_cov_str.up = ENV.DEFENCE_COVER_STRENGTH.HIGH_WALL
	if t_tms.WallBlockedWays.front:
		def_cov_str.down = ENV.DEFENCE_COVER_STRENGTH.HIGH_WALL
	if t_tms.WallBlockedWays.left:
		def_cov_str.left = ENV.DEFENCE_COVER_STRENGTH.HIGH_WALL
	if t_tms.WallBlockedWays.right:
		def_cov_str.right = ENV.DEFENCE_COVER_STRENGTH.HIGH_WALL

	return {left = def_cov_str.left, right = def_cov_str.right, up = def_cov_str.up, down = def_cov_str.down}

# получает тайлы между которыми есть путь A*
func get_tile_not_blocked_nearest_tiles(_tile_tms, _with_self = false, _with_walls = false):
	var cur_t_tms = _tile_tms

	var not_blocked_tiles = []
	var not_blocked_tiles_tms = []

	if cur_t_tms.AvailableWays.left:
		not_blocked_tiles_tms.append(cur_t_tms.NearestTiles.left)
	if cur_t_tms.AvailableWays.right:
		not_blocked_tiles_tms.append(cur_t_tms.NearestTiles.right)
	
	var back_wall = get_wall_by_tms_map_pos(cur_t_tms.NearestTiles.back.map_pos)
	if cur_t_tms.AvailableWays.back:
		not_blocked_tiles_tms.append(cur_t_tms.NearestTiles.back)
	
	if _with_walls and back_wall != null:
		not_blocked_tiles.append(back_wall)
	
	if cur_t_tms.AvailableWays.front:
		not_blocked_tiles_tms.append(cur_t_tms.NearestTiles.front)

	if _with_self:
		var left_wall = get_wall_by_tms_map_pos(cur_t_tms.map_pos)
		if _with_walls and left_wall != null:
			not_blocked_tiles.append(left_wall)

		not_blocked_tiles_tms.append(cur_t_tms)

	for t_tms in not_blocked_tiles_tms:
		var t = get_tile_by_tms(t_tms)
		if t != null:
			not_blocked_tiles.append(t)
			#t.test_custom_color = SYS.Colors.black

	return not_blocked_tiles

# возможно это нахуй не надо
# а возможно пригодится при проверке attack range в ai
func get_tiles_in_range_sector(_from_t, _check_dir_x=SYS.DIR.LEFT, _range_v2 = null, _show_t=false):
	var from_t = _from_t
	
	var x_range = _range_v2.x
	var y_range = _range_v2.y

	var h_dir = null
	var v_dir = null

	var check_dir_x = _check_dir_x

	var proven_tiles_x = []
	var proven_tiles_y = []

	var from_t_map_pos = from_t.get_map_pos() # MAP POS начального тайла

	# ПРОВЕРЯЕМ ВСЕ ТАЙЛЫ ПО Y

	var is_up_dir_blocked = false
	var is_down_dir_blocked = false

	for i in range(y_range):
		var cur_dir

		var cur_y_index = from_t_map_pos.y

		# CHECK DOWN DIR
		if i < floor(y_range / 2):
			cur_y_index += i

			cur_dir = SYS.DIR.DOWN
			if is_down_dir_blocked:
				continue

		# CHECK UP DIR
		else: 
			# проверяем тайлы сверху по формуле
			# EXEMLE: y_range = 8; y_range / 2 = 4; 4 - [5,6,7..] = [-1,-2,-3..]
			cur_y_index += floor(y_range / 2) - i

			cur_dir = SYS.DIR.UP
			if is_up_dir_blocked:
				continue

		var cur_t = get_tile_by_map_pos(Vector2(from_t_map_pos.x, cur_y_index))

		if cur_t != null:
			if cur_dir == SYS.DIR.DOWN:
				if cur_t.get_tms().WallBlockedWays.front:
					is_down_dir_blocked = true
			elif cur_dir == SYS.DIR.UP:
				if cur_t.get_tms().WallBlockedWays.back:
					is_up_dir_blocked = true

			proven_tiles_y.append(cur_t)

	# ПРОВЕРЯЕМ ТАЙЛЫ ПО X RANGE ИСХОДЯ ИЗ ПРАВИЛЬНЫХ Y ТАЙЛОВ

	var x_block_index # блокирует обзор если i совпадает с этим индексом

	var cur_y_dir 

	for cur_y_t in proven_tiles_y:
		var is_left_dir_blocked = false
		var is_right_dir_blocked = false

		var cur_y_t_map_pos = cur_y_t.get_map_pos()

		if cur_y_t_map_pos.y < from_t_map_pos.y:
			if cur_y_dir != SYS.DIR.UP:
				cur_y_dir = SYS.DIR.UP
				x_block_index = null
		elif cur_y_t_map_pos.y > from_t_map_pos.y:
			if cur_y_dir != SYS.DIR.DOWN:
				cur_y_dir = SYS.DIR.DOWN
				x_block_index = null

		for i in range(x_range):
			var cur_x_index = cur_y_t_map_pos.x

			if check_dir_x == SYS.DIR.RIGHT:
				cur_x_index += i

				if x_block_index != null and x_block_index < cur_x_index:
					break
				elif is_right_dir_blocked:
					continue

			elif check_dir_x == SYS.DIR.LEFT:
				cur_x_index -= i

				if x_block_index != null and x_block_index > cur_x_index:
					break
				elif is_left_dir_blocked:
					continue

			var cur_t = get_tile_by_map_pos(Vector2(cur_x_index, cur_y_t_map_pos.y))

			if cur_t != null:
				if check_dir_x == SYS.DIR.RIGHT:
					if cur_t.get_tms().WallBlockedWays.right:
						is_right_dir_blocked = true
						x_block_index = cur_x_index

				elif check_dir_x == SYS.DIR.LEFT:
					if cur_t.get_tms().WallBlockedWays.left:
						is_left_dir_blocked = true
						x_block_index = cur_x_index

				proven_tiles_x.append(cur_t)

	# HIGHLIGHT TILES
	if _show_t:
		# clear prev test_custom_color in tiles
		for t in tiles:
			if t.test_custom_color != null:
				t.test_custom_color = null

		# paint new tiles
		for x_t in proven_tiles_x:
			x_t.test_custom_color = SYS.Colors.green

		for y_t in proven_tiles_y:
			y_t.test_custom_color = SYS.Colors.plum

	var result_tiles = proven_tiles_y + proven_tiles_x
	
	return result_tiles

# проверяет находится ли нод в заданном диапазоне тайлов x/y
func check_is_tile_in_range_sector(_from_t, _to_t, _range_v2, _highlight_t=false, _return_tiles=false):
	var from_tile = _from_t
	var to_tile = _to_t

	if from_tile != null and to_tile != null:
		var from_tile_tms = from_tile.tile_map_symbol
		var to_tile_tms = to_tile.tile_map_symbol
	
		var h_dir
		var v_dir
		
		if to_tile_tms.map_pos.x < from_tile_tms.map_pos.x:
			h_dir = SYS.DIR.LEFT
		elif to_tile_tms.map_pos.x > from_tile_tms.map_pos.x:
			h_dir = SYS.DIR.RIGHT
		else:
			h_dir = null
	
		if to_tile_tms.map_pos.y < from_tile_tms.map_pos.y:
			v_dir = SYS.DIR.UP
		elif to_tile_tms.map_pos.y > from_tile_tms.map_pos.y:
			v_dir = SYS.DIR.DOWN
		else:
			v_dir = null
	
		var sight_sector_tiles = get_tiles_in_range_sector(
			from_tile, h_dir, _range_v2, _highlight_t)
	
		if _return_tiles:
			return sight_sector_tiles
		else:
			if sight_sector_tiles.has(to_tile):
				return true
			else:
				return false
	else:
		if _return_tiles:
			return []
		else:
			return false
			
			
func set_room(_room):
	room = _room
	room_id = _room.id

	print("SET ROOM NAME: " + str(room.get_zone_name()))

func get_room():
	return room

func get_outside_tiles():
	var correct_tiles = []
	for t in tiles:
		if t.is_outside_floor:
			correct_tiles.append(t)
	return correct_tiles

func get_tiles_inside_rooms():
	var correct_tiles = []
	for t in tiles:
		if get_tile_g_room(t) != null:
			correct_tiles.append(t)
	return correct_tiles

func get_all_units_current_tiles():
	var c_tiles = []
	for u in units:
		if u.current_tile != null:
			c_tiles.append(u.current_tile)
	return c_tiles

func get_unit_with_current_tile(_tile):
	for u in units:
		var u_ref = weakref(u)
		if u_ref.get_ref() and u.current_tile == _tile:
			return u
	return null

func get_units_with_current_tile(_tile):
	var cur_t_units = []
	for u in units:
		var u_ref = weakref(u)
		if u_ref.get_ref() and u.current_tile == _tile:
			cur_t_units.append(u)
	return cur_t_units

func get_car_with_current_tile(_tile):
	for c in cars:
		if c.main_current_tile == _tile or c.second_current_tile == _tile:
			return c
		return null

func get_tile_with_connected_local_storage(_cls):
	for t in tiles:
		if t.Connected.local_storage == _cls:
			return t
	return null

func get_tile_tms(_t):
	for t in tiles:
		if t == _t:
			return t.tile_map_symbol
	return null

func get_tile_by_tms(_tms):
	for t in tiles:
		if t.tile_map_symbol == _tms:
			return t
	return null

func get_tile_by_map_pos(_pos):
	for tile in tiles:
		if tile.is_floor and tile.map_pos == _pos:
			return tile
	return null

func get_tile_in_pos(_pos):
	var check_pos = _pos
	for tile in tiles:
		var tile_pos = tile.get_global_pos()
		#if check_pos.x >= tile_pos.x and check_pos.x < tile_pos.x + dist_between_tiles.x - 5 and \
		#	check_pos.y >= tile_pos.y and check_pos.y < tile_pos.y + dist_between_tiles.y - 5: 
		var dist_between_cur_tiles = SYS.get_dist_between_points_in_detail(check_pos, tile_pos)
		if dist_between_cur_tiles.horizontal < dist_between_tiles.x - 5 and \
			dist_between_cur_tiles.vertical < dist_between_tiles.y - 3:
			return tile
	return null

func get_tile_nearest_tile_in_dir(_t, _sys_dir):
	var t = _t
	var sys_dir = _sys_dir
	
	var t_tms = t.get_tms()
	var nearest_t
	var nearest_t_tms

	if sys_dir == SYS.DIR.LEFT:
		nearest_t_tms = t_tms.NearestTiles.left
	elif sys_dir == SYS.DIR.RIGHT:
		nearest_t_tms = t_tms.NearestTiles.right
	elif sys_dir == SYS.DIR.UP:
		nearest_t_tms = t_tms.NearestTiles.back
	elif sys_dir == SYS.DIR.DOWN:
		nearest_t_tms = t_tms.NearestTiles.front
	else:
		print("You shouldn't see this error! get_tile_nearest_tile_in_dir() error! sys_dir unknown")

	if nearest_t_tms != null:
		nearest_t = get_tile_by_tms(nearest_t_tms)
	
	return nearest_t

func get_corrected_tile_pos(_t):
	if _t != null and weakref(_t).get_ref():
		var cor_pos = _t.tile_center_pos
		cor_pos.x += 34
		cor_pos.y -= 44
		return cor_pos
	else:
		return null

# _allow_diagonal_paths = разрешить диагональные пути между тайлами
func get_tiles_around_tile(_t, _with_available_paths = false, _return_dict = false,
 _allow_diagonal_paths = false, _except_walls = false):
	var cur_tile = _t
	# если true возвращает только тайлы соединенные с cur_tile путём A*
	var with_available_paths = _with_available_paths 
	var allow_diagonal_paths = _allow_diagonal_paths

	var cur_tile_map_pos = cur_tile.get_map_pos()

	var around_tiles = {
		up_tile = get_tile_by_map_pos(Vector2(cur_tile_map_pos.x, cur_tile_map_pos.y - 1)),
		l_tile = get_tile_by_map_pos(Vector2(cur_tile_map_pos.x - 1, cur_tile_map_pos.y)),
		r_tile = get_tile_by_map_pos(Vector2(cur_tile_map_pos.x + 1, cur_tile_map_pos.y)),
		down_tile = get_tile_by_map_pos(Vector2(cur_tile_map_pos.x, cur_tile_map_pos.y + 1))
	}

	if allow_diagonal_paths:
		around_tiles.up_l_tile = get_tile_by_map_pos(Vector2(cur_tile_map_pos.x - 1, cur_tile_map_pos.y - 1))
		around_tiles.up_r_tile = get_tile_by_map_pos(Vector2(cur_tile_map_pos.x + 1, cur_tile_map_pos.y - 1))
		around_tiles.down_l_tile = get_tile_by_map_pos(Vector2(cur_tile_map_pos.x - 1, cur_tile_map_pos.y + 1))
		around_tiles.down_r_tile = get_tile_by_map_pos(Vector2(cur_tile_map_pos.x + 1, cur_tile_map_pos.y + 1))


	var result_tiles = []

	for k in around_tiles.keys():
		var ar_tile = around_tiles[k]
		if ar_tile != null:
			if with_available_paths:
				if is_way_exist_between_tiles(cur_tile, ar_tile):
					result_tiles.append(ar_tile)
				else:
					if _return_dict:
						around_tiles[k] = null
			else:
				result_tiles.append(ar_tile)
	
	if _return_dict:
		return around_tiles

	# проверяем диагональные пути и добавляем в массив если путь есть
	if with_available_paths and allow_diagonal_paths:
		# верх лево
		if result_tiles.has(around_tiles.l_tile) and result_tiles.has(around_tiles.up_tile):
			result_tiles.append(around_tiles.up_l_tile)
		# верх право
		if result_tiles.has(around_tiles.r_tile) and result_tiles.has(around_tiles.up_tile):
			result_tiles.append(around_tiles.up_r_tile)
		# низ лево
		if result_tiles.has(around_tiles.l_tile) and result_tiles.has(around_tiles.down_tile):
			result_tiles.append(around_tiles.down_l_tile)
		# низ право
		if result_tiles.has(around_tiles.r_tile) and result_tiles.has(around_tiles.down_tile):
			result_tiles.append(around_tiles.down_r_tile)

	# если нужно исключать стены
	if _except_walls:
		var t_tms = cur_tile.get_tms()

		if result_tiles.has(around_tiles.up_tile) and t_tms.WallBlockedWays.back:
			result_tiles.erase(around_tiles.up_tile)
		if result_tiles.has(around_tiles.down_tile) and t_tms.WallBlockedWays.front:
			result_tiles.erase(around_tiles.down_tile)
		if result_tiles.has(around_tiles.l_tile) and t_tms.WallBlockedWays.left:
			result_tiles.erase(around_tiles.l_tile)
		if result_tiles.has(around_tiles.r_tile) and t_tms.WallBlockedWays.right:
			result_tiles.erase(around_tiles.r_tile)

	return result_tiles

# получает тайлы в круговом секторе вокруг тайла (радиус выставляется в тайлах)
func get_tiles_in_circle_sector_around_tile(_center_tile, _radius_in_tiles = 1):
	var center_tile = _center_tile
	var radius_in_tiles = _radius_in_tiles
	
	# придется обойтись без ебаных синусов и ебучих косинусов
	# правильней в этой игре будет оценивать лев пра верх ниж тайл у каждого следующего тайла
	# так будет генерироваться правильный сектор из тайлов и не нужно будет делать расчёты

	var check_tiles = [center_tile]
	var result_tiles = []
	for i in range(radius_in_tiles):

		var erased_tiles = []
		for check_tile in check_tiles + []:
			var around_tiles = get_tiles_around_tile(check_tile, true, true)

			for v_tile in around_tiles.values():
				if v_tile != null and !check_tiles.has(v_tile) and !result_tiles.has(v_tile):
					check_tiles.append(v_tile)
					result_tiles.append(v_tile)

			erased_tiles.append(check_tile)
		
		for er_tile in erased_tiles:
			check_tiles.erase(er_tile)

	return result_tiles

# получает тайлы с определенной стороны от центрального тайла из круглого сектора (прошлая f)
func get_tiles_in_dir_from_center_in_tiles_circle_sector(_center_tile, _tiles, _dir):
	var center_t_map_pos = _center_tile.map_pos
	var correct_tiles = []
	var cur_dir = _dir

	for t in _tiles:
		if t != _center_tile:
			var t_map_pos = t.map_pos
			if cur_dir == SYS.DIR.LEFT and t.map_pos.x < center_t_map_pos.x:
				correct_tiles.append(t)
			elif cur_dir == SYS.DIR.RIGHT and t.map_pos.x > center_t_map_pos.x:
				correct_tiles.append(t)
			elif cur_dir == SYS.DIR.UP and t.map_pos.y < center_t_map_pos.y:
				correct_tiles.append(t)
			elif cur_dir == SYS.DIR.DOWN and t.map_pos.y > center_t_map_pos.y:
				correct_tiles.append(t)
	return correct_tiles

func get_all_tiles_in_sector_around_tile(_orig_tile, _radius_dist, _with_walls = true):
	var orig_tile = _orig_tile
	var radius_dist = _radius_dist

	var correct_tiles = []
	for t in tiles:
		if SYS.get_dist_between_points(
			get_corrected_tile_pos(orig_tile), get_corrected_tile_pos(t)) <= radius_dist:
			
			correct_tiles.append(t)

	for w in walls:
		if SYS.get_dist_between_points(
			get_corrected_tile_pos(orig_tile), get_corrected_tile_pos(w)) <= radius_dist:
			
			correct_tiles.append(w)	
				
	return correct_tiles

func get_wall_by_tms_map_pos(_pos):
	for wall in walls:
		if wall.get_tms().map_pos == _pos:
			return wall
	return null

func get_all_tiles_with_g_block(_g_block):
	var tiles_tms = g.find_all_tms_with_symbol(_g_block)
	var cor_tiles = []
	
	for t_tms in tiles_tms:
		cor_tiles.append(get_tile_by_tms(t_tms))

	return cor_tiles

func get_tile_g_room(_t):
	var t = _t

	for g_r in g.rooms:
		if g.is_pos_inside_room(t.get_tms().map_pos, g_r):
			return g_r

	return null

func get_available_car_parking_tile():
	var tiles = get_all_tiles_with_g_block(g.BLOCKS.CAR_PARKING)
	var cars_nodes = get_node("cars").get_children()

	var tiles_to_erase = []
	for t in tiles:
		if t == null or t.get_contains_car() != null:
			tiles_to_erase.append(t)
			
	for te in tiles_to_erase:
		tiles.erase(te)

	if tiles.size() > 0:
		randomize()

		var rand_index = randi() % tiles.size()

		print("PARKING PLACE AVAILABLE tiles size: " + str(tiles.size()) + " cars size: " + str(cars.size()))

		return tiles[rand_index] # возвращаем случайный тайл парковки
	else:
		return null

# получить расстояние между тайлами в тайлах
func get_dist_between_tiles_in_t(_t1, _t2):
	var dist_x = sqrt(pow(_t2.map_pos.x - _t1.map_pos.x, 2))
	var dist_y = sqrt(pow(_t2.map_pos.y - _t1.map_pos.y, 2))
	var dist = sqrt(pow(_t2.map_pos.x - _t1.map_pos.x, 2) + pow(_t2.map_pos.y - _t1.map_pos.y, 2))

	return {dist_x = dist_x, dist_y = dist_y, dist = dist}

func get_z_data_by_map_pos_y(_map_pos_y):
	for z_data in z_datas:
		if z_data.map_pos_y == _map_pos_y:
			return z_data
	return null

func is_way_exist_between_tiles(_t1, _t2):
	return g.ways_web.is_way_exist_between_tiles(_t1.get_tms(), _t2.get_tms())

func is_active():
	if get_room() != null and game.get_active_room() == get_room():
	#if is_visible():
		return true
	else:
		#print("r. room = " + get_room().room_name)
		#print("game active room =" + game.get_current_room().room_name)
		return false