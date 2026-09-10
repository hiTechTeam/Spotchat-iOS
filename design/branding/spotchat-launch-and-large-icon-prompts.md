# Larger app icon and themed launch screen

Mode: built-in imagegen edits of `spotchat-app-icon-filled-1024.png`.

The larger app icon is saved as `spotchat-app-icon-filled-large-1024.png` and used by both iOS app-icon entries. The generated image was resampled to 1024 px, then its canvas cropped to 1007 px and resampled back to 1024 px to match the requested 15% increase in the blue silhouette width.

The launch logo is saved in `bitchat/Assets.xcassets/SpotchatLaunchLogo.imageset/spotchat-launch-logo.png`. Its exterior is transparent; the blue fill and white lettering stay the same in both themes. The launch storyboard uses systemBackgroundColor underneath it, giving a white or black background according to the system theme.

## App-icon prompt

Precise edit of this production app icon: enlarge the entire existing blue filled circular speech bubble WITH its white Spotchat lettering by 15% around the center of the square canvas. Only change the scale, preserve EXACT lettering, proportions, blue color, white background, tail silhouette and relative positions. The current bubble spans about 76% of the canvas width; the enlarged bubble must span about 87% of the canvas width with approximately 6.5% white padding on each side. Remain fully visible, no clipping. Pure opaque white full-bleed square background, no rounded square frame, no shadows, no textures, no gradients, no additional elements. Output one square PNG.

## Launch-logo prompt

Background extraction of the exact supplied Spotchat logo for an iOS launch screen. Remove ONLY the white background OUTSIDE the blue filled circular speech bubble and replace it with genuine alpha transparency. Preserve the blue bubble, lower-left tail, white Spotchat letters, typography, position, proportions, color and size exactly. The white letters INSIDE the blue bubble must remain solid opaque white. Outside the bubble must be fully transparent, no white halo, no background rectangle, no checkerboard baked into the image. No added shadows, glow, text, gradients or other changes. Output one transparent PNG square.
