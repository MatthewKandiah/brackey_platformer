# TODO
- animate a coin using the coin.png spritesheet, think I'll need to create a second image and bind an array of image samplers to my fragment shader, and send the index of which sampler to use through in the vertex data

# Platformer
Let's build a more thought through game using [Brackeys' Platformer Bundle](https://brackeysgames.itch.io/brackeys-platformer-bundle)

# Design
- Mario ripoff basically
- Character can move left, move right, and jump
- Enemy slimes move left and right until they bounce off an obstacle, die when player jumps on them
- Player dies if they hit an enemy
- Win a level by collecting all the coins
- Camera centres the player as they move around
- Level defined as a tile map including initial positions for slimes and coins

# Plan
- Want to turn the various sprite assets into a single texture image. Think it might be best to first split the spritesheets into separate images, use a sensible naming convention to group and order animation sequences, then pack them into a single texture image and output the uv coordinates for each image to a file to be read in by the main file
- Want to render text too, probably going to use a similar strategy to the image spritesheets. Generate an image for each character we need (A-Z, 0-9, some basic punctuation) and pack into that same texture image, outputting uv coordinates to file (or possibly output to a different texture, intended to be used with an override colour, so we can write text in different colours easily?)
- Use unnormalised coordinate texture, nearest-neighbor interpolation and zero anti-aliasing for neat sprite drawing
- Draw a guy going through an idle animatino on the screen, then work out how we're going to do everything else from there
