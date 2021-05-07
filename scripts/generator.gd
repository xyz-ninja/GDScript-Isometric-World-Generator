extends Node2D

enum TILE_MOVEMENT_PARAMS {FLOOR, SOLID, SMALL_FURNITURE}
enum TILE_LAYER_TYPE {FLOOR, WALL_H, WALL_V}

class WaysWeb:
	var way_paths = []

	func _init():
		pass

	func add_way_path(_wp):
		way_paths.append(_wp)

	func is_way_exist_between_tiles(_t1_tms, _t2_tms):
		return SYS.astar.are_points_connected(_t1_tms.id, _t2_tms.id)

	func remove_A_STAR_way_between_tiles(_t1_tms, _t2_tms):
		if _t1_tms != null and _t2_tms != null and is_way_exist_between_tiles(_t1_tms, _t2_tms):
			var cur_way_path = get_A_STAR_path_between_tiles(_t1_tms, _t2_tms)
			way_paths.erase(cur_way_path)

			SYS.astar.disconnect_points(_t1_tms.id, _t2_tms.id)
			
	func get_A_STAR_path_between_tiles(_t1_tms, _t2_tms):
		var result_path = []

		var t_start = _t1_tms
		var t_finish = _t2_tms

		result_path = SYS.astar.get_id_path(t_start.id, t_finish.id)

		return result_path

class WayPath:
	var id = 0
	var capacity = 0

	var from_tile = null
	var to_tile = null

	func _init(_from, _to):
		from_tile = _from
		to_tile = _to

		#SYS.astar.connect_points(from_tile.id, to_tile.id)
		SYS.astar.connect_points(from_tile.id, to_tile.id)

	func set_capacity(_c):
		capacity = _c

class TileMapSymbol:
	var g = null

	var id = 0
	var astar_point = null

	var map_pos = Vector2()
	var movement_param = TILE_MOVEMENT_PARAMS.SOLID

	var all_layers_symbols = []

	# доступные пути в стороны из тайла в данный момент
	var AvailableWays = {left = false, right = false, front = false, back = false}
	# изначальные сохранённые пути
	var InitAvailableWays = {left = false, right = false, front = false, back = false}

	# пути в стороны заблокированные стенами
	var WallBlockedWays = {
		left = false,
		right = false,
		front = false,
		back = false
	}

	var NearestTiles = {
		left = null,
		right = null,
		front = null,
		back = null
	}

	func _init(_map_pos):
		SYS.tms_last_id += 1
		id = SYS.tms_last_id

		map_pos = _map_pos

		astar_point = SYS.astar.add_point(id, Vector3(
			map_pos.y, map_pos.x, 0))
		
	func set_all_layers_symbols(_a):
		all_layers_symbols.clear()
		all_layers_symbols = _a

	func set_move_param(_new_param):
		movement_param = _new_param

	func setup_way_by_dir(_g, _dir, _tile_tms):
		g = _g

		var dir = _dir
		var t_tms = _tile_tms

		if t_tms == null:
			return 
		else:
			if dir == SYS.ISOM_WALL_DIR.LEFT:
				if !all_layers_symbols.has(g.BLOCKS.WALL_L) and \
				!t_tms.all_layers_symbols.has(g.BLOCKS.WALL_R):
					AvailableWays.left = true
				else:
					WallBlockedWays.left = true

				NearestTiles.left = t_tms
			elif dir == SYS.ISOM_WALL_DIR.RIGHT:
				if !all_layers_symbols.has(g.BLOCKS.WALL_R) and \
				!t_tms.all_layers_symbols.has(g.BLOCKS.WALL_L):
					AvailableWays.right = true
				else:
					WallBlockedWays.right = true

				NearestTiles.right = t_tms
			elif dir == SYS.ISOM_WALL_DIR.FRONT:
				if all_layers_symbols.has(g.BLOCKS.WALL_F) or \
					all_layers_symbols.has(g.BLOCKS.WALL_B):

					g.ways_web.remove_A_STAR_way_between_tiles(t_tms, self)
					WallBlockedWays.front = true
				else:
					AvailableWays.front = true

				NearestTiles.front = t_tms
			elif dir == SYS.ISOM_WALL_DIR.BACK:
				if t_tms.all_layers_symbols.has(g.BLOCKS.WALL_B) or \
					t_tms.all_layers_symbols.has(g.BLOCKS.WALL_F):
					
					g.ways_web.remove_A_STAR_way_between_tiles(self, t_tms)
					WallBlockedWays.back = true
				else:
					AvailableWays.back = true

				NearestTiles.back = t_tms 

	func remove_ways_in_all_dirs():
		remove_ways_in_dirs({left = true, right = true, back = true, front = true})

		# ПРОВЕРЯТЬ СУЩЕСТВУЕТ ЛИ ТАЙЛ ПЕРЕД ПРОВЕРКОЙ ПУТИ 

	# UPDATE WAYS WHEN FURNITURE DELETED!!!!!!
	# MAY BE SAVE WAYS WHEN SETUP !!!!! ПОЧТИ СДЕЛАЛ ЭТУ ПАРАШНУЮ ЗАЛУПУ
	func remove_ways_in_dirs(_closed_dirs):
		if g == null:
			print("FURNITURE TMS SETUP FAILED :( GENERATOR NOT FOUND!")
		else:
			var closed_dirs = _closed_dirs
			if closed_dirs.left:
				AvailableWays.left = false
				g.ways_web.remove_A_STAR_way_between_tiles(self, NearestTiles.left)
			if closed_dirs.right:
				AvailableWays.right = false
				g.ways_web.remove_A_STAR_way_between_tiles(self, NearestTiles.right)
			if closed_dirs.back:
				AvailableWays.back = false
				g.ways_web.remove_A_STAR_way_between_tiles(self, NearestTiles.back)
			if closed_dirs.front:
				AvailableWays.front = false
				g.ways_web.remove_A_STAR_way_between_tiles(self, NearestTiles.front)

	func save_init_ways():
		InitAvailableWays.left = AvailableWays.left
		InitAvailableWays.right = AvailableWays.right
		InitAvailableWays.front = AvailableWays.front
		InitAvailableWays.back = AvailableWays.back

	func return_init_ways():
		if InitAvailableWays.left:
			g.create_way_between_tiles(self, NearestTiles.left)
		if InitAvailableWays.right:
			g.create_way_between_tiles(self, NearestTiles.right)
		if InitAvailableWays.back:
			g.create_way_between_tiles(self, NearestTiles.back)
		if InitAvailableWays.front:
			g.create_way_between_tiles(self, NearestTiles.front)

	func get_nearest_tiles():
		var result_arr = []
		for v in NearestTiles.values():
			if v != null:
				result_arr.append(v)
		return result_arr

	# получает все стены из параллельных слоёв с таким же map_pos 
	func get_walls_from_parallel_layers():
		var walls = []
		for block in all_layers_symbols:
			if block == g.BLOCKS.WALL_L or block == g.BLOCKS.WALL_R or \
				block == g.BLOCKS.WALL_F or block == g.BLOCKS.WALL_B:

				walls.append(block)
		return walls

