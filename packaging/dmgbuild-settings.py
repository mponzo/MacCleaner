# dmgbuild settings for MacCleaner installer window
# Invoked as:
#   dmgbuild -s packaging/dmgbuild-settings.py \
#     -D app=/path/MacCleaner.app \
#     -D background=/path/dmg-background@1x.tiff \
#     "MacCleaner 0.2.4" releases/MacCleaner-0.2.4.dmg

import os.path

_app = defines.get("app")  # noqa: F821 — injected by dmgbuild
_bg = defines.get("background")  # noqa: F821

application = _app
appname = os.path.basename(application)

format = "UDZO"
files = [application]
symlinks = {"Applications": "/Applications"}

icon_locations = {
    appname: (217, 238),
    "Applications": (500, 240),
}

background = _bg

show_status_bar = False
show_tab_view = False
show_toolbar = False
show_pathbar = False
show_sidebar = False

window_rect = ((200, 160), (720, 450))
default_view = "icon-view"
show_icon_preview = False

include_icon_view_settings = "auto"
include_list_view_settings = "auto"

arrange_by = None
grid_offset = (0, 0)
grid_spacing = 100
scroll_position = (0, 0)
label_pos = "bottom"
text_size = 12
icon_size = 128
