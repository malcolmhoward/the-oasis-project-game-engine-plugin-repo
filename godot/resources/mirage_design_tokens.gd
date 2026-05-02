## M.I.R.A.G.E. HUD design tokens.
##
## Extracted from the real M.I.R.A.G.E. C codebase (config.json,
## element_renderer.c, defines.h). Maps pixel-level HUD aesthetics
## to Godot-compatible constants for faithful recreation.
##
## Design spec source: godot/scratch/MIRAGE_DESIGN_SPEC.md
## Companion to: ArcReactorDark (design_tokens.gd) for D.A.W.N.
class_name MirageHUD


# --- Primary HUD Colors (from element_renderer.c) ---

## Bright cyan — pitch, FPS, compass heading, system time, log text
const PRIMARY_CYAN     := Color(0.0, 0.961, 0.988)      # 0x00F5FC

## Light cyan — CPU/MEM/FAN/TEMP labels, AI name, environmental labels
const SECONDARY_CYAN   := Color(0.459, 0.808, 0.980)    # 0x75CEFA

## Environmental label cyan — humidity, dew point, air quality
const ENV_CYAN         := Color(0.008, 0.875, 0.945)    # 0x02DFF1

## Orange/gold — heat index, temperature warnings
const WARNING_ORANGE   := Color(0.949, 0.573, 0.059)    # 0xF2920F

## White — all dynamic data values
const DATA_WHITE       := Color(1.0, 1.0, 1.0)          # 0xFFFFFF

## Dark gray — subdued text (units, descriptions)
const SUBDUED_GRAY     := Color(0.216, 0.365, 0.373)    # 0x375D5F

## Alert red — recording status, critical alerts
const ALERT_RED        := Color(1.0, 0.0, 0.0)          # 0xFF0000

## OCP accent — shared with Arc Reactor Dark for protocol elements
const OCP_ACCENT       := Color("2dd4bf")


# --- Armor Status Colors ---

const ARMOR_ONLINE     := Color(0.0, 0.8, 0.0)    # Green
const ARMOR_WARNING    := Color(0.9, 0.9, 0.0)    # Yellow
const ARMOR_OFFLINE    := Color(0.8, 0.0, 0.0)    # Red
const ARMOR_BASE       := Color(0.2, 0.4, 0.8)    # Blue (default/unknown)


# --- Armor Thresholds ---

const WARN_TEMP_C      := 35.0   # Component temp > this → warning
const WARN_VOLTAGE     := 3.2    # Component voltage < this → warning


# --- HUD Background ---

## Semi-transparent overlay for HUD panels on camera feed
const HUD_PANEL_BG     := Color(0.07, 0.08, 0.09, 0.6)  # Dark with 60% opacity
const HUD_BORDER       := Color(0.0, 0.961, 0.988, 0.3)  # Primary cyan at 30%


# --- Typography (font sizes for 720x720 viewport) ---
## Original M.I.R.A.G.E. uses 1440p; these are halved for 720p mode.
## Scale proportionally to actual viewport size.

const FONT_AI_NAME     := 17   # AI assistant name (34pt @ 1440 / 2)
const FONT_COMPASS     := 15   # Cardinal direction (30pt / 2)
const FONT_TIME        := 14   # System time HH:MM:SS (27pt / 2)
const FONT_PITCH       := 12   # Pitch/lat-lon values (24pt / 2)
const FONT_METRIC      := 11   # CPU/MEM/TEMP labels and values (22pt / 2)
const FONT_ALERT       := 10   # Alert text (20pt / 2)
const FONT_LOG         := 8    # Log output (16pt / 2)


# --- Layout Proportions (0.0 to 1.0, derived from 1440p positions) ---
## Use these with viewport_size * proportion for responsive positioning.

# Top bar
const TOP_BAR_Y        := 0.075   # ~108px @ 1440
const TIME_X           := 0.5     # Center-aligned (720 / 1440)
const TIME_Y           := 0.087   # 125 / 1440
const RECORD_X         := 0.413   # 595 / 1440
const RECORD_Y         := 0.076   # 109 / 1440

# Compass
const COMPASS_X        := 0.5     # Center
const COMPASS_Y        := 0.024   # 35 / 1440

