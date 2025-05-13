# Debugging
Seeing artefacts where random clusters of pixels are transparent, when they should be colours from sampled texture
Things I've checked:
- setting the colours to positions makes it render fine => vertex data is fine, quads are all lined up as expected
- inspected the fragment shader inputs in renderdoc => fragment shader tex_idx and tex_pos inputs look fine for each vertex
- disabling blending doesn't fix it => it isn't my blend operation misbehaving

Things I've found:
- renderdoc doesn't show the third texture as an `input` for the captured frame in the texture viewer. It does show it as expected in the descriptor set though
- resizing the window changes the position, size, and number of transparent artefacts. For a given window size, they seem to generate consistently though

# TODO
- how do we draw a square so that it is actually square? 
- how do we define our game entities in "world space" and map that to "screen space"?

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
