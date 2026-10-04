#!/bin/sh
# usage: install.sh [-y] [aro] [hyprland] [niri]
#   no compositors: asks which ones, and how to set them up
#   -y: no questions, the defaults for every compositor found
set -eu
here=$(cd "$(dirname "$0")" && pwd)
conf=${XDG_CONFIG_HOME:-$HOME/.config}
bin=$HOME/.local/bin

if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
	B=$(printf '\033[1m') D=$(printf '\033[2m') N=$(printf '\033[0m')
	BLUE=$(printf '\033[34m') CYAN=$(printf '\033[36m') GREEN=$(printf '\033[32m')
	YELLOW=$(printf '\033[33m') RED=$(printf '\033[31m')
else
	B='' D='' N='' BLUE='' CYAN='' GREEN='' YELLOW='' RED=''
fi
title() { printf '\n%s%s%s\n' "$B$BLUE" "$1" "$N"; }
info() { printf '  %s\n' "$1"; }
ok() { printf '  %s✓%s %s\n' "$GREEN" "$N" "$1"; }
warn() { printf '  %s!%s %s\n' "$YELLOW" "$N" "$1" >&2; }
die() { printf '%serror:%s %s\n' "$RED$B" "$N" "$1" >&2; exit 2; }

# ask VAR "question" default
ask() {
	printf '  %s?%s %s %s[%s]%s ' "$CYAN" "$N" "$2" "$D" "$3" "$N"
	read -r ans || ans=
	eval "$1=\${ans:-\$3}"
}
# confirm VAR "question" y|n
confirm() {
	ask _yn "$2" "$3"
	case $_yn in [Yy]*) eval "$1=1" ;; *) eval "$1=" ;; esac
}
# choose VAR "question" default option...
choose() {
	_var=$1 _q=$2 _def=$3
	shift 3
	_i=1
	for _o in "$@"; do
		printf '    %s%d)%s %s\n' "$D" "$_i" "$N" "$_o"
		_i=$((_i + 1))
	done
	while :; do
		ask _pick "$_q" "$_def"
		_i=1
		for _o in "$@"; do
			if [ "$_pick" = "$_i" ] || [ "$_pick" = "$_o" ]; then
				eval "$_var=\$_o"
				return
			fi
			_i=$((_i + 1))
		done
		warn "pick a number from 1 to $#, or a name"
	done
}

# installed paths, so reinstalls don't back up our own files
mark=${XDG_STATE_HOME:-$HOME/.local/state}/kon/installed
mkdir -p "$(dirname "$mark")"
touch "$mark"

put() {
	if grep -qxF "$2" "$mark" || [ -e "$2.pre-kon" ] || [ -L "$2.pre-kon" ]; then
		rm -rf "$2"
	elif [ -e "$2" ] || [ -L "$2" ]; then
		mv "$2" "$2.pre-kon"
	fi
	mkdir -p "$(dirname "$2")"
	cp -r "$1" "$2"
	grep -qxF "$2" "$mark" || echo "$2" >> "$mark"
}

# what hyprland will start from: theirs, an older kon's, the default, or nothing usable
hypr_state() {
	h=$conf/hypr
	if [ -f "$h/hyprland.lua" ]; then
		if grep -q 'qs -c aroclip -d' "$h/hyprland.lua" && ! grep -q 'require("kon-aero")' "$h/hyprland.lua"; then
			echo old
		else
			echo theirs
		fi
	elif [ -f "$h/hyprland.conf" ]; then
		echo conf
	else
		echo default
	fi
}

