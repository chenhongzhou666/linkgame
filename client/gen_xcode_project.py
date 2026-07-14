#!/usr/bin/env python3
"""Generate Xcode project.pbxproj for LinkGame macOS app + Widget Extension."""
import os, uuid

def gen(): return uuid.uuid4().hex[:24].upper()

# --- UUID allocation ---
P_ROOT           = gen()  # Project object
P_MAIN_GRP       = gen()  # Main group
P_LINKGAME_GRP   = gen()  # LinkGame sources group
P_GAME_GRP       = gen()  # Game/ subdirectory
P_MODELS_GRP     = gen()  # Models/
P_NETWORK_GRP    = gen()  # Network/
P_VIEWS_GRP      = gen()  # Views/
P_WIDGET_GRP     = gen()  # Widget sources group
P_PROD_GRP       = gen()  # Products group

# Products
P_APP_PROD       = gen()  # LinkGame.app product ref
P_WIDGET_PROD    = gen()  # LinkWidget.appex product ref

# Targets
P_APP_TARGET     = gen()  # LinkGame app target
P_WIDGET_TARGET  = gen()  # Widget extension target

# Build phases
P_APP_SRC_PHASE  = gen()
P_APP_RES_PHASE  = gen()
P_APP_EMBED_PHASE = gen()
P_WIDGET_SRC_PHASE = gen()
P_WIDGET_RES_PHASE = gen()

# Config lists
P_PROJ_CFG_LIST  = gen()
P_APP_CFG_LIST   = gen()
P_WIDGET_CFG_LIST = gen()

# Build configs (project level)
P_PROJ_DBG       = gen()
P_PROJ_REL       = gen()

# Build configs (app target)
P_APP_DBG        = gen()
P_APP_REL        = gen()

# Build configs (widget target)
P_WIDGET_DBG     = gen()
P_WIDGET_REL     = gen()

# Source files (main app)
APP_SOURCES = {
    "App.swift":                ("", "App.swift"),
    "Board.swift":              ("Game", "Board.swift"),
    "GameState.swift":          ("Game", "GameState.swift"),
    "LinkEngine.swift":         ("Game", "LinkEngine.swift"),
    "AccountManager.swift":     ("Models", "AccountManager.swift"),
    "GameMode.swift":           ("Models", "GameMode.swift"),
    "IconSet.swift":            ("Models", "IconSet.swift"),
    "Level.swift":              ("Models", "Level.swift"),
    "MusicManager.swift":       ("Models", "MusicManager.swift"),
    "Score.swift":              ("Models", "Score.swift"),
    "Theme.swift":              ("Models", "Theme.swift"),
    "ThemeManager.swift":       ("Models", "ThemeManager.swift"),
    "User.swift":               ("Models", "User.swift"),
    "WallpaperManager.swift":   ("Models", "WallpaperManager.swift"),
    "APIClient.swift":          ("Network", "APIClient.swift"),
    "ServerManager.swift":      ("Network", "ServerManager.swift"),
    "AppBackground.swift":      ("Views", "AppBackground.swift"),
    "AppLogo.swift":            ("Views", "AppLogo.swift"),
    "AvatarView.swift":         ("Views", "AvatarView.swift"),
    "ClickableModifier.swift":  ("Views", "ClickableModifier.swift"),
    "ContentView.swift":        ("Views", "ContentView.swift"),
    "DinoRunnerView.swift":     ("Views", "DinoRunnerView.swift"),
    "GameHubView.swift":        ("Views", "GameHubView.swift"),
    "GameView.swift":           ("Views", "GameView.swift"),
    "HistoryView.swift":        ("Views", "HistoryView.swift"),
    "LeaderboardView.swift":    ("Views", "LeaderboardView.swift"),
    "LoginView.swift":          ("Views", "LoginView.swift"),
    "PixelArtBackground.swift": ("Views", "PixelArtBackground.swift"),
    "SettingsView.swift":       ("Views", "SettingsView.swift"),
    "WidgetStoreView.swift":    ("Views", "WidgetStoreView.swift"),
    "DesktopWidgetView.swift":  ("Views", "DesktopWidgetView.swift"),
}

# Source files (widget)
WIDGET_SOURCES = {
    "WidgetBundle.swift":       "WidgetBundle.swift",
    "LinkWidget.swift":         "LinkWidget.swift",
}

# Shared files (used by both App and Widget targets)
SHARED_SOURCES = {
    "WidgetSkin.swift":         "WidgetSkin.swift",
    "WidgetDataProvider.swift": "WidgetDataProvider.swift",
}
shared_file_refs = {name: gen() for name in SHARED_SOURCES}

