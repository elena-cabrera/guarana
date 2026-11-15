# dmgbuild settings for the Guarana installer window.
# Positions match the blush/blue circles drawn in Sources/GuaranaAssets (640 x 400 pt).
import os.path

root = os.getcwd()  # make-dmg.sh runs from the repo root
app = os.path.join(root, "build", "Guarana.app")

format = "UDZO"
filesystem = "HFS+"
files = [app]
symlinks = {"Applications": "/Applications"}
badge_icon = os.path.join(root, "build", "assets", "AppIcon.icns")

background = os.path.join(root, "build", "assets", "dmg-background.tiff")
window_rect = ((200, 160), (640, 428))  # + title bar
default_view = "icon-view"
show_status_bar = False
show_tab_view = False
show_toolbar = False
show_pathbar = False
show_sidebar = False
icon_size = 112
text_size = 13
icon_locations = {
    "Guarana.app": (160, 210),
    "Applications": (480, 210),
}