# hyprland: keep the user's hyprland.lua, or start from hyprland's own, and load the rice from it
hypr() {
	h=$conf/hypr
	state=$(hypr_state)
	if [ "$state" = conf ]; then
		warn "skipping hyprland: it needs a hyprland.lua (hyprland 0.56+), and you have hyprland.conf"
		return
	fi
	mkdir -p "$h"
	cp "$here/config/hypr/kon-aero.lua" "$here/config/hypr/kon.lua" "$h/"
	if [ "$state" = old ]; then
		[ -e "$h/hyprland.lua.pre-kon" ] || cp "$h/hyprland.lua" "$h/hyprland.lua.pre-kon"
		rm "$h/hyprland.lua"
		warn "replaced the old kon hyprland.lua, yours is hyprland.lua.pre-kon"
		state=default
	fi
	if [ "$state" = theirs ]; then
		[ -e "$h/hyprland.lua.pre-kon" ] || grep -q 'require("kon-aero")' "$h/hyprland.lua" ||
			cp "$h/hyprland.lua" "$h/hyprland.lua.pre-kon"
		if [ "$hypr_layout" = keep ]; then
			rm -f "$h/kon-layout.lua"
		else
			printf 'hl.config({ general = { layout = "%s" } })\n' "$hypr_layout" > "$h/kon-layout.lua"
		fi
	else
		if [ -f /usr/share/hypr/hyprland.lua ]; then
			cp /usr/share/hypr/hyprland.lua "$h/hyprland.lua"
		else
			v=$(Hyprland --version 2>/dev/null | sed -n 's/^Hyprland \([0-9.]*\).*/\1/p' | head -1)
			ref=main
			[ -n "$v" ] && ref=v$v
			curl -sf "https://raw.githubusercontent.com/hyprwm/Hyprland/$ref/example/hyprland.lua" -o "$h/hyprland.lua" || {
				warn "couldn't get hyprland's default config, skipping hyprland"
				rm -f "$h/hyprland.lua"
				return
			}
		fi
		layout=$hypr_layout
		[ "$layout" = keep ] && layout=dwindle
		sed -i -e 's/^local terminal *= *"kitty"/local terminal    = "foot"/' \
			-e 's/^local menu *= *"hyprlauncher"/local menu        = "fuzzel"/' \
			-e "s/^\\( *scale *= *\\)\"auto\",/\\1$hypr_scale,/" \
			-e "s/^\\( *layout *= *\\)\"dwindle\",/\\1\"$layout\",/" "$h/hyprland.lua"
		[ -n "$kb" ] && sed -i "s/^\\( *kb_layout *= *\\)\"us\",/\\1\"$kb\",/" "$h/hyprland.lua"
	fi
	grep -q '^require("kon-aero")$' "$h/hyprland.lua" || printf '\nrequire("kon-aero")\n' >> "$h/hyprland.lua"
	ok "hyprland"
}

# choices
interactive=1
wms=
for a in "$@"; do
	case $a in
	-y|--yes) interactive= ;;
	-h|--help) sed -n '2,4s/^# \{0,1\}//p' "$0"; exit 0 ;;
	aro|hyprland|niri) wms="$wms $a"; interactive= ;;
	*) die "unknown option or compositor: $a (aro, hyprland, niri, -y)" ;;
	esac
done
[ -n "$interactive" ] && [ ! -t 0 ] && die "no terminal to ask in; pass the compositors (aro, hyprland, niri) or -y"

found=
command -v aro >/dev/null && found="$found aro"
command -v Hyprland >/dev/null && found="$found hyprland"
command -v niri >/dev/null && found="$found niri"

aro_layout=scroll hypr_layout=keep hypr_scale=1 kb='' city='' lat='' lon='' snow=1 wall=''
[ "$(hypr_state)" = theirs ] || hypr_layout=dwindle

if [ -n "$interactive" ]; then
	printf '%s%skon%s %s· a frutiger aero rice for aro, hyprland and niri%s\n' "$B" "$BLUE" "$N" "$D" "$N"

	title "Compositors"
	[ -n "$found" ] || die "none of aro, hyprland or niri is installed"
	for wm in aro hyprland niri; do
		case " $found " in
		*" $wm "*) confirm pick "Set up $wm?" y; [ -n "$pick" ] && wms="$wms $wm" ;;
		*) info "${D}$wm isn't installed, skipping$N" ;;
		esac
	done
	[ -n "$wms" ] || die "nothing to install"

	case " $wms " in *" aro "*)
		title "aro"
		choose aro_layout "Window layout" scroll scroll dwindle manual monocle ;;
	esac
	case " $wms " in *" hyprland "*)
		title "Hyprland"
		case $(hypr_state) in
		theirs)
			info "your hyprland.lua stays, the rice is added to it"
			choose hypr_layout "Window layout" keep keep dwindle master scrolling ;;
		conf)
			warn "you have a hyprland.conf; the rice needs a hyprland.lua, so hyprland will be skipped" ;;
		*)
			info "starting from hyprland's default config"
			choose hypr_layout "Window layout" dwindle dwindle master scrolling
			ask hypr_scale "Monitor scale" 1 ;;
		esac ;;
	esac

	title "Keyboard"
	cur=$(localectl status 2>/dev/null | sed -n 's/.*X11 Layout: *//p')
	case $cur in ''|'(unset)'|n/a) cur=us ;; esac
	ask kb "Keyboard layout (xkb, e.g. us, br, de)" "${cur:-us}"

	title "Weather"
	while :; do
		ask city "City for the weather gadget, empty to follow your IP" ""
		[ -z "$city" ] && break
		q=$(printf '%s' "$city" | sed 's/ /%20/g')
		hit=$(curl -sf --max-time 10 "https://geocoding-api.open-meteo.com/v1/search?name=$q&count=1&format=json" |
			python3 -c 'import json,sys; r=json.load(sys.stdin).get("results") or [{}]; r=r[0]
print(r.get("name",""), r.get("country_code",""), r.get("latitude",""), r.get("longitude",""), sep="|")' 2>/dev/null || true)
		name=${hit%%|*}
		if [ -n "$name" ]; then
			rest=${hit#*|}; cc=${rest%%|*}; rest=${rest#*|}; lat=${rest%%|*}; lon=${rest#*|}
			city="$name, $cc"
			ok "found $city ($lat, $lon)"
			break
		fi
		warn "couldn't find \"$city\", try another spelling"
	done

	title "Desktop"
	confirm snow "Falling snow?" y
	while :; do
		ask wall "Wallpaper image, empty for none" ""
		wall=$(printf '%s' "$wall" | sed "s|^~|$HOME|")
		[ -z "$wall" ] || [ -f "$wall" ] && break
		warn "no such file: $wall"
	done

	title "Summary"
	info "compositors: ${B}${wms# }${N}"
	case " $wms " in *" aro "*) info "aro layout: $aro_layout" ;; esac
	case " $wms " in *" hyprland "*) info "hyprland layout: $hypr_layout, scale: $hypr_scale" ;; esac
	info "keyboard: $kb"
	info "weather: ${city:-from your IP}"
	info "snow: $([ -n "$snow" ] && echo on || echo off)"
	info "wallpaper: ${wall:-none}"
	info "${D}anything replaced is kept as *.pre-kon$N"
	confirm go "Install?" y
	[ -n "$go" ] || { info "nothing changed"; exit 0; }
