#!/bin/bash
# https://unix.stackexchange.com/questions/550106/cant-use-different-font-families-in-groff-ms

set -e

mkdir -p /tmp/font/devps
cd  /tmp/font/devps

afmtodit /usr/share/fonts/X11/Type1/l048013t.afm textmap LUXSR
afmtodit /usr/share/fonts/X11/Type1/l048016t.afm textmap LUXSB
afmtodit /usr/share/fonts/X11/Type1/l048033t.afm textmap LUXSI
afmtodit /usr/share/fonts/X11/Type1/l048036t.afm textmap LUXSBI
#export GROFF_FONT_PATH=/tmp/font