class Room :
	var id

	var g

	var inmap_pos = Vector2()
	var inmap_size = Vector2()

	var mode

	var offset
	var door_pos 
	var map_dimensions

	enum WALL_TYPE {H,V}

	func _init(_generator, _id, _x, _y, _width, _height, _offset, _mode):
		g = _generator

		id = _id

		inmap_pos.x = _x
		inmap_pos.y = _y	

		inmap_size.x = _width
		inmap_size.y = _height

		offset = _offset
		mode = _mode

	func get_obj_dir_inside_wall(_g, _obj_pos):

		var o_pos = _obj_pos

		# если эта позиция будет равняться obj_pos то объект находится 
		# в стене этой комнаты

		var DIR = SYS.ISOM_WALL_DIR
		
		if o_pos.x == inmap_pos.x:
			if o_pos.y >= inmap_pos.y and o_pos.y <= get_end_pos().y:
				print(str(_obj_pos) + "IN WALL LEFT!")
				return DIR.LEFT
		if o_pos.x == get_end_pos().x or o_pos.x + 1 == get_end_pos().x:
			if o_pos.y >= inmap_pos.y and o_pos.y <= get_end_pos().y:
				print(str(_obj_pos) + "IN WALL RIGHT!")
				return DIR.RIGHT
		if o_pos.y == inmap_pos.y:
			if o_pos.x >= inmap_pos.x and o_pos.x <= get_end_pos().x:
				print(str(_obj_pos) + "IN WALL BACK!")
				return DIR.BACK

		if o_pos.y == get_end_pos().y:
			if o_pos.x >= inmap_pos.x and o_pos.x <= get_end_pos().x:
				print(str(_obj_pos) + "IN WALL FRONT!")
				return DIR.FRONT
					
		return null

	# MAY BE NEED DELETE THIS SHIT
	func get_all_positions_inner_room(_g):
		var g = _g

		var start_pos = inmap_pos
		var finish_pos = get_end_pos()

		var result = []
		for i in range(start_pos.y, finish_pos.y + 1):
			for j in range(start_pos.x, finish_pos.x):
				result.append(Vector2(j, i))

		return result

	func is_start_room():
		if mode != g.ROOM_MODE.NEXT and mode != g.ROOM_MODE.NEXT_VERT:
			return true
		else:
			return false

	func set_door_pos(_dp):
		door_pos = _dp

	func set_map_dimensions(_md):
		map_dimensions = _md

	func get_end_pos():
		return Vector2(inmap_pos.x + inmap_size.x, inmap_pos.y + inmap_size.y)

