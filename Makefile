build: build-textiler build-main

run: build
	./textiler.bin
	./main.bin

build-textiler:
	odin build textiler

build-main:
	odin build main

clean:
	rm main.bin
	rm textiler.bin
