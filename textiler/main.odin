package textiler

import "core:fmt"
import "core:strconv"
import "core:strings"
import stbi "vendor:stb/image"

IMAGE_BASE_PATH :: "brackeys_platformer_assets/sprites/"

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
}

// TODO-Matt: trim empty margin around sprite
// don't think we can automate this, we could trim to the smallest quad we can by trimming completely transparent rows and columns, but I'm planning to render entities with a fixed sized quad which we'll apply these textures to. If an entity ducks, we want a texture with some transparent space at the top of it. If we trim that empty space, the ducking sprite will stretch upwards to fill the quad and it will look broken!
// so probably need to pass in margin-top,bottom,left,right ?
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
			for byte_idx in 0 ..< 4 * sprite_width_pixels {
				output_idx := 4 * (row_idx * sprite_width_pixels) + byte_idx
				input_idx :=
					4 * input_width * cast(i32)(row_num * sprite_height_pixels + row_idx) +
					4 * cast(i32)(sprite_idx * sprite_width_pixels) +
					cast(i32)byte_idx
				output_data[output_idx] = input_data[input_idx]
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
