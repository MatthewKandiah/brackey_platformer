package textiler

import "core:fmt"
import "core:strconv"
import "core:strings"
import stbi "vendor:stb/image"

IMAGE_BASE_PATH :: "brackeys_platformer_assets/sprites/"

/*
  am I overthinking this? Would it be better to just make each spritesheet into a texture and get that working?
  the wasted space on the spritesheets wastes a little bit of memory, but the total size is so small I don't think it should be a problem
*/

// TODO-Matt: decompose input image row into separate images
// TODO-Matt: combine a set of images into a single texture image
// TODO-Matt: write uv coordinates for each sprite to a file

main :: proc() {
	decompose(IMAGE_BASE_PATH + "knight.png", "debug/knight_idle", 32, 32, 0, 4)
	decompose(IMAGE_BASE_PATH + "knight.png", "debug/knight_run_1", 32, 32, 2, 8)
	decompose(IMAGE_BASE_PATH + "knight.png", "debug/knight_run_2", 32, 32, 3, 8)
	decompose(IMAGE_BASE_PATH + "knight.png", "debug/knight_roll", 32, 32, 5, 8)
	decompose(IMAGE_BASE_PATH + "knight.png", "debug/knight_hit", 32, 32, 6, 4)
	decompose(IMAGE_BASE_PATH + "knight.png", "debug/knight_death", 32, 32, 7, 4)
	decompose(IMAGE_BASE_PATH + "coin.png", "debug/coin", 16, 16, 0, 12)
	decompose(IMAGE_BASE_PATH + "fruit.png", "debug/fruit_green", 16, 16, 0, 3)
	decompose(IMAGE_BASE_PATH + "fruit.png", "debug/fruit_yellow", 16, 16, 1, 3)
	decompose(IMAGE_BASE_PATH + "fruit.png", "debug/fruit_pink", 16, 16, 2, 3)
	decompose(IMAGE_BASE_PATH + "fruit.png", "debug/fruit_red", 16, 16, 3, 3)
	decompose(IMAGE_BASE_PATH + "platforms.png", "debug/platform_green", 16, 16, 0, 3)
	decompose(IMAGE_BASE_PATH + "platforms.png", "debug/platform_brown", 16, 16, 1, 3)
	decompose(IMAGE_BASE_PATH + "platforms.png", "debug/platform_yellow", 16, 16, 2, 3)
	decompose(IMAGE_BASE_PATH + "platforms.png", "debug/platform_blue", 16, 16, 3, 3)
	decompose(IMAGE_BASE_PATH + "slime_green.png", "debug/slime_green_1", 24, 24, 0, 4)
	decompose(IMAGE_BASE_PATH + "slime_green.png", "debug/slime_green_2", 24, 24, 1, 4)
	decompose(IMAGE_BASE_PATH + "slime_green.png", "debug/slime_green_3", 24, 24, 2, 4)
	decompose(IMAGE_BASE_PATH + "slime_purple.png", "debug/slime_purple_1", 24, 24, 0, 4)
	decompose(IMAGE_BASE_PATH + "slime_purple.png", "debug/slime_purple_2", 24, 24, 1, 4)
	decompose(IMAGE_BASE_PATH + "slime_purple.png", "debug/slime_purple_3", 24, 24, 2, 4)
	decompose(IMAGE_BASE_PATH + "world_tileset.png", "debug/world_tiles_1", 16, 16, 0, 12)
	decompose(IMAGE_BASE_PATH + "world_tileset.png", "debug/world_tiles_2", 16, 16, 1, 12)
	decompose(IMAGE_BASE_PATH + "world_tileset.png", "debug/world_tiles_3", 16, 16, 2, 12)
	decompose(IMAGE_BASE_PATH + "world_tileset.png", "debug/world_tiles_4", 16, 16, 3, 10)
	decompose(IMAGE_BASE_PATH + "world_tileset.png", "debug/world_tiles_5", 16, 16, 4, 10)
	decompose(IMAGE_BASE_PATH + "world_tileset.png", "debug/world_tiles_6", 16, 16, 5, 9)
	decompose(IMAGE_BASE_PATH + "world_tileset.png", "debug/world_tiles_7", 16, 16, 6, 9)
	decompose(IMAGE_BASE_PATH + "world_tileset.png", "debug/world_tiles_8", 16, 16, 7, 9)
	decompose(IMAGE_BASE_PATH + "world_tileset.png", "debug/world_tiles_9", 16, 16, 8, 9)
	decompose(IMAGE_BASE_PATH + "world_tileset.png", "debug/world_tiles_10", 16, 16, 9, 8)
	decompose(IMAGE_BASE_PATH + "world_tileset.png", "debug/world_tiles_11", 16, 16, 10, 7)
	decompose(IMAGE_BASE_PATH + "world_tileset.png", "debug/world_tiles_12", 16, 16, 11, 6)
	decompose(IMAGE_BASE_PATH + "world_tileset.png", "debug/world_tiles_13", 16, 16, 12, 5)
	decompose(IMAGE_BASE_PATH + "world_tileset.png", "debug/world_tiles_14", 16, 16, 13, 6)
	decompose(IMAGE_BASE_PATH + "world_tileset.png", "debug/world_tiles_15", 16, 16, 14, 5)
	decompose(IMAGE_BASE_PATH + "world_tileset.png", "debug/world_tiles_16", 16, 16, 15, 4)
}

decompose :: proc(
	original_file: cstring,
	output_file_prefix: string,
	sprite_width_pixels: u32,
	sprite_height_pixels: u32,
	row_num: u32,
	sprite_count: u32,
) {
	if sprite_count >= 100 {
		panic("ASSERT: will break my dumb output naming")
	}

	input_width, input_height, input_channel_count: i32
	input_data := stbi.load(original_file, &input_width, &input_height, &input_channel_count, 0)
	if input_data == nil {
		panic("ERROR: failed to load image")
	}
	if input_channel_count != 4 {
		panic("ASSERT: assumed 4 channel input images")
	}

	buf: [2]u8
	output_data := make([]u8, 4 * sprite_width_pixels * sprite_height_pixels)
	for sprite_idx in 0 ..< sprite_count {
		for row_idx in 0 ..< sprite_height_pixels {
			for col_idx in 0 ..< sprite_width_pixels {
				output_idx := 4 * (row_idx * sprite_width_pixels + col_idx)
				input_idx :=
					4 *
					(input_width * cast(i32)(row_num * sprite_height_pixels + row_idx) +
							cast(i32)(sprite_idx * sprite_width_pixels + col_idx))
				output_data[output_idx + 0] = input_data[input_idx + 0]
				output_data[output_idx + 1] = input_data[input_idx + 1]
				output_data[output_idx + 2] = input_data[input_idx + 2]
				output_data[output_idx + 3] = input_data[input_idx + 3]
			}
		}

		int_suffix := strconv.itoa(buf[0:2], cast(int)sprite_idx + 1)
		output_file := strings.concatenate([]string{output_file_prefix, "_", int_suffix, ".png"})
		if res := stbi.write_png(
			strings.clone_to_cstring(output_file),
			cast(i32)sprite_width_pixels,
			cast(i32)sprite_height_pixels,
			4,
			raw_data(output_data),
			4 * cast(i32)sprite_width_pixels,
		); res == 0 {
			fmt.println("output_file: ", output_file)
			panic("failed to write image to file")
		}
	}
}