# Generate file refs
app_file_refs = {name: gen() for name in APP_SOURCES}
app_build_refs = {name: gen() for name in APP_SOURCES}
widget_file_refs = {name: gen() for name in WIDGET_SOURCES}
widget_build_refs = {name: gen() for name in WIDGET_SOURCES}
shared_app_build_refs = {name: gen() for name in SHARED_SOURCES}
shared_widget_build_refs = {name: gen() for name in SHARED_SOURCES}

# Widget Info.plist
WIDGET_PLIST_REF = gen()

# App Info.plist
APP_PLIST_REF = gen()
APP_ICON_REF = gen()
APP_ICON_BUILD_REF = gen()
APP_LOGO_REF = gen()
APP_LOGO_BUILD_REF = gen()
# Group UUIDs for subdirectories
src_groups = {}
for group_name in set(g for g, _ in APP_SOURCES.values() if g):
    src_groups[group_name] = gen()

# --- Helper ---
def q(s): return f'"{s}"'

# --- Build the pbxproj ---
pbx = '// !$*UTF8*$!\n{\n\tarchiveVersion = 1;\n\tclasses = {};\n\tobjectVersion = 56;\n\tobjects = {\n\n'

# ====== PBXBuildFile ======
pbx += '/* Begin PBXBuildFile section */\n'
for name, bid in app_build_refs.items():
    ref = app_file_refs[name]
    pbx += f'\t\t{bid} /* {name} in Sources */ = {{isa = PBXBuildFile; fileRef = {ref} /* {name} */; }};\n'
for name, bid in widget_build_refs.items():
    ref = widget_file_refs[name]
    pbx += f'\t\t{bid} /* {name} in Sources */ = {{isa = PBXBuildFile; fileRef = {ref} /* {name} */; }};\n'
# Shared sources — build for both targets
for name, bid in shared_app_build_refs.items():
    ref = shared_file_refs[name]
    pbx += f'\t\t{bid} /* {name} in Sources (App) */ = {{isa = PBXBuildFile; fileRef = {ref} /* {name} */; }};\n'
for name, bid in shared_widget_build_refs.items():
    ref = shared_file_refs[name]
    pbx += f'\t\t{bid} /* {name} in Sources (Widget) */ = {{isa = PBXBuildFile; fileRef = {ref} /* {name} */; }};\n'
pbx += f'\t\t{APP_ICON_BUILD_REF} /* AppIcon.icns in Resources */ = {{isa = PBXBuildFile; fileRef = {APP_ICON_REF} /* AppIcon.icns */; }};\n'
pbx += f'\t\t{APP_LOGO_BUILD_REF} /* logo.png in Resources */ = {{isa = PBXBuildFile; fileRef = {APP_LOGO_REF} /* logo.png */; }};\n'
pbx += '/* End PBXBuildFile section */\n\n'

# ====== PBXFileReference ======
pbx += '/* Begin PBXFileReference section */\n'
# Products
pbx += f'\t\t{P_APP_PROD} /* LinkGame.app */ = {{isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = LinkGame.app; sourceTree = BUILT_PRODUCTS_DIR; }};\n'
pbx += f'\t\t{P_WIDGET_PROD} /* LinkWidget.appex */ = {{isa = PBXFileReference; explicitFileType = "wrapper.app-extension"; includeInIndex = 0; path = LinkWidget.appex; sourceTree = BUILT_PRODUCTS_DIR; }};\n'
# App sources
for name, ref in app_file_refs.items():
    _, path = APP_SOURCES[name]
    pbx += f'\t\t{ref} /* {name} */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = "{path}"; sourceTree = "<group>"; }};\n'
# Widget sources
for name, ref in widget_file_refs.items():
    path = WIDGET_SOURCES[name]
    pbx += f'\t\t{ref} /* {name} */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = "{path}"; sourceTree = "<group>"; }};\n'
# Shared sources (in Widget group)
for name, ref in shared_file_refs.items():
    path = SHARED_SOURCES[name]
    pbx += f'\t\t{ref} /* {name} */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = "{path}"; sourceTree = "<group>"; }};\n'
