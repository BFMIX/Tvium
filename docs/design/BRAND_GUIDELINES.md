# Tvium UI Branding Guidelines

## Official product name
Use **Tvium** exactly. Only the `T` is uppercase.

## Official visual reference
Use the local branding kit source and the four validated mockups as the visual direction:

- Home
- Live TV
- Movies
- TV Shows

## Locked header rules
- Use the validated Tvium logo.
- Place the logo in the center of the capsule header on TV and desktop.
- Left of logo: Home, Live TV.
- Right of logo: Movies, TV Shows.
- Right global actions outside nav capsule: Search, Settings, Time/Date, Profile.
- Do not add divider bars between menu items.
- Use spacing only.
- Active destination uses a cyan glowing pill.

## Visual direction
Tvium must feel premium, cinematic, dark, calm and TV-first.

Use:
- dark navy and graphite backgrounds;
- restrained cyan accent;
- blurred cinematic backgrounds behind content;
- strong but not excessive focus states;
- readable text from TV distance;
- content-first hierarchy.

Avoid:
- generic IPTV dashboards;
- excessive rectangles and stacked containers;
- overly crowded screens;
- too much glow;
- tiny metadata;
- real copyrighted movie posters or real channel logos in deliverables.

## Color tokens
- Background: `#071320`
- Background 2: `#0A1A2A`
- Surface: `#102338`
- Surface elevated: `#162C44`
- Tvium cyan: `#24D9FF`
- Cyan deep: `#00B7FF`
- Text primary: `#F3F7FF`
- Text muted: `#A9B7C8`
- Amber: `#FFCA5A`
- Live red: `#FF4E68`

## Screen notes

### Home
- Hero from user library.
- Three shortcut cards: Live TV, Movies, TV Shows.
- Rails only when populated.
- Keep the page spacious.

### Live TV
- Avoid a basic IPTV channel table.
- Use an original layout:
  - country carousel with flags;
  - category rail under/near selected country;
  - stylized channel stack;
  - integrated player preview on the right.
- Preview should feel blended into the background, not a box inside many boxes.

### Movies
- Poster ratio is mandatory.
- Continue Watching must appear above Popular Movies.
- Use category chips and hero content.
- Do not invent missing metadata.

### TV Shows
- Same visual language as Movies.
- Emphasize series, seasons, episodes and resume-next-episode.
- Handle incomplete metadata gracefully.

## Component inventory
- TviumHeader
- HeroBanner
- SectionShortcutCard
- PosterTile
- ContinueWatchingCard
- CountryCarousel
- CategoryRail
- ChannelStackItem
- PlayerPreview
- FocusableSurface
- QualityBadge
- ProgressBar
- EmptyState
- ErrorState
- LoadingSkeleton

## TV behavior
Every interactive component needs normal, hover, pressed, focused, selected, disabled and loading states.

D-pad behavior:
- left/right changes panes or rails;
- up/down moves within a pane;
- Back closes the top overlay first;
- focus returns to the element that opened the overlay.

## Privacy
Never show credentials, usernames, passwords, tokens, full playlist URLs, full stream URLs or server addresses in normal UI, errors or screenshots.
