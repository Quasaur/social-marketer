# AVFoundation Video Effects

This document catalogs the approved video effects for YouTube Shorts and TikTok videos generated from Social Marketer.

## Selected Effects (10 Total)

### Intro Transitions (Choose One)

These effects introduce the quote at the beginning of the video.

1. **Cross-Dissolve** - Fade in from black, smooth and elegant
2. **Zoom Expand** - Content expands from center point (0 to 1 scale)
3. **Wipe** - Left to right reveal
4. **Card Flip H** - Horizontal card flip rotation (simulated 3D)

### Ongoing/Ambient Effects (Can Layer Multiple)

These effects run throughout the video to add visual interest.

1. **Particles** - Falling snow particles (50 particles, varying sizes 2-6px, alpha 0.3-0.8)
2. **Light Leaks** - Golden light sweep moving diagonally across screen
3. **Word Reveal** - Words appear progressively one by one
4. **Cube Rotate** - Quote rotates in simulated 3D space (multi-axis rotation)

### Outro Transitions (Choose One)

These effects close out the video.

1. **Circular Collapse** - Content shrinks into center circle, fading to black
2. **Blinds** - Venetian blinds closing effect (5-7 slats, not 15)

## Effects Rejected

- Slide Reveal - Too weird/jarring
- Page Curl - Not effective
- Perspective Tilt - Too subtle/confusing
- Card Flip V - Horizontal flip preferred

## Effect Combinations

### Best Practices

**Intro combos (choose ONE intro):**

- Cross-Dissolve + Word Reveal (elegant)
- Zoom Expand + Particles (dramatic)
- Wipe + Light Leaks (dynamic)
- Card Flip H (bold, stands alone)

**Ongoing effects (can layer multiple):**

- Particles + Light Leaks ✓
- Word Reveal + Light Leaks ✓
- Particles + Cube Rotate ✓

**Outro combos (choose ONE outro):**

- Circular Collapse (clean)
- Blinds (stylish)

### Example Combinations

1. **Elegant**: Cross-Dissolve → Word Reveal + Light Leaks → Circular Collapse
2. **Energetic**: Zoom Expand → Particles + Light Leaks → Blinds
3. **Bold**: Card Flip H → Word Reveal + Particles → Circular Collapse
4. **Polished**: Wipe → Light Leaks + Word Reveal → Blinds

## Implementation Notes

- All videos should be 3 seconds (90 frames @ 30fps)
- Format: 1080x1920 (vertical for Shorts/TikTok)
- Text should have 60px safe margins
- Always include "wisdombook.life" watermark
- Quote graphics should use border styles from existing gallery
- Use CoreText for text rendering in CGContext
- Zoom effects should zoom OUT (1.2x → 1.0x) not IN