# Widget Info.plist
pbx += f'\t\t{WIDGET_PLIST_REF} /* Info.plist */ = {{isa = PBXFileReference; lastKnownFileType = text.plist.xml; path = Info.plist; sourceTree = "<group>"; }};\n'
# App Icon
pbx += f'\t\t{APP_ICON_REF} /* AppIcon.icns */ = {{isa = PBXFileReference; lastKnownFileType = image.icns; path = AppIcon.icns; sourceTree = "<group>"; }};\n'
pbx += f'\t\t{APP_LOGO_REF} /* logo.png */ = {{isa = PBXFileReference; lastKnownFileType = image.png; path = logo.png; sourceTree = "<group>"; }};\n'
# App Info.plist
pbx += f'\t\t{APP_PLIST_REF} /* macOS-Info.plist */ = {{isa = PBXFileReference; lastKnownFileType = text.plist.xml; path = macOS-Info.plist; sourceTree = "<group>"; }};\n'
pbx += '/* End PBXFileReference section */\n\n'

# ====== PBXGroup ======
pbx += '/* Begin PBXGroup section */\n'

# Main group
pbx += f'\t\t{P_MAIN_GRP} = {{\n\t\t\tisa = PBXGroup;\n\t\t\tchildren = (\n'
pbx += f'\t\t\t\t{P_LINKGAME_GRP} /* LinkGame */,\n'
pbx += f'\t\t\t\t{P_WIDGET_GRP} /* Widget */,\n'
pbx += f'\t\t\t\t{APP_ICON_REF} /* AppIcon.icns */,\n'
pbx += f'\t\t\t\t{APP_LOGO_REF} /* logo.png */,\n'
pbx += f'\t\t\t\t{APP_PLIST_REF} /* macOS-Info.plist */,\n'
pbx += f'\t\t\t\t{P_PROD_GRP} /* Products */,\n'
pbx += f'\t\t\t);\n\t\t\tsourceTree = "<group>";\n\t\t}};\n'

# LinkGame sources group
pbx += f'\t\t{P_LINKGAME_GRP} = {{\n\t\t\tisa = PBXGroup;\n\t\t\tchildren = (\n'
# Root-level files
for name in APP_SOURCES:
    group, _ = APP_SOURCES[name]
    if not group:
        pbx += f'\t\t\t\t{app_file_refs[name]} /* {name} */,\n'
# Subdirectories
for group_name in ["Game", "Models", "Network", "Views"]:
    pbx += f'\t\t\t\t{src_groups[group_name]} /* {group_name} */,\n'
pbx += f'\t\t\t);\n\t\t\tpath = Sources/LinkGame;\n\t\t\tsourceTree = "<group>";\n\t\t}};\n'

# Subdirectory groups
for group_name in ["Game", "Models", "Network", "Views"]:
    pbx += f'\t\t{src_groups[group_name]} = {{\n\t\t\tisa = PBXGroup;\n\t\t\tchildren = (\n'
    for name in APP_SOURCES:
        g, _ = APP_SOURCES[name]
        if g == group_name:
            pbx += f'\t\t\t\t{app_file_refs[name]} /* {name} */,\n'
    pbx += f'\t\t\t);\n\t\t\tpath = {group_name};\n\t\t\tsourceTree = "<group>";\n\t\t}};\n'

# Widget group
pbx += f'\t\t{P_WIDGET_GRP} = {{\n\t\t\tisa = PBXGroup;\n\t\t\tchildren = (\n'
for name in WIDGET_SOURCES:
    pbx += f'\t\t\t\t{widget_file_refs[name]} /* {name} */,\n'
for name in SHARED_SOURCES:
    pbx += f'\t\t\t\t{shared_file_refs[name]} /* {name} */,\n'
pbx += f'\t\t\t\t{WIDGET_PLIST_REF} /* Info.plist */,\n'
pbx += f'\t\t\t);\n\t\t\tpath = Sources/Widget;\n\t\t\tsourceTree = "<group>";\n\t\t}};\n'

# Products group
pbx += f'\t\t{P_PROD_GRP} = {{\n\t\t\tisa = PBXGroup;\n\t\t\tchildren = (\n'
pbx += f'\t\t\t\t{P_APP_PROD} /* LinkGame.app */,\n'
pbx += f'\t\t\t\t{P_WIDGET_PROD} /* LinkWidget.appex */,\n'
pbx += f'\t\t\t);\n\t\t\tname = Products;\n\t\t\tsourceTree = "<group>";\n\t\t}};\n'

pbx += '/* End PBXGroup section */\n\n'

# ====== PBXNativeTarget ======
pbx += '/* Begin PBXNativeTarget section */\n'

