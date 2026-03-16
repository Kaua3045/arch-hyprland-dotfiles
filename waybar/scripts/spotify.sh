#!/bin/bash

status=$(playerctl status 2>/dev/null)

if [ -z "$status" ]; then
    echo "404 not found"
    exit 0
fi

artist=$(playerctl metadata artist 2>/dev/null)
title=$(playerctl metadata title 2>/dev/null)

if [ "$status" = "Playing" ]; then
    icon="tocando"
else
    icon="pausado"
fi

text="$icon $artist - $title"

max=45
if [ ${#text} -gt $max ]; then
    text="${text:0:max}..."
fi
echo "$text"