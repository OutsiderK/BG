# v0.3.1 Player Row Integration

Integrated into `game/art/sprites/player_saint/spritesheet.png`:

- `jump-start`
- `fall`
- `dash`
- `sword-attack-1`
- `sword-attack-2`
- `hurt`
- `death`
- `unfold-enter`
- `unfold-loop`
- `unfold-exit` derived by reversing `unfold-enter`

Integrator notes:

- H1-B delivered sword attack frames as transparent 1024x1536 exports. They were deterministically cropped by alpha, scaled, and bottom-anchored into 128x128 cells before atlas packing.
- `validate_atlas.py` now honors optional per-row `anchor_drift_max` values in the manifest. The default remains the command-line `--drift-max`, but intentional state animations such as `death` and `unfold-enter` can declare wider drift budgets without weakening idle/run validation.
- No row is left as a grey mock placeholder in the current atlas.