# App target
pbx += f'\t\t{P_APP_TARGET} /* LinkGame */ = {{\n'
pbx += f'\t\t\tisa = PBXNativeTarget;\n'
pbx += f'\t\t\tbuildConfigurationList = {P_APP_CFG_LIST} /* Build configuration list for PBXNativeTarget "LinkGame" */;\n'
pbx += f'\t\t\tbuildPhases = (\n'
pbx += f'\t\t\t\t{P_APP_SRC_PHASE} /* Sources */,\n'
pbx += f'\t\t\t\t{P_APP_RES_PHASE} /* Resources */,\n'
pbx += f'\t\t\t\t{P_APP_EMBED_PHASE} /* Embed App Extensions */,\n'
pbx += f'\t\t\t);\n'
pbx += f'\t\t\tbuildRules = ();\n'
pbx += f'\t\t\tdependencies = (\n'
pbx += f'\t\t\t\t{gen()} /* PBXTargetDependency */,\n'
pbx += f'\t\t\t);\n'
pbx += f'\t\t\tname = LinkGame;\n'
pbx += f'\t\t\tproductName = LinkGame;\n'
pbx += f'\t\t\tproductReference = {P_APP_PROD} /* LinkGame.app */;\n'
pbx += f'\t\t\tproductType = "com.apple.product-type.application";\n'
pbx += f'\t\t}};\n'

# Widget target
pbx += f'\t\t{P_WIDGET_TARGET} /* LinkWidget */ = {{\n'
pbx += f'\t\t\tisa = PBXNativeTarget;\n'
pbx += f'\t\t\tbuildConfigurationList = {P_WIDGET_CFG_LIST} /* Build configuration list for PBXNativeTarget "LinkWidget" */;\n'
pbx += f'\t\t\tbuildPhases = (\n'
pbx += f'\t\t\t\t{P_WIDGET_SRC_PHASE} /* Sources */,\n'
pbx += f'\t\t\t\t{P_WIDGET_RES_PHASE} /* Resources */,\n'
pbx += f'\t\t\t);\n'
pbx += f'\t\t\tbuildRules = ();\n'
pbx += f'\t\t\tdependencies = ();\n'
pbx += f'\t\t\tname = LinkWidget;\n'
pbx += f'\t\t\tproductName = LinkWidget;\n'
pbx += f'\t\t\tproductReference = {P_WIDGET_PROD} /* LinkWidget.appex */;\n'
pbx += f'\t\t\tproductType = "com.apple.product-type.app-extension";\n'
pbx += f'\t\t}};\n'

pbx += '/* End PBXNativeTarget section */\n\n'

# ====== PBXProject ======
pbx += '/* Begin PBXProject section */\n'
pbx += f'\t\t{P_ROOT} /* Project object */ = {{\n'
pbx += f'\t\t\tisa = PBXProject;\n'
pbx += f'\t\t\tattributes = {{\n'
pbx += f'\t\t\t\tBuildIndependentTargetsInParallel = 1;\n'
pbx += f'\t\t\t\tLastSwiftUpdateCheck = 1600;\n'
pbx += f'\t\t\t\tLastUpgradeCheck = 1600;\n'
pbx += f'\t\t\t}};\n'
pbx += f'\t\t\tbuildConfigurationList = {P_PROJ_CFG_LIST} /* Build configuration list for PBXProject "LinkGame" */;\n'
pbx += f'\t\t\tcompatibilityVersion = "Xcode 14.0";\n'
pbx += f'\t\t\tdevelopmentRegion = "zh-Hans";\n'
pbx += f'\t\t\thasScannedForEncodings = 0;\n'
pbx += f'\t\t\tknownRegions = (en, Base, "zh-Hans");\n'
pbx += f'\t\t\tmainGroup = {P_MAIN_GRP};\n'
pbx += f'\t\t\tproductRefGroup = {P_PROD_GRP} /* Products */;\n'
pbx += f'\t\t\tprojectDirPath = "";\n'
pbx += f'\t\t\tprojectRoot = "";\n'
pbx += f'\t\t\ttargets = (\n'
pbx += f'\t\t\t\t{P_APP_TARGET} /* LinkGame */,\n'
pbx += f'\t\t\t\t{P_WIDGET_TARGET} /* LinkWidget */,\n'
pbx += f'\t\t\t);\n'
pbx += f'\t\t}};\n'
pbx += '/* End PBXProject section */\n\n'

# ====== PBXSourcesBuildPhase ======
pbx += '/* Begin PBXSourcesBuildPhase section */\n'
# App sources
pbx += f'\t\t{P_APP_SRC_PHASE} /* Sources */ = {{\n\t\t\tisa = PBXSourcesBuildPhase;\n\t\t\tbuildActionMask = 2147483647;\n\t\t\tfiles = (\n'
for name in APP_SOURCES:
    pbx += f'\t\t\t\t{app_build_refs[name]} /* {name} in Sources */,\n'
