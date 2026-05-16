# player_saint source rows

Source-only 128x128 transparent animation frames for rows reserved in `game/art/sprites/player_saint/manifest.json`.

- `jump-start`: 4 frames, crouch/compress into first airborne frame.
- `fall`: 4 frames, loopable downward posture without attack or hurt read.
- `dash`: 4 frames, forward lean with restrained afterimage while keeping the main silhouette readable.
- `sword-attack-1`: 6 frames, plain blade, hit starts on frame 2 and ends on frame 4.
- `sword-attack-2`: 6 frames, plain blade follow-up, hit starts on frame 2 and ends on frame 4.
- `hurt`: 4 frames, short recoil with restrained white-flash read.
- `death`: 8 frames, coordinate-wear collapse without gore.
- `unfold-enter`: 6 frames, coordinate compression/lock-in.
- `unfold-loop`: 4 frames, loopable flattened hover.

These files are source deliverables. The packed runtime atlas lives at
`game/art/sprites/player_saint/spritesheet.png`.
