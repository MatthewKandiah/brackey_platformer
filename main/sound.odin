package main

import ma "vendor:miniaudio"

init_sound :: proc() -> ^ma.engine {
	engine := new(ma.engine)
  ma.engine_init(nil, engine)
	return engine
}