for name in SHARED_SOURCES:
    pbx += f'\t\t\t\t{shared_app_build_refs[name]} /* {name} in Sources */,\n'
pbx += f'\t\t\t);\n\t\t\trunOnlyForDeploymentPostprocessing = 0;\n\t\t}};\n'
# Widget sources
pbx += f'\t\t{P_WIDGET_SRC_PHASE} /* Sources */ = {{\n\t\t\tisa = PBXSourcesBuildPhase;\n\t\t\tbuildActionMask = 2147483647;\n\t\t\tfiles = (\n'
for name in WIDGET_SOURCES:
    pbx += f'\t\t\t\t{widget_build_refs[name]} /* {name} in Sources */,\n'
for name in SHARED_SOURCES:
    pbx += f'\t\t\t\t{shared_widget_build_refs[name]} /* {name} in Sources */,\n'
pbx += f'\t\t\t);\n\t\t\trunOnlyForDeploymentPostprocessing = 0;\n\t\t}};\n'
pbx += '/* End PBXSourcesBuildPhase section */\n\n'

# ====== PBXResourcesBuildPhase ======
pbx += '/* Begin PBXResourcesBuildPhase section */\n'
# App resources
pbx += f'\t\t{P_APP_RES_PHASE} /* Resources */ = {{\n\t\t\tisa = PBXResourcesBuildPhase;\n\t\t\tbuildActionMask = 2147483647;\n\t\t\tfiles = (\n'
pbx += f'\t\t\t\t{APP_ICON_BUILD_REF} /* AppIcon.icns in Resources */,\n'
pbx += f'\t\t\t\t{APP_LOGO_BUILD_REF} /* logo.png in Resources */,\n'
pbx += f'\t\t\t);\n\t\t\trunOnlyForDeploymentPostprocessing = 0;\n\t\t}};\n'
# Widget resources (empty — Info.plist handled via INFOPLIST_FILE)
pbx += f'\t\t{P_WIDGET_RES_PHASE} /* Resources */ = {{\n\t\t\tisa = PBXResourcesBuildPhase;\n\t\t\tbuildActionMask = 2147483647;\n\t\t\tfiles = ();\n\t\t\trunOnlyForDeploymentPostprocessing = 0;\n\t\t}};\n'
pbx += '/* End PBXResourcesBuildPhase section */\n\n'

# ====== PBXCopyFilesBuildPhase (Embed Widget) ======
pbx += '/* Begin PBXCopyFilesBuildPhase section */\n'
EMBED_PHASE = gen()
pbx += f'\t\t{P_APP_EMBED_PHASE} /* Embed App Extensions */ = {{\n'
pbx += f'\t\t\tisa = PBXCopyFilesBuildPhase;\n'
pbx += f'\t\t\tbuildActionMask = 2147483647;\n'
pbx += f'\t\t\tdstPath = "";\n'
pbx += f'\t\t\tdstSubfolderSpec = 13;\n'
pbx += f'\t\t\tfiles = (\n'
EMBED_FILE = gen()
pbx += f'\t\t\t\t{EMBED_FILE} /* LinkWidget.appex in Embed App Extensions */,\n'
pbx += f'\t\t\t);\n'
pbx += f'\t\t\trunOnlyForDeploymentPostprocessing = 0;\n'
pbx += f'\t\t}};\n'
pbx += '/* End PBXCopyFilesBuildPhase section */\n\n'

# Also need the PBXBuildFile for the embed
# Insert right after Begin PBXBuildFile
embed_build_line = f'\t\t{EMBED_FILE} /* LinkWidget.appex in Embed App Extensions */ = {{isa = PBXBuildFile; fileRef = {P_WIDGET_PROD} /* LinkWidget.appex */; settings = {{ATTRIBUTES = (RemoveHeadersOnCopy, ); }}; }};\n'
pbx = pbx.replace('/* End PBXBuildFile section */\n', embed_build_line + '/* End PBXBuildFile section */\n')

# ====== XCBuildConfiguration ======
pbx += '/* Begin XCBuildConfiguration section */\n'