# System metrics panel (top-right quadrant)
const METRICS_X        := 0.644   # 928 / 1440
const METRICS_Y        := 0.535   # 770 / 1440
const METRIC_ROW_H     := 0.017   # ~24px spacing between rows @ 1440
const METRIC_LABEL_X   := 0.861   # 1240 / 1440 (left column labels)
const METRIC_VALUE_X   := 0.962   # 1385 / 1440 (right column values)
const HELMET_LABEL_X   := 0.677   # 975 / 1440 (helmet sensor labels)
const HELMET_VALUE_X   := 0.781   # 1125 / 1440 (helmet sensor values)

# Pitch display
const PITCH_BOX_X      := 0.115   # 165 / 1440
const PITCH_BOX_Y      := 0.483   # 696 / 1440

# Center reticle
const RETICLE_X        := 0.299   # 431 / 1440
const RETICLE_Y        := 0.441   # 635 / 1440

# Map display
const MAP_X            := 0.644   # 928 / 1440
const MAP_Y            := 0.641   # 923 / 1440
const MAP_W            := 0.301   # 433 / 1440
const MAP_H            := 0.303   # 437 / 1440

# Armor display
const ARMOR_X          := 0.049   # 70 / 1440
const ARMOR_Y          := 0.625   # 900 / 1440
const ARMOR_SIZE       := 0.313   # 450 / 1440

# AI state indicator
const AI_ICON_X        := 0.939   # 1352 / 1440
const AI_ICON_Y        := 0.111   # 160 / 1440
const AI_NAME_X        := 0.983   # 1415 / 1440 (right-aligned)
const AI_NAME_Y        := 0.139   # 200 / 1440

# FPS display
const FPS_X            := 1.0     # Right-aligned
const FPS_Y            := 0.0     # Top

# WiFi signal
const WIFI_X           := 0.892   # 1285 / 1440
const WIFI_Y           := 0.473   # 681 / 1440

# Alert area
const ALERT_X          := 0.139   # 200 / 1440
const ALERT_Y          := 0.125   # 180 / 1440

# Log display
const LOG_X            := 0.146   # 210 / 1440
const LOG_Y            := 0.705   # 1015 / 1440
const LOG_W            := 0.427   # 615 / 1440
const LOG_H            := 0.240   # 345 / 1440


# --- Data Format Strings (from element_renderer.c) ---

const FMT_CPU          := "%03.0f%%"
const FMT_MEM          := "%03.0f%%"
const FMT_TEMP_C       := "%0.0f C"
const FMT_TEMP_F       := "%03.0f F"
const FMT_HUMIDITY     := "%02.0f%%"
const FMT_FPS          := "FPS: %d"
const FMT_TIME         := "%02d:%02d:%02d"
const FMT_LATLON       := "%0.02f, %0.02f"
const FMT_BATTERY_PCT  := "%0.1f%%"
const FMT_VOLTAGE      := "%0.2f V"
const FMT_CURRENT      := "%0.2f A"
const FMT_POWER        := "%0.2f W"
const FMT_AIR_QUALITY  := "%03.0f"


# --- HUD Transition Timing ---

const TRANSITION_FADE_MS   := 250
const TRANSITION_FADE_SEC  := 0.25
const TRANSITION_ZOOM_SCALE := 0.8  # Zoom starts at 80%, ends at 100%


# --- Camera Configuration ---

const CAMERA_INPUT_W   := 1280
const CAMERA_INPUT_H   := 720
const CAMERA_FPS       := 60
const CAMERA_CROP_X    := 280    # Center-crop to square
const CAMERA_CROP_W    := 720


# --- AI State Names ---

const AI_IDLE          := "idle"       # Grey icon
const AI_LISTENING     := "listening"  # Green icon
const AI_WAKEWORD      := "wakeword"   # Purple icon
const AI_PROCESSING    := "processing" # Red icon


# --- Font Paths (shared with Arc Reactor Dark) ---

const FONT_MONO_PATH   := "res://resources/fonts/IBMPlexMono-Regular.ttf"
const FONT_SANS_PATH   := "res://resources/fonts/SourceSans3-Regular.ttf"
## M.I.R.A.G.E. uses Dev Gothic and Aldrich — not bundled yet.
## Fallback to IBM Plex Mono (similar monospace HUD aesthetic).
