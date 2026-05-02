## Presentation theme constants.
##
## Centralized typography, layout, and color overrides for
## presentation slides and the control panel. Complements
## ArcReactorDark (design_tokens.gd) which covers the demo UI.
##
## Usage:
##   $Title.add_theme_font_size_override("font_size", PresentationTheme.TITLE)
##   $Body.add_theme_font_size_override("font_size", PresentationTheme.BODY)
class_name PresentationTheme


# --- Slide Typography (pixel sizes for 1920x1080 viewport) ---

const TITLE       := 56   # Slide titles — one per slide
const HEADING     := 36   # Section headings, taglines
const SUBHEADING  := 32   # Subsection text, multi-line concepts
const BODY        := 28   # Body text, list items, descriptions
const CODE        := 24   # Monospace content, file trees, data tables
const LABEL       := 22   # Table headers, metric labels
const FOOTER      := 24   # Footer text, attributions
const CAPTION     := 20   # Alerts, small annotations
const LOG         := 16   # Log output, debug text
const CLOSING     := 72   # Closing slide title ("Thank You")


# --- Control Panel Typography ---

const CP_LABEL    := 11   # Row labels, status text, buttons
const CP_HEADER   := 11   # Component section headers
const CP_DPAD     := 14   # D-pad arrow buttons
const CP_TOPIC    := 22   # MQTT topic names (monospace)


# --- Slide Layout (Y positions for 1920x1080 viewport) ---

const TITLE_Y         := 80    # Title top position (all slides)
const TITLE_BOTTOM    := 160   # Title bottom (allows for 56pt + breathing room)
const CONTENT_START_Y := 200   # First content element (50px gap after title)
const FOOTER_Y        := 760   # Footer/tagline area


# --- Provider State Colors ---

const COLOR_LIVE    := Color("44dd88")  # Green — real data source active
const COLOR_SIM     := Color("ccaa44")  # Amber — simulated data source
const COLOR_MIXED   := Color("888888")  # Gray — mixed state (component/global)
const COLOR_ACCENT  := Color("2dd4bf")  # Teal — OCP accent (matches ArcReactorDark)
const COLOR_DIM     := Color("a0a0a0")  # Dim text for labels


# --- Panel Styling ---

const PANEL_BG        := Color("1a1e24e0")  # Slight transparency over 3D viewport
const PANEL_BORDER    := Color("2dd4bf40")  # Teal border at 25% opacity
const BTN_BG          := Color("2a3040")    # Button normal state
const BTN_ACCENT_BG   := Color("2dd4bf20")  # Toggle All button (teal tint)
const WAVEFORM_BG     := Color("0d1014")    # Waveform canvas background
const WAVEFORM_MID    := Color("333333")    # Waveform center line


# --- Component Header Colors (matches component identity) ---

const COMP_MIRAGE  := Color("00F5FC")   # M.I.R.A.G.E. primary cyan
const COMP_AURA    := Color("44dd88")   # A.U.R.A. green (sensor/nature)
const COMP_STAT    := Color("3b82f6")   # S.T.A.T. blue (system/info)
const COMP_DAWN    := Color("2dd4bf")   # D.A.W.N. teal (AI/accent)