# Project Debug
pbx += f'\t\t{P_PROJ_DBG} /* Debug */ = {{\n\t\t\tisa = XCBuildConfiguration;\n\t\t\tbuildSettings = {{\n'
pbx += f'\t\t\t\tALWAYS_SEARCH_USER_PATHS = NO;\n'
pbx += f'\t\t\t\tCLANG_ANALYZER_NONNULL = YES;\n'
pbx += f'\t\t\t\tCLANG_CXX_LANGUAGE_STANDARD = "gnu++20";\n'
pbx += f'\t\t\t\tCLANG_ENABLE_MODULES = YES;\n'
pbx += f'\t\t\t\tCLANG_ENABLE_OBJC_ARC = YES;\n'
pbx += f'\t\t\t\tCOPY_PHASE_STRIP = NO;\n'
pbx += f'\t\t\t\tDEBUG_INFORMATION_FORMAT = dwarf;\n'
pbx += f'\t\t\t\tENABLE_STRICT_OBJC_MSGSEND = YES;\n'
pbx += f'\t\t\t\tENABLE_TESTABILITY = YES;\n'
pbx += f'\t\t\t\tGCC_DYNAMIC_NO_PIC = NO;\n'
pbx += f'\t\t\t\tGCC_NO_COMMON_BLOCKS = YES;\n'
pbx += f'\t\t\t\tGCC_OPTIMIZATION_LEVEL = 0;\n'
pbx += f'\t\t\t\tGCC_PREPROCESSOR_DEFINITIONS = ("DEBUG=1", "$(inherited)");\n'
pbx += f'\t\t\t\tMACOSX_DEPLOYMENT_TARGET = 14.0;\n'
pbx += f'\t\t\t\tMTL_ENABLE_DEBUG_INFO = INCLUDE_SOURCE;\n'
pbx += f'\t\t\t\tMTL_FAST_MATH = YES;\n'
pbx += f'\t\t\t\tONLY_ACTIVE_ARCH = YES;\n'
pbx += f'\t\t\t\tSDKROOT = macosx;\n'
pbx += f'\t\t\t\tSWIFT_ACTIVE_COMPILATION_CONDITIONS = DEBUG;\n'
pbx += f'\t\t\t\tSWIFT_OPTIMIZATION_LEVEL = "-Onone";\n'
pbx += f'\t\t\t\tSWIFT_VERSION = 5.0;\n'
pbx += f'\t\t\t\tENABLE_USER_SCRIPT_SANDBOXING = NO;\n'
pbx += f'\t\t\t}};\n\t\t\tname = Debug;\n\t\t}};\n'

# Project Release
pbx += f'\t\t{P_PROJ_REL} /* Release */ = {{\n\t\t\tisa = XCBuildConfiguration;\n\t\t\tbuildSettings = {{\n'
pbx += f'\t\t\t\tALWAYS_SEARCH_USER_PATHS = NO;\n'
pbx += f'\t\t\t\tCLANG_ANALYZER_NONNULL = YES;\n'
pbx += f'\t\t\t\tCLANG_CXX_LANGUAGE_STANDARD = "gnu++20";\n'
pbx += f'\t\t\t\tCLANG_ENABLE_MODULES = YES;\n'
pbx += f'\t\t\t\tCLANG_ENABLE_OBJC_ARC = YES;\n'
pbx += f'\t\t\t\tCOPY_PHASE_STRIP = NO;\n'
pbx += f'\t\t\t\tDEBUG_INFORMATION_FORMAT = "dwarf-with-dsym";\n'
pbx += f'\t\t\t\tENABLE_NS_ASSERTIONS = NO;\n'
pbx += f'\t\t\t\tENABLE_STRICT_OBJC_MSGSEND = YES;\n'
pbx += f'\t\t\t\tGCC_NO_COMMON_BLOCKS = YES;\n'
pbx += f'\t\t\t\tGCC_OPTIMIZATION_LEVEL = s;\n'
pbx += f'\t\t\t\tMACOSX_DEPLOYMENT_TARGET = 14.0;\n'
pbx += f'\t\t\t\tMTL_ENABLE_DEBUG_INFO = NO;\n'
pbx += f'\t\t\t\tMTL_FAST_MATH = YES;\n'
pbx += f'\t\t\t\tSDKROOT = macosx;\n'
pbx += f'\t\t\t\tSWIFT_COMPILATION_MODE = wholemodule;\n'
pbx += f'\t\t\t\tSWIFT_OPTIMIZATION_LEVEL = "-O";\n'
pbx += f'\t\t\t\tSWIFT_VERSION = 5.0;\n'
pbx += f'\t\t\t\tVALIDATE_PRODUCT = YES;\n'
pbx += f'\t\t\t\tENABLE_USER_SCRIPT_SANDBOXING = NO;\n'
pbx += f'\t\t\t}};\n\t\t\tname = Release;\n\t\t}};\n'

