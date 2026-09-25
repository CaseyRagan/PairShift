# Art and sensory direction

## Provenance

The user supplied `/Users/caseyragan/Downloads/PairShift.png` as a visual reference. Its text and example boards are not game specifications or valid puzzle definitions. Original runtime tile materials and glyphs are drawn by `App/Rendering/TileArtwork.swift`; they remain independent from the reference bitmap.

The two raster assets below were created with the built-in imagegen tool on 2026-09-24. No CLI/API fallback was used. The source icon is preserved in `Art/Source/PairShift-Icon.png`; the app icon was mechanically resized to Apple's 1024×1024 asset size with `sips`. Artwork is stored in the repository and works offline.

### Atmosphere background

Final file: `App/Resources/Assets.xcassets/Atmosphere.imageset/Atmosphere.png`.

Final prompt:

> Use case: stylized-concept. Asset type: full-screen portrait background art for an original premium iPhone puzzle game named PairShift. Generate only the landscape, with absolutely no text, no logo, no UI, no puzzle pieces, no phone, no frames. A tranquil cinematic mountain lake at blue hour with distant sculptural misty mountains forming a natural valley, a subtle warm peach dawn glow along the low horizon, still glasslike blue water reflecting the sky. Moody deep navy, desaturated slate blue, muted dusty violet, a very small amount of warm champagne light. Sophisticated premium 3D environment/film concept art with natural photographic detail, refined not cartoonish. Portrait 2:3 composition. Upper half mostly quiet smooth dusky sky with soft atmospheric haze, horizon around 60 percent down, distant mountain silhouettes in lower middle flanking quiet water. Dark lower corners. Broad quiet central negative space so a game board can be overlaid legibly. Deliberately restrained contrast and restrained detail, the landscape gives depth without competing with interface. No fantastical structures, buildings, people, animals, particles, stars or neon. Render edge-to-edge high quality artwork.

### App icon

Final file: `App/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon.png`.

Final prompt:

> Use case: logo-brand. Asset type: square iOS app icon for original premium puzzle game PairShift. Square full-bleed 1:1 image. A meticulously rendered pair of matching luminous periwinkle-blue glass puzzle tiles on a deep midnight navy background. Exactly TWO separate dimensional softly rounded square acrylic tiles, each has the SAME small crisp embossed white diamond symbol at its center. Left tile is slightly lower; right tile slightly higher, offset diagonally but almost side-by-side. A beautiful short luminous icy blue magnetic bridge visibly connects the tiles' nearest side edges. Tile top faces almost front-facing, just a tiny perspective tilt, strong legible silhouette at tiny size. Frosted glass internal material, restrained beveled edges, white top-left edge highlights and soft soft blue underglow. Fill roughly 75 percent of square with symbol. Premium tactile physical puzzle object, sophisticated and clean, subtle cinematic studio lighting, slight ambient contact shadow. Background flat/deep ink navy with a soft radial blue pool, full bleed. No text, no letters, no numbers, no extra tiles, no stars, no scenery, no outer rounded app-icon mask, no frame, no watermark, no overly bright bloom. Icon should feel engineered, serene and original. Highest craft.

## Runtime material system

Six immutable pair identities: blue circle, coral star, gold triangle, jade diamond, violet crescent, cyan wave. Shapes reinforce color. Materials are cached by pair/appearance/bond state. Swipes animate to authoritative engine snapshots; rendered contact cannot change a puzzle outcome. Short connection accents and a completion ripple reinforce state. Reduced motion snaps pieces into place and clears transient effects.

Backdrop art stays static. SpriteKit suppresses unchanged drawing after its animation window and pauses while sheets/background cover gameplay. Every foreground/appearance transition redraws the final authoritative snapshot.

## Sound

Original PCM clicks/chimes are synthesized locally, cached, and played with an ambient audio session that respects the silent switch. Short haptic transients distinguish a bond and completion; supported devices use Core Haptics with UIKit fallback. Simulator sound can be checked; physical feel and final sound balance require the iPhone 15 playtest.
