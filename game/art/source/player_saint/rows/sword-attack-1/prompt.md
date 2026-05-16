Use case: stylized-concept
Asset type: source animation frames for `player_saint/sword-attack-1`
Primary request: Six transparent full-body source frames for the protagonist's first sword attack.

Reference identity:
Match `game/art/source/player_saint/base_v0_3.png`: anonymous masked face, off-white thin cloak, dark blue-gray inner clothing, restrained silhouette, small muted gold stigma accents, pale cyan coordinate traces.

Action:
Right-facing horizontal slash that can be mirrored later by `set_facing()`. Frame 0 is anticipation, frame 1 prepares the cut, frame 2 begins the hit, frame 3 carries the horizontal cut, frame 4 ends the hit and starts recovery, frame 5 settles.

Frame events:
- hit_start_frame: 2
- hit_end_frame: 4

Constraints:
Use only a plain physical sword blade. Do not draw a large attack arc, slash trail, magic trail, text, watermark, church crest, cross, plus-shaped holy symbol, gold cape, face cross mark, or UI overlay.