# App target Debug
pbx += f'\t\t{P_APP_DBG} /* Debug */ = {{\n\t\t\tisa = XCBuildConfiguration;\n\t\t\tbuildSettings = {{\n'
pbx += f'\t\t\t\tCODE_SIGN_STYLE = Automatic;\n'
pbx += f'\t\t\t\tDEVELOPMENT_TEAM = 8WFH238U2W;\n'
pbx += f'\t\t\t\tCURRENT_PROJECT_VERSION = 1;\n'
pbx += f'\t\t\t\tENABLE_PREVIEWS = YES;\n'
pbx += f'\t\t\t\tGENERATE_INFOPLIST_FILE = NO;\n'
pbx += f'\t\t\t\tINFOPLIST_FILE = macOS-Info.plist;\n'
pbx += f'\t\t\t\tLD_RUNPATH_SEARCH_PATHS = ("$(inherited)", "@executable_path/../Frameworks");\n'
pbx += f'\t\t\t\tMARKETING_VERSION = 1.0;\n'
pbx += f'\t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = com.chenhongzhou.linkgame;\n'
pbx += f'\t\t\t\tPRODUCT_NAME = "$(TARGET_NAME)";\n'
pbx += f'\t\t\t\tSUPPORTED_PLATFORMS = macosx;\n'
pbx += f'\t\t\t\tSWIFT_EMIT_LOC_STRINGS = YES;\n'
pbx += f'\t\t\t\tSWIFT_VERSION = 5.0;\n'
pbx += f'\t\t\t\tCODE_SIGN_ENTITLEMENTS = LinkGame.entitlements;\n'
pbx += f'\t\t\t}};\n\t\t\tname = Debug;\n\t\t}};\n'

# App target Release
pbx += f'\t\t{P_APP_REL} /* Release */ = {{\n\t\t\tisa = XCBuildConfiguration;\n\t\t\tbuildSettings = {{\n'
pbx += f'\t\t\t\tCODE_SIGN_STYLE = Automatic;\n'
pbx += f'\t\t\t\tDEVELOPMENT_TEAM = 8WFH238U2W;\n'
pbx += f'\t\t\t\tCURRENT_PROJECT_VERSION = 1;\n'
pbx += f'\t\t\t\tENABLE_PREVIEWS = YES;\n'
pbx += f'\t\t\t\tGENERATE_INFOPLIST_FILE = NO;\n'
pbx += f'\t\t\t\tINFOPLIST_FILE = macOS-Info.plist;\n'
pbx += f'\t\t\t\tLD_RUNPATH_SEARCH_PATHS = ("$(inherited)", "@executable_path/../Frameworks");\n'
pbx += f'\t\t\t\tMARKETING_VERSION = 1.0;\n'
pbx += f'\t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = com.chenhongzhou.linkgame;\n'
pbx += f'\t\t\t\tPRODUCT_NAME = "$(TARGET_NAME)";\n'
pbx += f'\t\t\t\tSUPPORTED_PLATFORMS = macosx;\n'
pbx += f'\t\t\t\tSWIFT_EMIT_LOC_STRINGS = YES;\n'
pbx += f'\t\t\t\tSWIFT_VERSION = 5.0;\n'
pbx += f'\t\t\t\tCODE_SIGN_ENTITLEMENTS = LinkGame.entitlements;\n'
pbx += f'\t\t\t}};\n\t\t\tname = Release;\n\t\t}};\n'

# Widget target Debug
pbx += f'\t\t{P_WIDGET_DBG} /* Debug */ = {{\n\t\t\tisa = XCBuildConfiguration;\n\t\t\tbuildSettings = {{\n'
pbx += f'\t\t\t\tCODE_SIGN_STYLE = Automatic;\n'
pbx += f'\t\t\t\tDEVELOPMENT_TEAM = 8WFH238U2W;\n'
pbx += f'\t\t\t\tCURRENT_PROJECT_VERSION = 1;\n'
pbx += f'\t\t\t\tGENERATE_INFOPLIST_FILE = NO;\n'
pbx += f'\t\t\t\tINFOPLIST_FILE = Sources/Widget/Info.plist;\n'
pbx += f'\t\t\t\tLD_RUNPATH_SEARCH_PATHS = ("$(inherited)", "@executable_path/../Frameworks", "@executable_path/../../../../Frameworks");\n'
pbx += f'\t\t\t\tMARKETING_VERSION = 1.0;\n'
pbx += f'\t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = com.chenhongzhou.linkgame.widget;\n'
pbx += f'\t\t\t\tPRODUCT_NAME = "$(TARGET_NAME)";\n'
pbx += f'\t\t\t\tSKIP_INSTALL = YES;\n'
pbx += f'\t\t\t\tSUPPORTED_PLATFORMS = macosx;\n'
pbx += f'\t\t\t\tSWIFT_EMIT_LOC_STRINGS = YES;\n'
pbx += f'\t\t\t\tSWIFT_VERSION = 5.0;\n'
pbx += f'\t\t\t}};\n\t\t\tname = Debug;\n\t\t}};\n'

