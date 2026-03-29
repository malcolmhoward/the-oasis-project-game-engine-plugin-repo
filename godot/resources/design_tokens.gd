## Arc Reactor Dark design system tokens.
##
## Color values matched to D.A.W.N. WebUI CSS variables for visual consistency.
## Typography uses the same font families as the WebUI:
##   IBM Plex Mono — system text, metrics, labels (uppercase, letter-spaced)
##   Source Sans 3 — conversation text, user-facing content (sentence case)
class_name ArcReactorDark

# ─── Backgrounds (matched to DAWN --bg-*) ───
const BG_DEEPEST     := Color("121417")  # --bg-primary
const BG_DARK        := Color("1b1f24")  # --bg-secondary, --bg-panel
const BG_MEDIUM      := Color("242a31")  # --bg-tertiary, input backgrounds
const BG_CARD        := Color("242a31")  # Same as tertiary in DAWN
const BG_ELEVATED    := Color("2a323a")  # Hover states, --ring-inactive
const BG_INPUT       := Color("242a31")  # --bg-tertiary

# ─── Primary Accent (DAWN teal: #2dd4bf) ───
const ARC_CORE       := Color("2dd4bf")  # --accent — active system behavior
const ARC_BRIGHT     := Color("2dd4bf")  # Same — DAWN doesn't brighten on hover
const ARC_GLOW       := Color8(45, 212, 191, 128)  # --accent-glow (50% alpha)
const ARC_DIM        := Color8(45, 212, 191, 77)   # --accent-dim (30% alpha)
const ARC_SUBTLE     := Color8(45, 212, 191, 15)   # --accent-subtle (6% alpha)
const ARC_HOVER      := Color8(45, 212, 191, 38)   # --accent-hover (15% alpha)
const ARC_FOCUS      := Color8(45, 212, 191, 51)   # --accent-focus (20% alpha)
const ARC_BORDER     := Color8(45, 212, 191, 26)   # --accent-border (10% alpha)

# ─── Status (matched to DAWN) ───
const STATUS_SUCCESS := Color("22c55e")  # --success
const STATUS_WARNING := Color("f0b429")  # --warning (amber, not yellow)
const STATUS_ERROR   := Color("ef4444")  # --error
const STATUS_INFO    := Color("3b82f6")  # blue

# ─── Text (matched to DAWN --text-*) ───
const TEXT_PRIMARY   := Color("e6e6e6")  # --text-primary
const TEXT_SECONDARY := Color("7b8794")  # --text-secondary
const TEXT_TERTIARY  := Color("6b7280")  # --text-tertiary
const TEXT_INVERSE   := Color("121417")  # On bright backgrounds
const TEXT_CODE      := Color("2dd4bf")  # Accent for monospace highlights

# ─── Semantic (matched to DAWN) ───
const ACCENT_GOLD    := Color("f0b429")  # --warning (amber)
const ACCENT_PURPLE  := Color("8b5cf6")  # --tool-color
const ACCENT_ORANGE  := Color("f97316")  # Orange actions
const SYSTEM_COLOR   := Color("eab308")  # --system-color (yellow)

# ─── OCP Message Types ───
const OCP_STATUS     := Color("3b82f6")  # Blue
const OCP_DISCOVERY  := Color("22c55e")  # Green (matched to --success)
const OCP_COMMAND    := Color("f97316")  # Orange

# ─── Embodiment Spectrum ───
const E1_PHYSICAL    := Color("f97316")  # Warm — hardware
const E2_REMOTE      := Color("f0b429")  # Amber — remote hardware
const E3_DIGITAL     := Color("22c55e")  # Green — virtual
const E4_SOFTWARE    := Color("3b82f6")  # Blue — software-only
const E5_HYBRID      := Color("8b5cf6")  # Purple — spans types

# ─── Borders (matched to DAWN) ───
const BORDER_DEFAULT := Color("30363d")  # Container outlines
const BORDER_FOCUS   := Color("2dd4bf")  # Focused elements (accent)
const BORDER_DIVIDER := Color("21262d")  # Separators

# ─── Typography Sizes ───
const FONT_DISPLAY   := 32   # Slide titles
const FONT_HEADING   := 24   # Section headings
const FONT_SUBHEAD   := 18   # Subsections
const FONT_BODY      := 16   # Body text (1rem)
const FONT_SMALL     := 14   # Labels, captions (0.875rem)
const FONT_TINY      := 12   # Badges, metadata (0.75rem)
const FONT_CODE      := 14   # Monospace content
const FONT_ROLE      := 10   # Role labels (0.65rem)

# ─── Spacing ───
const SPACE_XS  := 4    # Tight padding
const SPACE_SM  := 8    # 0.5rem — compact padding, flex gaps
const SPACE_MD  := 12   # 0.75rem — entry padding
const SPACE_LG  := 16   # 1rem — panel padding
const SPACE_XL  := 24   # 1.5rem — section spacing
const SPACE_XXL := 32   # 2rem — container spacing

# ─── Borders and Radii ───
const RADIUS_SM   := 4    # Small corners
const RADIUS_MD   := 8    # Standard — matched to DAWN --border-radius
const RADIUS_LG   := 12   # Large corners
const RADIUS_FULL := 999  # Pills, status dots
const BORDER_THIN := 1    # Container borders
const BORDER_ACCENT := 3  # Left accent stripe

# ─── Animation Timing (matched to DAWN --transition-*) ───
const ANIM_FAST     := 0.15  # --transition-fast (150ms)
const ANIM_NORMAL   := 0.3   # --transition-medium (300ms)
const ANIM_SLOW     := 0.5   # Panel slides
const ANIM_DRAMATIC := 0.8   # Demo morph

# ─── Message Styling ───
const MSG_USER_BG       := Color("242a31")   # --bg-tertiary
const MSG_ASSISTANT_BG  := Color8(45, 212, 191, 77)  # --accent-dim
const MSG_SYSTEM_BG     := Color8(239, 68, 68, 51)   # Red 20%
const MSG_DEBUG_BG      := Color8(139, 92, 246, 38)   # Purple 15%
const MSG_USER_MARGIN   := 32   # 2rem left margin (right-aligned)
const MSG_ASSIST_MARGIN := 32   # 2rem right margin (left-aligned)

# ─── Font Paths ───
const FONT_SANS_PATH       := "res://resources/fonts/SourceSans3-Regular.ttf"
const FONT_SANS_MEDIUM     := "res://resources/fonts/SourceSans3-Medium.ttf"
const FONT_SANS_SEMIBOLD   := "res://resources/fonts/SourceSans3-Semibold.ttf"
const FONT_SANS_BOLD       := "res://resources/fonts/SourceSans3-Bold.ttf"
const FONT_MONO_PATH       := "res://resources/fonts/IBMPlexMono-Regular.ttf"
const FONT_MONO_MEDIUM     := "res://resources/fonts/IBMPlexMono-Medium.ttf"
const FONT_MONO_SEMIBOLD   := "res://resources/fonts/IBMPlexMono-SemiBold.ttf"
const FONT_MONO_BOLD       := "res://resources/fonts/IBMPlexMono-Bold.ttf"
