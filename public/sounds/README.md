# Game Sounds

Place sound files here. They'll be accessible at `/sounds/filename.mp3`.

## Recommended Structure

```
sounds/
├── ui/           # UI interaction sounds
│   ├── click.mp3
│   ├── hover.mp3
│   └── error.mp3
├── notifications/
│   ├── message.mp3
│   └── alert.mp3
├── actions/      # Game action sounds
│   ├── mine.mp3
│   ├── trade.mp3
│   └── warp.mp3
└── ambient/      # Background/ambient sounds
    └── station.mp3
```

## Usage in Views

```erb
<%# One-shot sound on button click %>
<button data-controller="audio" 
        data-audio-src-value="/sounds/ui/click.mp3"
        data-action="click->audio#play">
  Click Me
</button>

<%# Auto-play sound when element appears (e.g., via Turbo Stream) %>
<div data-controller="audio" 
     data-audio-src-value="/sounds/notifications/alert.mp3"
     data-audio-autoplay-value="true">
</div>

<%# Adjust volume (0.0 to 1.0) %>
<div data-controller="audio" 
     data-audio-src-value="/sounds/ui/click.mp3"
     data-audio-volume-value="0.3">
</div>
```

## Turbo Stream Integration

To play sounds from server actions, append an audio element via Turbo Stream:

```erb
<%= turbo_stream.append "sounds" do %>
  <div data-controller="audio" 
       data-audio-src-value="/sounds/notifications/message.mp3"
       data-audio-autoplay-value="true">
  </div>
<% end %>
```

Add a sounds container to your layout:
```erb
<div id="sounds"></div>
```