elif [ -z "$wms" ]; then
	wms=$found
	[ -n "$wms" ] || die "none of aro, hyprland or niri is installed"
fi

# install
title "Installing"
for wm in $wms; do
	case $wm in
	aro)
		put "$here/config/aro" "$conf/aro"
		sed -i "s/^layout = .*/layout = $aro_layout/" "$conf/aro/config"
		if [ -n "$kb" ]; then
			printf '\nkeyboard_layout = %s\n' "$kb" >> "$conf/aro/config"
		fi
		ok "aro" ;;
	hyprland) hypr ;;
	niri)
		put "$here/config/niri" "$conf/niri"
		if [ -n "$kb" ]; then
			sed -i "s/^    keyboard {\$/    keyboard {\n        xkb {\n            layout \"$kb\"\n        }/" "$conf/niri/config.kdl"
		fi
		if command -v niri >/dev/null && ! niri validate -c "$conf/niri/config.kdl" >/dev/null 2>&1; then
			warn "niri doesn't accept the keyboard layout \"$kb\"; using the default"
			put "$here/config/niri" "$conf/niri"
		fi
		ok "niri" ;;
	esac
done

for d in kon foot mako fuzzel fastfetch qutebrowser; do
	put "$here/config/$d" "$conf/$d"
done
put "$here/config/quickshell/aroclip" "$conf/quickshell/aroclip"
put "$here/config/starship.toml" "$conf/starship.toml"
put "$here/bin/aroclip" "$bin/aroclip"
put "$here/bin/kon-lock" "$bin/kon-lock"
put "$here/bin/kon-wm" "$bin/kon-wm"
put "$here/config/kon/kon.py" "$bin/kon"
ok "shell, kon and apps"

shell=$conf/quickshell/aroclip
if [ -n "$lat" ]; then
	esc=$(printf '%s' "$city" | sed 's/[\/&"]/\\&/g')
	sed -i -e "s/^\\( *readonly property string pinCity: \\)\"\"/\\1\"$esc\"/" \
		-e "s/^\\( *readonly property real pinLat: \\)NaN/\\1$lat/" \
		-e "s/^\\( *readonly property real pinLon: \\)NaN/\\1$lon/" "$shell/Aero.qml"
	ok "weather pinned to $city"
fi
[ -n "$snow" ] || { sed -i 's/^\( *property bool enabled: \)true/\1false/' "$shell/Snow.qml"; ok "snow off"; }
if [ -n "$wall" ]; then
	ext=jpg
	case ${wall##*/} in *.*) ext=${wall##*.} ;; esac
	cp "$wall" "$conf/kon/wallpapers/aero.$ext"
	sed -i "s|\"wallpaper\": \"[^\"]*\"|\"wallpaper\": \"~/.config/kon/wallpapers/aero.$ext\"|" "$conf/kon/themes/aero.json"
	ok "wallpaper"
fi

printf '\n%sdone.%s log into %s and run %skon%s\n' "$GREEN$B" "$N" "$(printf '%s' "${wms# }" | sed 's/ /, /g')" "$B" "$N"
