import os

config.load_autoconfig()

# start page and colours from kon
c.url.start_pages = ["file://" + os.path.expanduser("~/.config/kon/start.html")]
c.url.default_page = "file://" + os.path.expanduser("~/.config/kon/start.html")

c.prompt.radius = 0
c.hints.radius = 0

colors_file = os.path.expanduser("~/.config/qutebrowser/kon.py")
if os.path.exists(colors_file):
    exec(open(colors_file).read())
