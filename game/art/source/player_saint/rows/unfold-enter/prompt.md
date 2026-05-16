Use case: stylized-concept
Asset type: 128x128 transparent source frames for player_saint animation row `unfold-enter`
Primary request: Six-frame transition where the body is pressed flatter by coordinate lines and locked into an unfold state.
Style: match the already integrated `player_saint` idle/run atlas identity while adding restrained cyan coordinate-grid overlays.
Action: frame 0 begins upright and readable; frames 1-4 progressively compress the body vertically and widen it slightly; frame 5 settles into a flattened locked plane.
Constraints: no held sword, no attack pose, coordinate lines stay dim enough to avoid becoming a light blob, no text or watermark, transparent background, stable center anchor.
Reverse-use note: the sequence is monotonic and does not rely on one-way debris, so it is intended to be suitable for reverse playback as `unfold-exit`.
