# Godot_Networked_Boilerplate
 Boilerplate setup for a networked game in Godot that comes with a Main Menu and the ability to host via UPnP and join via IP Address.  
 2D/3D agnostic
 <br>
 <br>

# Structure

## Flow
- Entry point is `Main.tscn`
- Host will spawn its' own levels and add them to the `SceneTree`
- Clients get their level's spawned through the `Autoload` `LevelManager` that has a `MultiplayerSpawner` `Node`
- The `Autoload` `Transition.tscn` fades to black and fades in when levels are switching

## Autoloads
- `LevelManager.tscn`
  - Responsible for spawning levels and removing previous levels through a `MultiplayerSpawner` (named `LevelSpawner`)
  - Listens for a `finished_level` `signal` attached to the level it spawns to determine when to switch levels
- `Transition.tscn`
  - Responisble for transitioning the screen to hide level cleanup and creation
  - Has a `TextureRect` which fades to black and fades in when levels are switching
- `AudioManager.tscn`
  - Responsible for music and sfx
  - Has 3 Buses:
	- Master
	- Music
	- SFX
  - Has an `AudioStreamPlayer` for music by default with no music attached
  - Unmutes the Audio Buses when exported

## Creating Levels
  - Add your level scenes to the `LevelStore` `Resource` file `res://resources/StandardLevels.tres`
  - The level being spawned should have a top level script that emits a `finished_level` `signal` when players finish a level
	- once this `signal` is emitted then it will proceed to the next level
  - You can create another `LevelStore` for levels you are testing and adjust the `level_store` variable in `LevelManager.gd`
	- Note: You can export the `level_store` variable for more of an editor workflow

## Doesn't Include
- Player scripts or spawning
- Tracking Game State

## Credits
- Based on [DevLogLogan](https://www.youtube.com/@DevLogLogan)'s youtube video [Godot 4 - Online Multiplayer FPS From Scratch](https://www.youtube.com/watch?v=n8D3vEx7NAE)
- SFX from [Kenney](https://www.kenney.nl/)