# Widget target Release
pbx += f'\t\t{P_WIDGET_REL} /* Release */ = {{\n\t\t\tisa = XCBuildConfiguration;\n\t\t\tbuildSettings = {{\n'
pbx += f'\t\t\t\tCODE_SIGN_STYLE = Automatic;\n'
pbx += f'\t\t\t\tDEVELOPMENT_TEAM = 8WFH238U2W;\n'
pbx += f'\t\t\t\tCURRENT_PROJECT_VERSION = 1;\n'
pbx += f'\t\t\t\tGENERATE_INFOPLIST_FILE = NO;\n'
pbx += f'\t\t\t\tINFOPLIST_FILE = Sources/Widget/Info.plist;\n'
pbx += f'\t\t\t\tLD_RUNPATH_SEARCH_PATHS = ("$(inherited)", "@executable_path/../Frameworks", "@executable_path/../../../../Frameworks");\n'
pbx += f'\t\t\t\tMARKETING_VERSION = 1.0;\n'
pbx += f'\t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = com.chenhongzhou.linkgame.widget;\n'
pbx += f'\t\t\t\tPRODUCT_NAME = "$(TARGET_NAME)";\n'
pbx += f'\t\t\t\tSKIP_INSTALL = YES;\n'
pbx += f'\t\t\t\tSUPPORTED_PLATFORMS = macosx;\n'
pbx += f'\t\t\t\tSWIFT_EMIT_LOC_STRINGS = YES;\n'
pbx += f'\t\t\t\tSWIFT_VERSION = 5.0;\n'
pbx += f'\t\t\t}};\n\t\t\tname = Release;\n\t\t}};\n'

pbx += '/* End XCBuildConfiguration section */\n\n'

# ====== XCConfigurationList ======
pbx += '/* Begin XCConfigurationList section */\n'
pbx += f'\t\t{P_PROJ_CFG_LIST} /* Build configuration list for PBXProject "LinkGame" */ = {{\n'
pbx += f'\t\t\tisa = XCConfigurationList;\n'
pbx += f'\t\t\tbuildConfigurations = ({P_PROJ_DBG} /* Debug */, {P_PROJ_REL} /* Release */);\n'
pbx += f'\t\t\tdefaultConfigurationIsVisible = 0;\n\t\t\tdefaultConfigurationName = Release;\n\t\t}};\n'
pbx += f'\t\t{P_APP_CFG_LIST} /* Build configuration list for PBXNativeTarget "LinkGame" */ = {{\n'
pbx += f'\t\t\tisa = XCConfigurationList;\n'
pbx += f'\t\t\tbuildConfigurations = ({P_APP_DBG} /* Debug */, {P_APP_REL} /* Release */);\n'
pbx += f'\t\t\tdefaultConfigurationIsVisible = 0;\n\t\t\tdefaultConfigurationName = Release;\n\t\t}};\n'
pbx += f'\t\t{P_WIDGET_CFG_LIST} /* Build configuration list for PBXNativeTarget "LinkWidget" */ = {{\n'
pbx += f'\t\t\tisa = XCConfigurationList;\n'
pbx += f'\t\t\tbuildConfigurations = ({P_WIDGET_DBG} /* Debug */, {P_WIDGET_REL} /* Release */);\n'
pbx += f'\t\t\tdefaultConfigurationIsVisible = 0;\n\t\t\tdefaultConfigurationName = Release;\n\t\t}};\n'
pbx += '/* End XCConfigurationList section */\n'

pbx += f'\t}};\n\trootObject = {P_ROOT} /* Project object */;\n}}'

# --- Write ---
pbxproj_path = os.path.expanduser("~/linkgame/client/LinkGame.xcodeproj/project.pbxproj")
os.makedirs(os.path.dirname(pbxproj_path), exist_ok=True)
with open(pbxproj_path, "w") as f:
    f.write(pbx)

print("✅ project.pbxproj generated successfully")
print(f"   Targets: LinkGame (app) + LinkWidget (widget extension)")
print(f"   Platforms: macOS 14.0+")
