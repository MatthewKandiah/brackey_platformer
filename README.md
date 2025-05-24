# TODO
- die when you fall too far
- sounds - beep on jump, on coin collected, on death
- more interesting map to jump around
- fix collision detection - my cutting corners idea has fixed the weirdness where unwanted horizontal collisions stopped you walking on a flat surface, but now the gaps in the collision box mean you can get your character stuck e.g. by falling down a wall with your left collision check to the left of the wall and the leftmost point of your bottom collision check to the right of the wall. Probably need to include checks for the lines between the current segments, not immediately sure how you should handle those collisions though?
- collectible coins that vanish when you collide with them

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
