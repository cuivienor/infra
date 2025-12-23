#!/bin/sh
xrandr --output HDMI-A-1 --off \
	--output DisplayPort-1 --mode 3440x1440 --pos 0x0 --rotate left \
	--output HDMI-A-0 --mode 3840x2160 --pos 4000x752 --scale 0.7x0.7 --rotate right \
	--output DisplayPort-0 --primary --mode 2560x1440 --pos 1440x905 --rotate normal
