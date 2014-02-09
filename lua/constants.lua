package.path = "?.lua;../hbs-tools/lua-modules/lib/?.lua;../lua-modules/lib/?.lua;../modules/lib/?.lua"
local device = require("device")
ACU_BUNDLE_ID = "com.myGame.bundleId"
ANDROID_PRODUCT_ID = "com.myGame.productId"
GOOGLE_STORE_PREFIX = "gp"
AMAZON_STORE_PREFIX = "as"
VERSION = MOAIEnvironment.getAppVersion()
if VERSION == nil or VERSION == "UNKNOWN" then
  do
    local versioned
    local prop = io.open("../project.properties", "r")
    if prop then
      for lines in prop:lines() do
        if lines:find("bundle.version.short=") then
          VERSION = lines:match("%s*=(.+)")
          versioned = true
          break
        end
      end
      prop:close()
    end
    if not versioned then
      VERSION = "dev"
      ACU_VERSION = "dev"
    else
      ACU_VERSION = VERSION:match("^(%d+%.%d+)") .. "dev"
    end
  end
else
  ACU_VERSION = VERSION:match("^(%d+%.%d+)")
  local channel = VERSION:match("%(([^%)]+)%)$")
  if channel ~= nil then
    ACU_VERSION = ACU_VERSION .. channel
  end
end
assert(ACU_BUNDLE_ID ~= "UNKNOWN" and ACU_BUNDLE_ID ~= nil, "invalid bundle id")
print()
print("\tAppId:      ", ACU_BUNDLE_ID)
print("\tAppVersion: ", VERSION)
print("\tACU:        ", ACU_VERSION)
print()
APPCACHE_URL = "http://strikefleet-acu.harebrained-schemes.com/" .. ACU_BUNDLE_ID .. "/" .. ACU_VERSION .. "/manifest.jws"
MOAI_CLOUD_CLIENT_KEY = "wKkgmPN3XUDaKdk3dNSNrQGRlqWU58m5"
MOAI_CLOUD_CLIENT_SECRET = "URFZJSZVTBauhXBCY66jBgJXfcweots2mxwHhOQuygIsAzRHmW"
WORLD_SCL = 1
WAVE_COUNT = 25
WAVE_TIME = 10
SOURCE_ENTITY_LUA_FILE = "SourceEntityDef.lua"
DISPLAY_DEBUG_INFO = false
DEBUG_STORE = false
DEBUG_PHYSICS = false
DEBUG_CONSTRUCTION_SPAWN = false
SIMULATE_LOW_FILL = false
SIMULATE_LOW_CPU = false
if SIMULATE_LOW_FILL then
  device.fill = device.FILL_RATE_LO
end
if SIMULATE_LOW_CPU then
  device.cpu = device.CPU_LO
