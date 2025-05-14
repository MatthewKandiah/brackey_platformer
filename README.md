# TODO
- add a uniform buffer object for camera pos and zoom
- move world->screen coordinate mapping to vertex shader
- crazy screen tearing when moving camera around, google how to fix

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
