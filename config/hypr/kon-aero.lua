require("kon")
pcall(require, "kon-layout")

local mod = "SUPER"
local bin = "~/.local/bin/"
local dsp = hl.dsp

hl.env("XCURSOR_THEME", "Windows8-cursor")
hl.env("XCURSOR_SIZE", "24")

hl.on("hyprland.start", function()
    hl.exec_cmd("systemctl --user import-environment WAYLAND_DISPLAY DISPLAY XDG_CURRENT_DESKTOP HYPRLAND_INSTANCE_SIGNATURE")
    hl.exec_cmd("wl-paste --watch cliphist store")
    hl.exec_cmd("qs -c aroclip -d")
    hl.exec_cmd("mako")
    hl.exec_cmd("swayidle -w timeout 600 '~/.local/bin/kon-lock -f' before-sleep '~/.local/bin/kon-lock -f'")
    hl.exec_cmd("foot --app-id dropterm")
    hl.exec_cmd(bin .. "kon")
end)

hl.config({
    misc = {
        force_default_wallpaper = 0,
        disable_hyprland_logo = true,
    },
})

for _, ns in ipairs({ "aero-taskbar", "aero-glass", "aero-flip", "launcher" }) do
    hl.layer_rule({ name = "blur-" .. ns, match = { namespace = "^" .. ns .. "$" }, blur = true, ignore_alpha = 0.01 })
end

hl.window_rule({
    name = "dropterm",
    match = { class = "^dropterm$" },
    float = true,
    size = "70% 55%",
    move = "15% 5%",
    workspace = "special:dropterm silent",
})
hl.window_rule({ name = "pavucontrol", match = { class = "pavucontrol" }, float = true, size = "800 500", center = true })
hl.window_rule({ name = "mpv", match = { class = "^mpv$" }, border_size = 0, rounding = 0, opaque = true })

local function bind(keys, d, opts)
    hl.unbind(keys)
    hl.bind(keys, d, opts)
end

bind(mod .. " + Q", dsp.exec_cmd("foot"))
bind(mod .. " + A", dsp.exec_cmd(bin .. "aroclip apps"))
bind(mod .. " + SHIFT + A", dsp.exec_cmd("fuzzel"))
bind(mod .. " + C", dsp.window.close())
bind(mod .. " + SHIFT + E", dsp.exec_cmd(bin .. "aroclip power"))
bind(mod .. " + SPACE", dsp.window.float({ action = "toggle" }))
bind(mod .. " + SHIFT + SPACE", dsp.window.pin())
bind(mod .. " + T", dsp.layout("togglesplit"))
bind(mod .. " + Tab", dsp.exec_cmd("qs -c aroclip ipc call flip toggle"))
bind("ALT + Tab", dsp.window.cycle_next())
bind(mod .. " + SHIFT + Tab", dsp.window.cycle_next({ prev = true }))
bind(mod .. " + ESCAPE", dsp.exec_cmd(bin .. "kon-lock -f"))
bind(mod .. " + V", dsp.exec_cmd(bin .. "aroclip menu"))
bind("Print", dsp.exec_cmd(bin .. "aroclip full"))
bind(mod .. " + Print", dsp.exec_cmd(bin .. "aroclip area"))
bind(mod .. " + SHIFT + Print", dsp.exec_cmd(bin .. "aroclip rec"))
bind(mod .. " + CTRL + Print", dsp.exec_cmd(bin .. "aroclip rec area"))
bind(mod .. " + SHIFT + C", dsp.exec_cmd(bin .. "aroclip color"))
bind(mod .. " + period", dsp.exec_cmd(bin .. "aroclip emoji"))
bind(mod .. " + F", dsp.window.fullscreen({ mode = "maximized" }))
bind(mod .. " + SHIFT + F", dsp.window.fullscreen({ mode = "fullscreen" }))
bind(mod .. " + apostrophe", dsp.workspace.toggle_special("dropterm"))
bind(mod .. " + SHIFT + G", dsp.group.toggle())
bind(mod .. " + bracketright", dsp.group.next())
bind(mod .. " + bracketleft", dsp.group.prev())

local dirs = { h = "left", j = "down", k = "up", l = "right" }
local step = { left = { -40, 0 }, right = { 40, 0 }, up = { 0, -40 }, down = { 0, 40 } }
local side = { left = "l", right = "r", up = "u", down = "d" }
for key, dir in pairs(dirs) do
    bind(mod .. " + " .. key, dsp.focus({ direction = dir }))
    bind(mod .. " + SHIFT + " .. key, dsp.window.move({ direction = dir }))
    bind(mod .. " + CTRL + " .. key,
        dsp.window.resize({ x = step[dir][1], y = step[dir][2], relative = true }), { repeating = true })
    bind(mod .. " + ALT + " .. key, dsp.workspace.move({ monitor = side[dir] }))
end

for i = 1, 8 do
    bind(mod .. " + " .. i, dsp.focus({ workspace = i }))
    bind(mod .. " + SHIFT + " .. i, dsp.window.move({ workspace = i }))
end

bind(mod .. " + mouse:272", dsp.window.drag(), { mouse = true })
bind(mod .. " + mouse:273", dsp.window.resize(), { mouse = true })

local keys = { locked = true, repeating = true }
bind("XF86AudioRaiseVolume", dsp.exec_cmd(bin .. "aroclip vol up"), keys)
bind("XF86AudioLowerVolume", dsp.exec_cmd(bin .. "aroclip vol down"), keys)
bind("XF86AudioMute", dsp.exec_cmd(bin .. "aroclip vol mute"), { locked = true })
bind("XF86AudioMicMute", dsp.exec_cmd(bin .. "aroclip mic"), { locked = true })
bind("XF86MonBrightnessUp", dsp.exec_cmd(bin .. "aroclip bright up"), keys)
bind("XF86MonBrightnessDown", dsp.exec_cmd(bin .. "aroclip bright down"), keys)
bind("XF86AudioPlay", dsp.exec_cmd("playerctl play-pause"), { locked = true })
bind("XF86AudioNext", dsp.exec_cmd("playerctl next"), { locked = true })
bind("XF86AudioPrev", dsp.exec_cmd("playerctl previous"), { locked = true })
