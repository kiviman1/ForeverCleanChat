# Theme artwork

The user supplied an interface reference showing a dark panel, an ornate gold
frame and a shield containing a speech bubble. The following project assets
were created with the built-in image generation tool from that reference.
The tool was used for artwork creation; Python/Pillow only exports the selected
artwork to power-of-two, uncompressed 32-bit RGBA TGA textures for the game.
Transparency is preserved. No reference text, sample counters or interactive
controls are baked into the artwork.

- `Frame.tga`: 1024 × 1024, blank dark leather panel and ornate gold perimeter.
- `Emblem.tga`: 256 × 256, gold speech-bubble shield, transparent surroundings.

## Frame prompt

Edit the provided image to create a production raster UI texture asset for the Forever Clean Chat game addon, not a mockup. Extract and recreate ONLY the ornate antique gold outer rectangular frame and its continuous near-black subtly worn leather/stone interior from the reference. Remove ALL text, emblem, status lamp, buttons, inner cards, close button, HUD, world background and captions. The result is one completely blank dark textured panel enclosed in the same narrow angular gold fantasy frame, centered and facing exactly front-on with square proportions, 1024x1024 if possible. The gold perimeter should sit within approximately 8 pixels of the image edge, with no large exterior padding. Preserve the tasteful bevels, fine gold double lines, angular corner flourishes and subtle small central top ornament, no added objects. Interior should be near black (#111111), quiet enough for readable cream native UI text later; no patterns or illuminated regions. Outside the outline of the frame is genuine alpha transparency, with a very small soft shadow. All interior is opaque. No typography, symbols, watermarks or checkerboard baked in. This image will be reencoded without pixel changes into a WoW .tga and stretched to 760x724; keep border thin and corners crisp.

## Emblem prompt

Use the reference ONLY for visual style. Create one production game UI emblem asset: the gold edged dark shield containing a raised gold speech bubble with three round black dots, closely matching the reference emblem at the upper left. Standalone centered shield, front-on, rich antique-gold thin double bevel outline, pointed lower shield, near-black graphite face, large gold rounded chat balloon with small lower-left tail and three inset dark circular dots. Ornate restrained MMORPG craftsmanship and subtle metal highlights, readable at 24px minimap and 90px panel sizes. The entire shield occupies about 90 percent of a square image; no huge padding. Genuine alpha transparent background outside shield, no environment, no frame, no text/letters/title/watermark, no extra objects. One emblem only, no variants, no contact sheet. A clean square PNG intended for technical export as 256x256 RGBA TGA.
