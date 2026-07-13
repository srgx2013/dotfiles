#!/bin/bash
# SKHD: Focus next DIFFERENT app in the current space
# Salta ventanas de la misma app, solo cambia entre apps distintas

CURRENT_APP=$(yabai -m query --windows --window | jq -r '.app')
CURRENT_SPACE=$(yabai -m query --windows --window | jq -r '.space')

NEXT_WINDOW=$(yabai -m query --windows --space "$CURRENT_SPACE" | jq -r \
  "[.[] | select(.app != \"$CURRENT_APP\")] | first | .id")

if [ -n "$NEXT_WINDOW" ] && [ "$NEXT_WINDOW" != "null" ]; then
  yabai -m window --focus "$NEXT_WINDOW"
else
  # Si no hay otra app, quedate donde estás
  exit 0
fi