end
SIXWAVES_GC_LEADERBOARDS = "com.6waves.strikefleetomega.survival.highscore"
USE_PATH_DELTA = false
USE_DELTA_WHEN_CAPTURING = false
USE_MODULE_DPI = true
MODULE_WORLD_SIZE = 80
MODULE_PIXEL_SIZE = 160
SHIELD_RECHARGE_TIME = 3
DRIFT_SPEED = 30
WRECKAGE_SPEED = 15
WRECKAGE_SPEED_SPC = 30
WRECKAGE_ROT = 4
RESOURCE_GENERATION_RATE = 0.5
RESOURCE_START_BLUE = 50
DOCKING_EPSILON = 10
DEFAULT_LEVEL_SIZE = 960
DEFAULT_LOC_VARIANCE = 130
BG1_PARALLAX = 0.04
BG2_PARALLAX = 1.8
GALAXYMAP1_PARALLAX = 0.1
GALAXYMAP2_PARALLAX = 1
JUNK_PARALLAX = 0.3
HOVER_ACTIVATION_TIME = 2
FONTS = {
  [device.ASSET_MODE_X_HI] = {
    FONT_SMALL = "fonts/EurostileDemi@36",
    FONT_SMALL_BOLD = "fonts/EurostileDemi@36",
    FONT_MEDIUM = "fonts/EurostileNormal@52",
    FONT_MEDIUM_BOLD = "fonts/EurostileDemi@52",
    FONT_LARGE = "fonts/EurostileDemi@80",
    FONT_XLARGE = "fonts/CCTheStorySoFar@102"
  },
  [device.ASSET_MODE_HI] = {
    FONT_SMALL = "fonts/EurostileDemi@18",
    FONT_SMALL_BOLD = "fonts/EurostileDemi@18",
    FONT_MEDIUM = "fonts/EurostileNormal@26",
    FONT_MEDIUM_BOLD = "fonts/EurostileDemi@26",
    FONT_LARGE = "fonts/EurostileDemi@40",
    FONT_XLARGE = "fonts/CCTheStorySoFar@52"
  },
  [device.ASSET_MODE_LO] = {
    FONT_SMALL = "fonts/EurostileDemi@10",
    FONT_SMALL_BOLD = "fonts/EurostileDemi@10",
    FONT_MEDIUM = "fonts/EurostileNormal@13",
    FONT_MEDIUM_BOLD = "fonts/EurostileDemi@13",
    FONT_LARGE = "fonts/EurostileDemi@20",
    FONT_XLARGE = "fonts/CCTheStorySoFar@26"
  }
}
for k, v in pairs(FONTS[device.ui_assetrez] or FONTS[device.ASSET_MODE_HI]) do
  _G[k] = v
end
SQUAD_SELECTOR_WIDTH_INCHES = 0.33
SQUAD_SELECTOR_SIZE_PIXELS = 148
WEAPON_INEFFECTIVE_MOD = 0.3
WEAPON_SUPER_EFFECTIVE_MOD = 0.9
MISSILE_ZOOM_MULTIPLIER = 8
MISSILE_ZOOM_DAMAGE_MULTIPLIER = 5
MISSILE_BOOM_DAMAGE_MULTIPLIER = 2
MISSILE_BOOM_RADIUS = 150
PATH_ACTIVE_WIDTH = 3
PATH_INACTIVE_WIDTH = 1
PATH_DRAG_THRESHOLD = 80
PATH_LOOP_THRESHOLD = 50
PATH_MAX_USER_POINTS = 250
ALLOY_NAME = "alloy"
CREDS_NAME = "creds"
SCORE_XP_THRESHOLD = 1
OMEGA_TIME = 8
OMEGA_DELAY = 5
FOG_PIXELS_PER_SECOND = -125
BG_PIXELS_PER_SECOND = -4
MIN_DUST_DIR = 270
MAX_DUST_DIR = 270
MIN_SPACE_DUST = 15
MAX_SPACE_DUST = 18
SPACE_DUST_SPEED = 1000
SPACE_DUST_VARIANCE = 100
MIN_SPACE_DUST_OPACITY = 0.1
MAX_SPACE_DUST_OPACITY = 0.35
MIN_DUST_RESET_TIME = 0.1
MAX_DUST_RESET_TIME = 0.1
MIN_JUNK_DIR = 260
MAX_JUNK_DIR = 280
MIN_JUNK_OBJECTS = 5
MAX_JUNK_OBJECTS = 6
JUNK_SPEED = 20
JUNK_VARIANCE = 5
MIN_JUNK_SCALE = 1.2
MAX_JUNK_SCALE = 1.5
MIN_JUNK_ROT_SPEED = 1
MAX_JUNK_ROT_SPEED = 2
MIN_JUNK_RESET_TIME = 0.1
MAX_JUNK_RESET_TIME = 0.1
MIN_FOG_DIR = 280
MAX_FOG_DIR = 300
if device.fill == device.FILL_RATE_LO then
  MIN_FOG_OBJECTS = 4
  MAX_FOG_OBJECTS = 4
else
  MIN_FOG_OBJECTS = 10
  MAX_FOG_OBJECTS = 12