class Generator :
	var BLOCKS = {
		NONE = ".",

		WALL = "#",
		WALL_L = "L", # left
		WALL_R = "R", # right
		WALL_F = "F", # front
		WALL_B = "B", # back
		
		OUTSIDE_FLOOR_PLATE = ",",
		OUTSIDE_FLOOR_PLATE_ROAD = ";",
		FLOOR_PLATE = "*",

		DOOR_OPENED = "-",

		UNIT_SPAWN = "u",
		UNIT_PLAYER = "p",
		UNIT_ENEMY = "e",
		UNIT_CIVIL = "c",
		UNIT_CIVIL_QUEST = "q", # квестовый гражданский (продавец, кассир)
		UNIT_POLICE = "P",
		UNIT_SECURITY = "s",

		UNIT_BAND_PATRIOTS = "1",
	
		# ROOM FURNITURE OBJECTS
		RFO_BARMAN_TABLE = "t",
		RFO_OLD_PARAPET = "<",

		CAR_PARKING = "r"
	}

	enum TYPES {
		RANDOM,
		TRAINING_FIGHT_MISSION,

		ARROW,
		P_HOLDING_GARAGE,
		P_HOLDING_GYM,
		P_HOLDING_SMALL_CLINIC,
		P_HOLDING_BAR
	}

	enum SUBTYPES {
		VERT_UP, # vetrical room that placed upper
		VERT_DOWN,
		SMALL_DISGUISE
	}

	enum ROOM_MODE {FIRST, NEXT, NEXT_VERT}

	# наполняет комнаты определенными объектами (например мебель)
	var RoomFillingObject = {
		block = null,
		start_pos = null, 	# vec2
		size = null, 		# vec2
	}

	var game

	var room_id = null

	var type = null
	var sub_type = null

	var maps_layers = {
		map = [],
		map_walls_h = [],
		map_walls_v = [],
		map_floor = [],
		map_outside = [],
		map_units = []
	}

	var map_size = Vector2()

	var tile_map_symbols = []

	var rooms = []
	var rooms_count = 0
	var last_room_id = 0

	var spawn_vert_room_at = null # sometimes spawn room top or bottom

	var ways_web = null

	var block_start_offset = Vector2(4,0)

	var outside_params = {min_x = null, min_y = null, max_x = null, max_y = null}
	#var outside_params = {min_x = 0, min_y = 0, max_x = 0, max_y = 0}

	func _init(_game):
		game = _game
		ways_web = WaysWeb.new()

	func generate(_rooms_count, _type, _sub_type):
		randomize()

		type = _type
		sub_type = _sub_type

		rooms_count = _rooms_count
 
		var ground_size = Vector2()

		if type == TYPES.TRAINING_FIGHT_MISSION:
			ground_size.x = 13
			ground_size.y = 7
		else:
			ground_size.x = 25 * rooms_count
			ground_size.y = 19

		# generate ground
		for y in range(ground_size.y):
			maps_layers.map.append("")
			for x in range(ground_size.x):
				maps_layers.map[y] += BLOCKS.NONE

		maps_layers.map_walls_v = [] + maps_layers.map # clone of maps_layers.map array
		maps_layers.map_walls_h = [] + maps_layers.map
		maps_layers.map_floor = [] + maps_layers.map
		maps_layers.map_outside = [] + maps_layers.map
		maps_layers.map_units = [] + maps_layers.map

		# set maps_layers.map size
		map_size.x = maps_layers.map[0].length()
		map_size.y = maps_layers.map.size()

		# IF DOESN'T HAVE ROOMS
		if rooms_count == 0:
			generate_outside_in_sector(
				Rect2(0, 0, ground_size.x, ground_size.y),
				Rect2(0, 1, ground_size.x, ground_size.y - 2))
			
			generate_blocks_in_outside_by_type(ground_size)

			# generate outside params 20 23
			#generate_floor_in_room(Vector2(14, 0), Vector2(10, 3))
		else:
			# generate rooms
			for i in range(rooms_count):
				# first room params
				if i == 0:
					generate_room(ROOM_MODE.FIRST, block_start_offset)
				else:
					if spawn_vert_room_at == null:
						generate_room(ROOM_MODE.NEXT)
					else:
						generate_room(ROOM_MODE.NEXT_VERT)

		calculate_outside_params()

		# generate units
		generate_units()
		
		# fill wall-dirs arrays
		for row in range(maps_layers.map.size()):
			for col in range(maps_layers.map[row].length()):
				var cur_ceil = maps_layers.map[row][col]

				if cur_ceil == BLOCKS.WALL_F or cur_ceil == BLOCKS.WALL_B:
					maps_layers.map_walls_h[row][col] = cur_ceil
				elif cur_ceil == BLOCKS.WALL_L or cur_ceil == BLOCKS.WALL_R:
					maps_layers.map_walls_v[row][col] = cur_ceil

					# закрывает "зазоры" в нижних левом и правом углах v стен
					if (maps_layers.map[row + 1][col] == BLOCKS.WALL_F or
						maps_layers.map[row + 1][col] == BLOCKS.WALL_B):

						maps_layers.map_walls_v[row+1][col] = cur_ceil

		if rooms.size() > 0:
			delete_outside_tiles_inside_rooms()
		
		setup_ways_web()

	func generate_room(_mode, _offset = null):
		randomize()

		var mode = _mode
		var offset = _offset

		var gen_w
		var gen_h

		var start_x = 0
		var start_y = 0

		var end_w # end of top wall
		var end_h # end of left wall

		var door_pos = Vector2(0,0)
		var door_params = {
			repeat_x = 0, repeat_y = 0, # создаёт клоны двери дальше по направлению x/y
		}

		var spawn_objs = [{}]

		var skip_BLOCKS_pos = [] # this BLOCKS didnt spawn at map
		var env_blocks_params = [] # параметры блоков окружения (например спаун мебели по y,x и т.п.)

		var temp_diff = 0 # difference between size of prev and new walls

		#########################
		##..SPAWN.START.POINT..##
		#########################

		if mode == ROOM_MODE.FIRST:
			if type == TYPES.RANDOM:
				gen_w = randi() % 6 + 6
				gen_h = randi() % 5 + 5

				start_x = 3
				start_y = int(map_size.y / 2 - gen_h / 2)

				door_pos.x = start_x
				door_pos.y = start_y + int(gen_h / 2)
			elif type == TYPES.ARROW:
				gen_w = randi() % 4 + 10
				gen_h = randi() % 4 + 8

				start_x = 3
				start_y = int(map_size.y / 2 - gen_h / 2)

				door_pos.x = start_x
				door_pos.y = start_y + int(gen_h / 2)

			elif type == TYPES.P_HOLDING_GARAGE:
				gen_w = 3
				gen_h = 5

				start_x = 3
				start_y = int(map_size.y / 2 - gen_h / 2)

				door_pos.x = start_x
				door_pos.y = start_y + 2
				door_params.repeat_y = 1

			elif type == TYPES.P_HOLDING_GYM:
				gen_w = 4
				gen_h = 4

				start_x = 3
				start_y = int(map_size.y / 2 - gen_h / 2)

				door_pos.x = start_x
				door_pos.y = start_y + 2

			elif type == TYPES.P_HOLDING_SMALL_CLINIC:
				gen_w = 2
				gen_h = 4

				start_x = 3
				start_y = int(map_size.y / 2 - gen_h / 2)

				door_pos.x = start_x
				door_pos.y = start_y + 1

			elif type == TYPES.P_HOLDING_BAR:
				gen_w = 4
				gen_h = 4

				start_x = 3
				start_y = int(map_size.y / 2 - gen_h / 2)

				door_pos.x = start_x
				door_pos.y = start_y + 2

				env_blocks_params = [{
					block = BLOCKS.RFO_BARMAN_TABLE, 
					pos = Vector2(start_x + gen_w - 2, start_y + 1),
					y_size_mul = 3
				}]

		# HORIZONTAL NEXT ROOM
		elif mode == ROOM_MODE.NEXT: 
			
			if type == TYPES.P_HOLDING_SMALL_CLINIC:
				gen_w = 3
				gen_h = 4
			else:
				if sub_type == null:
					gen_w = randi() % 6 + 4
					gen_h = randi() % 5 + 3
					
				elif sub_type == SUBTYPES.SMALL_DISGUISE:
					gen_w = 2
					gen_h = 4

			var prev_r = get_room_by_id(last_room_id)
			var prev_r_end_pos = prev_r.get_end_pos()

			start_x = prev_r_end_pos.x
			start_y = prev_r_end_pos.y

			# if this room bigger than previous
			if gen_h > prev_r.inmap_size.y:
				temp_diff = gen_h - prev_r.inmap_size.y
				start_y -= gen_h
				start_y += int(temp_diff / 2) # translate room to correct point
				# chance to spawn room in top or bottom

				if SYS.get_random_percent_0_to_100() <= 50:
					spawn_vert_room_at = last_room_id + 1

				door_pos.y = prev_r.inmap_pos.y + int(prev_r.inmap_size.y / 2)

			# if this room smaller than previous
			elif gen_h < prev_r.inmap_size.y:
				temp_diff = prev_r.inmap_size.y - gen_h
				start_y -= gen_h
				start_y -= int(temp_diff / 2)

				door_pos.y = start_y + int(gen_h / 2)

			else:
				start_y = prev_r_end_pos.y - gen_h

				door_pos.y = start_y + int(gen_h / 2)
			
			# spawn door in prev room
			door_pos.x = prev_r_end_pos.x - 1
			# clear block to door in room
			skip_BLOCKS_pos.append(Vector2(door_pos.x + 1,door_pos.y))

		# VERTICAL NEXT ROOM
		elif mode == ROOM_MODE.NEXT_VERT: 
			var prev_r = get_room_by_id(spawn_vert_room_at)
			spawn_vert_room_at = null

			var prev_r_end_pos = prev_r.get_end_pos()

			if sub_type == null:
				gen_w = prev_r.inmap_size.x - randi() % 4
				gen_h = randi() % 3 + 4
			elif sub_type == SUBTYPES.SMALL_DISGUISE:
				gen_w = 4
				gen_h = 2

			temp_diff = prev_r.inmap_size.x - gen_w

			start_x = prev_r.inmap_pos.x + int(temp_diff / 2)

			randomize()
			var chance = randi() % 101
			# spawn room at TOP
			if chance < 50:
				start_y = prev_r.inmap_pos.y - gen_h
				door_pos.y = prev_r.inmap_pos.y
			# spawn room at BOTTOM
			else:
				start_y = prev_r_end_pos.y
				door_pos.y = start_y

			door_pos.x = start_x + int(gen_w / 2)
		
		last_room_id += 1

		if offset != null:
			start_x += offset.x
			start_y += offset.y

		# check collide with other rooms in corners
		if mode != ROOM_MODE.FIRST:
			for other_room in rooms:
				if is_pos_inside_room(Vector2(start_x,start_y), other_room):
					print("Corner Collision TOP LEFT : FIXING...")
					start_y += 1
				if is_pos_inside_room(Vector2(start_x + gen_w,start_y), other_room):
					print("Corner Collision TOP RIGHT : FIXING...")
					start_y += 1
				if is_pos_inside_room(Vector2(start_x,start_y + gen_h), other_room):
					print("Corner Collision BOTTOM LEFT : FIXING...")
					start_y -= 1
				if is_pos_inside_room(
					Vector2(start_x + gen_w,start_y + gen_h), other_room):
				
					print("Corner Collision BOTTOM RIGHT : FIXING...")
					start_y -= 1

		######################
		##..GENERATE.WALLS..##
		######################

		maps_layers.map[start_y][start_x] = BLOCKS.WALL_B

		#  generate top wall
		for top_w in range(gen_w - 1):
			maps_layers.map[start_y][start_x + (top_w + 1)] = BLOCKS.WALL_B

			end_w = start_x + (top_w + 1)

		#  generate right wall 
		for right_w in range(gen_h):
			maps_layers.map[start_y + (right_w + 1)][end_w] = BLOCKS.WALL_R
		
		#  generate left wall
		for left_w in range (gen_h):
			maps_layers.map[start_y + (left_w + 1)][start_x] = BLOCKS.WALL_L

			end_h = start_y + (left_w + 1)

		#  generate down wall 
		for down_w in range(gen_w):
			maps_layers.map[end_h][start_x + (down_w)] = BLOCKS.WALL_F

		# SPAWN BLOCKS
		var s_block = null # spawned block

		for pos in skip_BLOCKS_pos:
			s_block = spawn_block_at(BLOCKS.NONE, pos, null)

		# SPAWN DOOR
		if door_pos.x != 0 and door_pos.y != 0:
			s_block = spawn_block_at(BLOCKS.DOOR_OPENED, door_pos, offset)
			if door_params.repeat_x > 0:
				for i in range(door_params.repeat_x):
					var new_door_pos = door_pos
					new_door_pos.x += 1
					s_block = spawn_block_at(BLOCKS.DOOR_OPENED, new_door_pos, offset)
			if door_params.repeat_y > 0:
				for i in range(door_params.repeat_y):
					var new_door_pos = door_pos
					new_door_pos.y += 1
					s_block = spawn_block_at(BLOCKS.DOOR_OPENED, new_door_pos, offset)

		# SPAWN INNER ENV
		for info in env_blocks_params:
			if offset != null and info.has("pos"):
				info.pos.x += offset.x
				info.pos.y += offset.y

			spawn_env_block_by_param(info)

		var new_map_dimensions = generate_floor_in_room(
			Vector2(start_x,start_y),Vector2(gen_w,gen_h))

		var r = Room.new(self, last_room_id, start_x, start_y, gen_w, gen_h, offset, mode)
		r.set_door_pos(door_pos)
		r.set_map_dimensions(new_map_dimensions)

		rooms.append(r)

	# генерирует внутренние объекты в уровнях без комнат
	func generate_blocks_in_outside_by_type(_ground_size):
		var ground_size = _ground_size

		var env_blocks_params = []

		if type == TYPES.TRAINING_FIGHT_MISSION:
			env_blocks_params = [
				{
					block = BLOCKS.RFO_OLD_PARAPET,
					pos = Vector2(2, 2),
					x_size_mul = SYS.get_random_int(0, 4),
					y_size_mul = SYS.get_random_int(1, 4)
				},
				{
					block = BLOCKS.RFO_OLD_PARAPET,
					pos = Vector2(7, SYS.get_random_int(SYS.get_random_int(3, 4), 6)),
					x_size_mul = SYS.get_random_int(1, 4),
					is_x_size_backwards = true,
					y_size_mul = SYS.get_random_int(1, 4),
					is_y_size_backwards = true
				}
			]
		for info in env_blocks_params:
			spawn_env_block_by_param(info)

	# _gen_rect состоит из начальной позиции .pos генерации и её размеров .size
	# _addit_tiles_gen_rect - тоже самое для доп. тайлов (например BLOCKS.OUTSIDE_FLOOR_PLATE_ROAD)
	func generate_outside_in_sector(_gen_rect, _addit_tiles_gen_rect = null):
		var gen_rect = _gen_rect
		var gen_init_pos = gen_rect.pos
		var gen_size = gen_rect.size

		var addit_tiles_gen_rect = _addit_tiles_gen_rect
		var a_gen_init_pos = addit_tiles_gen_rect.pos
		var a_gen_size = addit_tiles_gen_rect.size

		# генерируем outside_floor тайлы
		for row in range(gen_init_pos.y, gen_init_pos.y + gen_size.y):
			for col in range(gen_init_pos.x, gen_init_pos.x + gen_size.x):

				maps_layers.map_outside[row][col] = BLOCKS.OUTSIDE_FLOOR_PLATE
		
		# генерируем доп тайлы
		for row in range(a_gen_init_pos.y, a_gen_init_pos.y + a_gen_size.y):
			for col in range(a_gen_init_pos.x, a_gen_init_pos.x + a_gen_size.x):

				maps_layers.map_outside[row][col] = BLOCKS.OUTSIDE_FLOOR_PLATE_ROAD
	
	# функция генерирует floor-тайлы в комнате
	func generate_floor_in_room(_start_pos, _size): 
		var out_x_mul = 4
		var out_y_mul = 3
 
		var new_min_x = _start_pos.x
		var new_min_y = _start_pos.y
		var new_max_x = _start_pos.x + _size.x
		var new_max_y = _start_pos.y + _size.y

		var out_s_pos = _start_pos
		out_s_pos.x -= out_x_mul
		out_s_pos.y -= out_y_mul

		var out_r_size = _size
		out_r_size.x += out_x_mul * 1.5
		out_r_size.y += out_y_mul * 2

		# GENERATE OUTSIDE
		for i in range(out_r_size.y):
			for j in range(out_r_size.x):
				var out_x = out_s_pos.x + j
				var out_y = out_s_pos.y + 1 + i
				
				# что это за пиздец одному богу известно
				if i > out_r_size.y / 6 and i < out_r_size.y - out_r_size.y / 4.5 and \
				j < out_r_size.x - out_x_mul * 0.18:
				
					var cur_floor_t = maps_layers.map_floor[out_y][out_x]
					
					if cur_floor_t != BLOCKS.FLOOR_PLATE:
						maps_layers.map_outside[out_y][out_x] = \
							BLOCKS.OUTSIDE_FLOOR_PLATE_ROAD
						
						if out_x < new_min_x:
							new_min_x = out_x
						if out_x > new_max_x:
							new_max_x = out_x
						if out_y > new_max_y:
							new_max_y = out_y
						if out_y < new_min_y:
							new_min_y = out_y
				else:
					maps_layers.map_outside[out_y][out_x] = BLOCKS.OUTSIDE_FLOOR_PLATE

					if out_x < new_min_x:
						new_min_x = out_x
					if out_x > new_max_x:
						new_max_x = out_x
					if out_y > new_max_y:
						new_max_y = out_y
					if out_y < new_min_y:
						new_min_y = out_y

		# GENERATE FLOOR IN ROOM
		var s_pos = _start_pos
		var r_size = _size

		for i in range(r_size.y):
			for j in range(r_size.x):
				var cur_x = s_pos.x + j
				var cur_y = s_pos.y + 1 + i

				# clear inner outside tiles
				maps_layers.map_outside[cur_y][cur_x] = BLOCKS.NONE
				
				# spawn floor plate
				maps_layers.map_floor[cur_y][cur_x] = BLOCKS.FLOOR_PLATE

		return {min_x = new_min_x, max_x = new_max_x, min_y = new_min_y, max_y = new_max_y}

	# удаляет outside floor тайлы внутри комнта
	func delete_outside_tiles_inside_rooms():
		for i in range(maps_layers.map_floor.size()):
			for j in range(maps_layers.map_floor[i].length()):
				var pos_layers = get_obj_all_layers_in_pos(Vector2(j, i))
				if pos_layers.has(BLOCKS.FLOOR_PLATE) and pos_layers.has(BLOCKS.OUTSIDE_FLOOR_PLATE):
					maps_layers.map_outside[i][j] = BLOCKS.NONE
	
	# ГЕНЕРАЦИЯ ЮНИТОВ КОТОРЫЕ ДОЛЖНЫ ПРИСУТСТВОВАТЬ ИЗНАЧАЛЬНО
	func generate_units():
		var dev_menu = game.get_tree().get_nodes_in_group("gui_dev_menu")[0]
		
		# СТАНДАРТНЫЕ ТАЙЛЫ ВХОДА ЮНИТОВ
		for cur_y in range(outside_params.min_y + 1, outside_params.max_y):
			spawn_block_at(BLOCKS.UNIT_SPAWN, Vector2(outside_params.min_x, cur_y), Vector2(0,0))

		# СТАНДАРТНЫЕ ТАЙЛЫ ВХОДА МАШИН
		for cur_y in range(outside_params.min_y + 2, outside_params.max_y - 1):
			spawn_block_at(BLOCKS.CAR_PARKING, Vector2(outside_params.min_x + 1, cur_y), Vector2(0,0))

		# СПАУН СТАНДАРТНЫХ ЮНИТОВ В ЗАВИСИМОСТИ ОТ ТИПА ГЕНЕРИРУЕМОГО УРОВНЯ
		if type == TYPES.TRAINING_FIGHT_MISSION:
			# количество создаваемых юнитов задаётся вручную в dev_menu
			var pl_gen_units_count = int(dev_menu.get_node("main/mission_rooms/gen_pl_units_line").get_text())
			var en_gen_units_count = int(dev_menu.get_node("main/mission_rooms/gen_enemy_units_line").get_text())

			# добавляем маркеры (блоки) спауна юнитов игрока
			for i in range(pl_gen_units_count):
				spawn_block_at(BLOCKS.UNIT_PLAYER, Vector2(
					outside_params.min_x + 3, outside_params.min_y + 3 + i), Vector2(0, 0), maps_layers.map_units)

			# добавляем маркеры (блоки) спауна вражеских юнитов
			for i in range(en_gen_units_count):
			#	spawn_block_at(BLOCKS.UNIT_POLICE, Vector2(
				spawn_block_at(BLOCKS.UNIT_BAND_PATRIOTS, Vector2(
					outside_params.min_x + 8, outside_params.min_y + 3 + i), Vector2(0, 0), maps_layers.map_units)

		else:
			var s_block

			var start_r

			for r in rooms:
				if r.is_start_room():
					start_r = r

			if start_r != null:
				var offset = start_r.offset

				# TEST POLICE UNIT!!!
				#s_block = spawn_block_at(BLOCKS.UNIT_POLICE, Vector2(
				#	start_r.door_pos.x + 1, start_r.door_pos.y + 1), offset, maps_layers.map_units)

	# special objects
	func spawn_block_at(_block, _pos, _offset, _custom_map_arr = null):
		var offset = _offset
		var custom_map_arr = _custom_map_arr

		var map_arr = null

		if custom_map_arr == null:
			map_arr = maps_layers.map
		else:
			map_arr = custom_map_arr

		if offset == null:
			map_arr[_pos.y][_pos.x] = _block
		else:
			map_arr[_pos.y + offset.y][_pos.x +  offset.x] = _block

	# ГЕНЕРИРУЕТ БЛОКИ ПО ЗАДАННЫМ ПАРАМЕТРАМ
	func spawn_env_block_by_param(_block_dict_info):
		var b_info = _block_dict_info
		var b = b_info.block

		var pos = b_info.pos

		# объект повторяющийся x раз по y
		if b_info.has("y_size_mul"):
			for i in range(b_info.y_size_mul):
				# is_y_size_backwards - спаунить блоки в обратную сторону
				if b_info.has("is_y_size_backwards") and b_info.is_y_size_backwards:
					spawn_block_at(b_info.block, Vector2(b_info.pos.x, b_info.pos.y - 1 * i), null)
				else:
					spawn_block_at(b_info.block, Vector2(b_info.pos.x, b_info.pos.y + 1 * i), null)
		
		# тоже самое по x
		if b_info.has("x_size_mul"):
			for i in range(b_info.x_size_mul):
				if b_info.has("is_x_size_backwards") and b_info.is_x_size_backwards:
					spawn_block_at(b_info.block, Vector2(b_info.pos.x - 1 * i, b_info.pos.y), null)
				else:
					spawn_block_at(b_info.block, Vector2(b_info.pos.x + 1 * i, b_info.pos.y), null)

		# if b_info.has(something)

	func setup_tile_map_symbols():
		for i in range(maps_layers.map.size()):
			for j in range(maps_layers.map[i].length()):
				
				# CREATE NEW TileMapSymbol OBJECT
				var new_tms = TileMapSymbol.new(Vector2(j, i))

				var tms_all_l = get_obj_all_layers_in_pos(Vector2(j, i))
				var tms_move_type = TILE_MOVEMENT_PARAMS.SOLID

				# IF THIS TILE OJBECT NOT EMPTY
				if tms_all_l.size() > 0:
					new_tms.set_all_layers_symbols(tms_all_l)

					# SETUP TMS MOVEMENT_PARAMS BY BLOCK
					for l_obj in tms_all_l:
						tms_move_type = TILE_MOVEMENT_PARAMS.FLOOR

					new_tms.set_move_param(tms_move_type)
					tile_map_symbols.append(new_tms)

	# ГЕНЕРИРУЕМ OUTSIDE FLOOR
	func calculate_outside_params():
		var o_p = outside_params

		for row_i in range(maps_layers.map_outside.size()):
			for col_i in range(maps_layers.map_outside[row_i].length()):
				
				var cur_block = maps_layers.map_outside[row_i][col_i]
				if cur_block != BLOCKS.NONE:
					# setup x values
					if o_p.min_x == null or col_i < o_p.min_x:
						o_p.min_x = col_i
					if o_p.max_x == null or col_i > o_p.max_x:
						o_p.max_x = col_i

					# setup y values
					if o_p.min_y == null or row_i < o_p.min_y:
						o_p.min_y = row_i
					if o_p.max_y == null or row_i > o_p.max_y:
						o_p.max_y = row_i

	# НАСТРОИВАЕТ СЕТЬ ПУТЕЙ
	func setup_ways_web():
		ways_web.way_paths.clear()
		setup_tile_map_symbols()

		for tms in tile_map_symbols:
			setup_all_dirs_tms(tms)

			if tms.AvailableWays.left:
				create_way_between_tiles(tms, tms.NearestTiles.left)
			if tms.AvailableWays.right:
				create_way_between_tiles(tms, tms.NearestTiles.right)
			if tms.AvailableWays.back:
				create_way_between_tiles(tms, tms.NearestTiles.back)
			if tms.AvailableWays.front:
				create_way_between_tiles(tms, tms.NearestTiles.front)

	# проверяет пути между тайлом и окружающими его тайлами
	func setup_all_dirs_tms(_tms):
		var tms = _tms

		var c_pos = tms.map_pos

		var l_tile_tms = get_tile_map_symbol_by_pos(Vector2(c_pos.x - 1, c_pos.y))
		var r_tile_tms = get_tile_map_symbol_by_pos(Vector2(c_pos.x + 1, c_pos.y))
		var b_tile_tms = get_tile_map_symbol_by_pos(Vector2(c_pos.x, c_pos.y - 1))
		var f_tile_tms = get_tile_map_symbol_by_pos(Vector2(c_pos.x, c_pos.y + 1))

		tms.setup_way_by_dir(self, SYS.ISOM_WALL_DIR.LEFT, l_tile_tms)
		tms.setup_way_by_dir(self, SYS.ISOM_WALL_DIR.RIGHT, r_tile_tms)
		tms.setup_way_by_dir(self, SYS.ISOM_WALL_DIR.BACK, b_tile_tms)
		tms.setup_way_by_dir(self, SYS.ISOM_WALL_DIR.FRONT, f_tile_tms)

	# создать путь между тайлами
	func create_way_between_tiles(_tms1, _tms2):
		if !ways_web.is_way_exist_between_tiles(_tms1, _tms2):
			var wp = WayPath.new(_tms1, _tms2)
			wp.set_capacity(10)
			ways_web.add_way_path(wp)

	func get_tile_map_symbol_by_pos(_pos):
		for tms in tile_map_symbols:
			if tms.map_pos == _pos:
				return tms
		return null

	func find_all_tms_with_symbol(_block_symbol):
		var found_tms = []
		for tms in tile_map_symbols:
			if tms.all_layers_symbols.has(_block_symbol):
				found_tms.append(tms)
		return found_tms

	func get_room_by_id(_id):
		for room in rooms:
			if room.id == _id:
				return room
		print("ERROR! ROOM WITH THAT ID, DOESNT EXIST!")
		return null

	# получает направление в котором тайл должен отображаться в стене (используется например для дверей)
	func get_dir_by_pos_in_wall(_pos):
		var pos = _pos
		
		for room in rooms:
			var inwall_dir = room.get_obj_dir_inside_wall(self, pos)
			if inwall_dir != null:
				return inwall_dir
		return null

	# отобразить карту в консоли
	func console_map():
		print("[ MAP ]")
		for line in maps_layers.map:
			print(line)
	
		print("[ FLOOR MAP ]")
		for line in maps_layers.map_outside:
			print(line)

		print("[ ROOMS ]")
		for room in rooms:
			print("Room №"+str(room.id)+ \
				" x:"+str(room.inmap_pos.x)+" y:"+str(room.inmap_pos.y)+ \
				" end pos: "+str(room.get_end_pos())+ \
				" w:"+str(room.inmap_size.x)+" h:"+str(room.inmap_size.y))

	func get_obj_all_layers_in_pos(_pos):
		var layers = []

		if maps_layers.map[_pos.y][_pos.x] != BLOCKS.NONE:
			layers.append(maps_layers.map[_pos.y][_pos.x])

		if maps_layers.map_outside[_pos.y][_pos.x] != BLOCKS.NONE:
			layers.append(maps_layers.map_outside[_pos.y][_pos.x])

		if maps_layers.map_floor[_pos.y][_pos.x] != BLOCKS.NONE:
			layers.append(maps_layers.map_floor[_pos.y][_pos.x])

		if maps_layers.map_walls_v[_pos.y][_pos.x] != BLOCKS.NONE:
			layers.append(maps_layers.map_walls_v[_pos.y][_pos.x])

		if maps_layers.map_walls_h[_pos.y][_pos.x] != BLOCKS.NONE:
			layers.append(maps_layers.map_walls_h[_pos.y][_pos.x])

		return layers

	# back стены спаунятся "вне" комнаты но всё равно принадлежат им
	# _with_addit_back_wall_tile позволяет включать тайл вне комнаты
	# (назначать true стоит только при смещении текстур стен)
	func get_room_by_pos(_pos, _with_addit_back_wall_tile = false):
		for room in rooms:
			if is_pos_inside_room(_pos, room, _with_addit_back_wall_tile):
				return room
		return null

	func is_pos_inside_room(_pos, _room, _with_addit_back_wall_tile = false):
		var pos = _pos
		var r = _room
		var r_pos = r.inmap_pos
		var r_end_pos = r.get_end_pos()

		if _with_addit_back_wall_tile:
			if check_is_pos_inside_room(Vector2(pos.x, pos.y), r_pos, r_end_pos) or \
				check_is_pos_inside_room(Vector2(pos.x, pos.y + 1), r_pos, r_end_pos):
				
				return true
			else:
				return false
		else:
			if check_is_pos_inside_room(Vector2(pos.x, pos.y), r_pos, r_end_pos):
				return true
			else:
				return false
	
	# эта функция должна использоваться только в прошлой функции
	func check_is_pos_inside_room(_pos, _room_pos, _room_end_pos):
		var pos = _pos
		var r_pos = _room_pos
		var r_end_pos = _room_end_pos

		if (pos.x >= r_pos.x and pos.x < r_end_pos.x and
			pos.y > r_pos.y and pos.y <= r_end_pos.y):

			return  true
		else:
			return false
	

