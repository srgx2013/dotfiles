#!/bin/bash
# SKHD: Focus previous DIFFERENT app in the current space
# Hacia atrás en el orden de ventanas

CURRENT_APP=$(yabai -m query --windows --window | jq -r '.app')
CURRENT_SPACE=$(yabai -m query --windows --window | jq -r '.space')

PREV_WINDOW=$(yabai -m query --windows --space "$CURRENT_SPACE" | jq -r \
  "[reverse[] | select(.app != \"$CURRENT_APP\")] | first | .id")

if [ -n "$PREV_WINDOW" ] && [ "$PREV_WINDOW" != "null" ]; then
  yabai -m window --focus "$PREV_WINDOW"
else
  exit 0
fi