end
FOG_SPEED = 80
FOG_VARIANCE = 5
MIN_FOG_SCALE = 1.75
MAX_FOG_SCALE = 2.25
MIN_FOG_OPACITY = 0.42
MAX_FOG_OPACITY = 0.72
MIN_FOG_ROT_SPEED = 5
MAX_FOG_ROT_SPEED = 10
MIN_FOG_RESET_TIME = 0.01
MAX_FOG_RESET_TIME = 0.01
CAPITAL_SHIP_SPAWN_RADIUS = 220
DEATH_BLOSSOM_X = 0
DEATH_BLOSSOM_Y = 38
SURVIVOR_DRIVE_SPEED = 0.1
UI_BAR_HEIGHT = 122
UI_BAR_HEIGHT_SURVIVAL = 130
UI_TOP_BAR_COLOR = "#161616A5"
UI_TOUCH_DOWN_COLOR = {
  0.2,
  0.73,
  0.95,
  1
}
UI_FILL_COLOR_HEX = "#7c7c77ff"
UI_FILL_COLOR = {
  0.49,
  0.49,
  0.47,
  1
}
UI_FILL_RED_COLOR_HEX = "#e6510f"
UI_FILL_RED_COLOR = {
  0.9,
  0.31,
  0.05,
  1
}
UI_OFFSCREEN_OFF_COLOR = {
  1,
  0.6862745098039216,
  0.1568627450980392,
  0.75
}
UI_DROP_SHADOW_COLOR = {
  0,
  0,
  0,
  0.5
}
UI_FADE_COLOR = {
  0.6,
  0.6,
  0.6,
  0.6
}
UI_COLOR_GRAY = {
  0.651,
  0.651,
  0.651,
  1
}
UI_COLOR_GRAY_HEX = "#a6a6a6"
UI_COLOR_GRAY_DARKEN = {
  0.3255,
  0.3255,
  0.3255,
  1
}
UI_COLOR_GRAY_DARKEN_HEX = "#535353"
UI_COLOR_BLUE = {
  0.2078,
  0.7529,
  0.9725,
  1
}
UI_COLOR_BLUE_HEX = "#38cdff"
UI_COLOR_BLUE_DARKEN = {
  0.1039,
  0.37645,
  0.48625,
  1
}
UI_COLOR_BLUE_DARKEN_HEX = "#1c667f"
UI_COLOR_GREEN = {
  0.69,
  0.788,
  0.33725,
  1
}
UI_COLOR_GREEN_HEX = "#b2c956"
UI_COLOR_GREEN_DARKEN = {
  0.345,
  0.394,
  0.168625,
  1
}
UI_COLOR_GREEN_DARKEN_HEX = "#58642b"
UI_COLOR_GOLD = {
  0.898,
  0.714,
  0.215,
  1
}
UI_COLOR_GOLD_HEX = "#e5b637"
UI_COLOR_GOLD_DARKEN = {
  0.449,
  0.357,
  0.1075,
  1
}
UI_COLOR_GOLD_DARKEN_HEX = "#725b1b"
UI_COLOR_RED = {
  0.80784,
  0.2941,
  0.0666,
  1
}
UI_COLOR_RED_HEX = "#ce4b11"
UI_COLOR_RED_DARKEN = {
  0.40392,
  0.14705,
  0.0333,
  1
}
UI_COLOR_RED_DARKEN_HEX = "#672508"
UI_COLOR_YELLOW = {
  1,
  0.788,
  0.2235,
  1
}
UI_COLOR_YELLOW_HEX = "#ffc939"
UI_COLOR_YELLOW_DARKEN = {
  0.5,
  0.394,
  0.11175,
  1
}
UI_COLOR_YELLOW_DARKEN_HEX = "#7f641c"
UI_COLOR_ORANGE = {
  0.90196,
  0.317647,
  0.05882353,
  1
}
UI_COLOR_ORANGE_HEX = "#fe7f24"
UI_CREDITS_TITLE_COLOR = {
  0.49804,
  0.764706,
  0.8705883,
  1
}
UI_SHIP_COLOR_ALL = {
  0.737255,
  0.87843,
  0.9333,
  1
}
UI_SHIP_COLOR_ALL_DARKEN = {
  0.3686275,
  0.439215,
  0.46665,
  1
}
UI_SHIP_COLOR_ALL_HEX = "bce0ee"
UI_SHIP_COLOR_FIGHTERS = {
  0.701961,
  0.87451,
  0.302,
  1
}
UI_SHIP_COLOR_FIGHTERS_DARKEN = {
  0.3509805,
  0.437255,
  0.151,
  1
}
UI_SHIP_COLOR_FIGHTERS_HEX = "a9de4e"
UI_SHIP_COLOR_INTERCEPTORS = {
  0.8902,
  0.85882,
  0.254902,
  1
}
UI_SHIP_COLOR_INTERCEPTORS_DARKEN = {
  0.4451,
  0.42941,
  0.127451,
  1
}
UI_SHIP_COLOR_INTERCEPTORS_HEX = "e3db41"
UI_SHIP_COLOR_BOMBERS = {
  0.94902,
  0.71373,
  0.207843,
  1
}
UI_SHIP_COLOR_BOMBERS_DARKEN = {
  0.47451,
  0.356865,
  0.1039215,
  1
}
UI_SHIP_COLOR_BOMBERS_HEX = "f2b635"
UI_SHIP_COLOR_DEFENSE = {
  0.20392,
  0.72941,
  0.937255,
  1
}
UI_SHIP_COLOR_DEFENSE_DARKEN = {
  0.10196,
  0.364705,
  0.4686275,
  1
}
UI_SHIP_COLOR_DEFENSE_HEX = "34BCF2"
UI_SHIP_COLOR_SPECIAL = {
  0.99608,
  0.49804,
  0.141177,
  1
}
UI_SHIP_COLOR_SPECIAL_DARKEN = {
  0.49804,
  0.24902,
  0.0705885,
  1
}
UI_SHIP_COLOR_SPECIAL_HEX = "fe8025"
UI_SHIP_COLOR_TESLA_HEX = "f0872c"
UI_BUOY_IND_COLOR = {
  0.72,
  0.83,
  0.34,
  1
}
UI_BUOY_IND_COLOR_HEX = "bad657"
UI_UNIT_BUILD_BAR_LENGTH = 36
UI_UNIT_BUILD_BAR_HEIGHT = 6
ENEMY_SPAWN_CHANCE = 0.85
ENEMY_SPAWN_PULSE = 0.2
CONSTRUCTION_BUILD_TIME = 10
CONSTRUCTION_ANGLE_STEP = 120
CONSTRUCTION_NEW_BUILD_STEP = 45
ARTILLERY_HIT_FX = "fighterImpactLarge.pex"
ARTILLERY_TARGET_TYPES = {
  enemyf = true,
  enemyb = true,
  enemyc = true,
  saucer = true
}
FIGHTER_TARGET_TYPES = {enemyf = 1, enemyb = 1}
FIGHTER_COLLECT_TYPES = {
  resource = true,
  powerup = true,
  crate = true
}
MINER_FLEE_TYPES = {enemyf = true, enemyb = true}
MINER_TARGET_TYPES = {asteroid = true, resource = true}
ALL_ENEMY_TARGET_TYPES = {
  enemyf = true,
  enemyb = true,
  enemyc = true
}
ASTEROID_TARGET_TYPES = {fighter = true, miner = true}
ENEMY_TARGET_TYPES = {
  fighter = true,
  harvester = true,
  survivor = true
}
ENEMYB_TARGET_TYPES = {capitalship = true}
OFFSCREEN_LOC = 10000
UI_MESSAGE_BOMBER = "Enemy bombers! Warp in a Counter-Bomber Carrier!"
UI_MESSAGE_ARTILLERY = "Captain! Something's coming. Something BIG."
UI_MESSAGE_LAST_WAVE = "Captain! Massive wave of enemies approaching!"
UI_MESSAGE_LEVEL = {
  "",
  "",
  "",
  "",
  "",
  "",
  "",
  UI_MESSAGE_BOMBER,
  "",
  "",
  "",
  UI_MESSAGE_ARTILLERY,
  "",
  "",
  "",
  "",
  "",
  "",
  "",
  UI_MESSAGE_LAST_WAVE
}