onready var cam = get_node("cam")

var room_id = null

var g
var r

var cam_speed = 400
var cam_speed_mouse = 200
var cam_init_offset = Vector2(0, -100)
var cam_zoom_limits = Vector2(0.2, 0.55)
var cam_zoom_speed = 0.02

func _ready():
	#ROOT.load_global_scripts(ROOT.LOAD_STATE.TEST_RPG)
	
	#generate_map()
	
	set_process(true)

func start_setup(_room_id):
	room_id = _room_id
	g = Generator.new(get_tree().get_nodes_in_group("game")[0])
	g.room_id = room_id

	r = get_node("renderer")
	r.room_id = room_id

	cam.set_global_pos(Vector2(
		cam.get_global_pos().x + cam_init_offset.x,
		cam.get_global_pos().y + cam_init_offset.y
	))

func _process(delta):
	var dx = 0
	var dy = 0
	
	# MAKE IT FROM GUI FUNC
	if Input.is_action_pressed("ui_left"):
		dx -= cam_speed * delta
	if Input.is_action_pressed("ui_right"):
		dx += cam_speed * delta
	if Input.is_action_pressed("ui_up"):
		dy -= cam_speed * delta
	if Input.is_action_pressed("ui_down"):
		dy += cam_speed * delta

	var cp = cam.get_global_pos()
	cp.x += dx 
	cp.y += dy

	cam.set_global_pos(cp)

	# СДЕЛАТЬ ПЕРЕМЕЩЕНИЕ КАМЕРЫ С ЗАЖАТОЙ ПРАВОЙ КНОПКОЙ МЫШИ

	#var mouse_vp_pos = get_viewport().get_mouse_pos()
	#var vp_size = get_viewport_rect()
	#
	#if mouse_vp_pos.x < vp_size.pos.x + vp_size.size.width * 0.15:
	#	move_camera(-cam_speed_mouse * delta, 0)
	#elif mouse_vp_pos.x > vp_size.pos.x + vp_size.size.width * 0.85:
	#	move_camera(cam_speed_mouse * delta, 0)
	#if mouse_vp_pos.y < vp_size.pos.y + vp_size.size.height * 0.15:
	#	move_camera(0, -cam_speed_mouse * delta)
	#elif mouse_vp_pos.y > vp_size.pos.y + vp_size.size.height * 0.85:
	#	move_camera(0, cam_speed_mouse * delta)
	

