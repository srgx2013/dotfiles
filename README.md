# Dotfiles — macOS Window Management

Configuración y scripts de auto-arranque para yabai, skhd, y sketchybar en macOS.

## Estructura
```
local/bin/          — Scripts de health check y auto-arranque
config/
  yabai/yabairc     — Config de tiling (bsp)
  skhd/skhdrc       — Atajos de teclado
  sketchybar/sketchybarrc — Config de la barra
Applications/       — .app wrappers (protegen permisos TCC)
Library/LaunchAgents/ — Watchdog de yabai
```

## Notas
- Los `.app` wrappers existen para proteger permisos de Accessibility en macOS 26.x
- Los check scripts usan `open --args --config` para que LaunchServices atribuya TCC al .app
- yabai no necesita wrapper (tiene firma propia)
