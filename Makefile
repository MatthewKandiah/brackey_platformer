default: run-debug

run: build
	./main.bin

run-debug: build-debug
	./main.bin

build:
	odin build main
	glslc shaders/shader.vert -o vert.spv
	glslc shaders/shader.frag -o frag.spv

build-debug:
	odin build main -debug
	glslc shaders/shader.vert -g -o vert.spv
	glslc shaders/shader.frag -g -o frag.spv

clean:
	rm main.bin