func generate_map(_rooms_count, _gen_type, _gen_sub_type = null):
	var rooms_count = _rooms_count
	var gen_type = _gen_type
	var gen_sub_type = _gen_sub_type

	g.generate(rooms_count, gen_type, gen_sub_type)
	#g.generate(4 , g.TYPES.P_HOLDING_GARAGE)
	
	g.console_map()

	r.set_generator(g)
	r.generator = self

	r.render()

	var cam_max_l = -120
	var cam_max_r = g.outside_params.max_x * 60 + 40
	var cam_max_top = -50
	var cam_max_bot = g.outside_params.max_y * 40 + 10

	setup_cam_limits(cam_max_l, cam_max_r, cam_max_top, cam_max_bot)

	#setup_cam_limits(r.ex_start_x - 150, r.ex_final_x,
	#	r.ex_start_y - 100, r.ex_final_y + 200 )
	
func set_cam_pos(_pos):
	cam.set_global_pos(Vector2(_pos.x,_pos.y + 40))

func setup_cam_limits(_l, _r, _t, _b):
	cam.set_limit(MARGIN_LEFT, _l)
	cam.set_limit(MARGIN_RIGHT, _r)
	cam.set_limit(MARGIN_TOP, _t)
	cam.set_limit(MARGIN_BOTTOM, _b)

func zoom_camera(_up, _down):
	var is_up = _up
	var is_down = _down
	
	var cur_cam_zoom = cam.get_zoom()

	if is_down and cur_cam_zoom.x < cam_zoom_limits.y:
		cur_cam_zoom.x += cam_zoom_speed
		cur_cam_zoom.y += cam_zoom_speed

		if cam.get_zoom().x > cam_zoom_limits.y:
			cam.set_zoom(Vector2(cam_zoom_limits.y, cam_zoom_limits.y))

	elif is_up and cur_cam_zoom.x > cam_zoom_limits.x:
		cur_cam_zoom.x -= cam_zoom_speed
		cur_cam_zoom.y -= cam_zoom_speed
		
		if cam.get_zoom().x < cam_zoom_limits.x:
			cam.set_zoom(Vector2(cam_zoom_limits.x, cam_zoom_limits.x))

	cam.set_zoom(cur_cam_zoom)
