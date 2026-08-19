"""
PEDI-GUIDE AI — Production-Grade 3-Column Clinical Dashboard
==============================================================
Streamlit application implementing the WHO IMCI Clinical Decision Support System.

Features:
- 3-column clinical dashboard (Assessment | Evidence | PDF Preview)
- Dual vector DB backend switching (ChromaDB / Pinecone)
- Quick demo case buttons for live demonstrations
- Triage-colored result cards with confidence gauges
- Evidence explainability with auto-tagged "Used/Not used" badges
- Live PDF page preview with navigation (Next/Prev)
- Session history with triage badges
- Dark clinical theme with glassmorphism styling
"""

import os
import re
import streamlit as st

# ─────────────────────────────────────────────
# PDF RENDERING (lazy import — may not be installed)
# ─────────────────────────────────────────────
try:
    import pymupdf as fitz  # PyMuPDF (new import name)
    PYMUPDF_AVAILABLE = True
except ImportError:
    try:
        import fitz  # Fallback for older PyMuPDF versions
        PYMUPDF_AVAILABLE = True
    except ImportError:
        PYMUPDF_AVAILABLE = False

try:
    from PIL import Image
    import io
    PIL_AVAILABLE = True
except ImportError:
    PIL_AVAILABLE = False

from doctor_assistant import (
    run_clinical_query,
    PINECONE_AVAILABLE,
    CONFIDENCE_THRESHOLD,
    DOCUMENT_TITLE,
)

# ─────────────────────────────────────────────
# PAGE CONFIG
# ─────────────────────────────────────────────

st.set_page_config(
    page_title="PEDI-GUIDE AI — WHO IMCI Clinical Decision Support",
    page_icon="🩺",
    layout="wide",
    initial_sidebar_state="expanded",
)

# ─────────────────────────────────────────────
# CONSTANTS
# ─────────────────────────────────────────────

DEMO_CASES = {
    "🚨 General Danger Signs": "child not able to drink or breastfeed, vomiting everything, convulsions, lethargic or unconscious",
    "🫁 Severe Pneumonia": "6 month old child with cough for 5 days, fast breathing 58 breaths per minute, chest indrawing, stridor when calm",
    "🌐 Arabic Query (حالة عربية)": "رضيع عمره 3 شهور عنده صعوبة في الرضاعة مع سرعة تنفس وحرارة منخفضة وصفار في الجلد",
    "🛡️ Out-of-Scope (Refusal)": "What is the recommended nitroglycerin dosage for adult coronary artery disease?",
}

PDF_SEARCH_PATHS = [
    "WHO.pdf",
    "temp/WHO.pdf",
    os.path.join("temp", "WHO.pdf"),
    os.path.join(os.path.dirname(__file__), "WHO.pdf"),
    os.path.join(os.path.dirname(__file__), "temp", "WHO.pdf"),
]

# ─────────────────────────────────────────────
# PDF UTILITIES
# ─────────────────────────────────────────────


def find_pdf_path() -> str | None:
    """Search for WHO.pdf in multiple known locations."""
    for p in PDF_SEARCH_PATHS:
        if os.path.isfile(p):
            return os.path.abspath(p)
    return None


@st.cache_data(show_spinner=False)
def render_pdf_page(pdf_path: str, page_number: int, zoom: float = 2.0) -> bytes | None:
    """Render a single PDF page as PNG bytes using PyMuPDF."""
    if not PYMUPDF_AVAILABLE or not pdf_path or not os.path.isfile(pdf_path):
        return None
    try:
        doc = fitz.open(pdf_path)
        if page_number < 1 or page_number > len(doc):
            doc.close()
            return None
        page = doc.load_page(page_number - 1)  # 0-indexed
        mat = fitz.Matrix(zoom, zoom)
        pix = page.get_pixmap(matrix=mat)
        img_bytes = pix.tobytes("png")
        doc.close()
        return img_bytes
    except Exception:
        return None


@st.cache_data(show_spinner=False)
def get_pdf_page_count(pdf_path: str) -> int:
    """Get total page count of the PDF."""
    if not PYMUPDF_AVAILABLE or not pdf_path:
        return 0
    try:
        doc = fitz.open(pdf_path)
        count = len(doc)
        doc.close()
        return count
    except Exception:
        return 0


# ─────────────────────────────────────────────
# CUSTOM CSS
# ─────────────────────────────────────────────

CUSTOM_CSS = """
<style>
/* ── Import professional font ── */
@import url('https://fonts.googleapis.com/css2?family=Inter:wght@300;400;500;600;700;800&display=swap');

/* ── Global overrides ── */
.stApp {
    font-family: 'Inter', -apple-system, BlinkMacSystemFont, sans-serif;
}

/* ── Main header ── */
.main-header {
    text-align: center;
    padding: 1.2rem 0 0.8rem 0;
    margin-bottom: 0.5rem;
}
.main-header h1 {
    font-size: 2rem;
    font-weight: 800;
    background: linear-gradient(135deg, #00d2ff 0%, #3a7bd5 50%, #6dd5fa 100%);
    -webkit-background-clip: text;
    -webkit-text-fill-color: transparent;
    background-clip: text;
    margin: 0;
    letter-spacing: -0.5px;
}
.main-header p {
    color: #94a3b8;
    font-size: 0.92rem;
    margin-top: 0.25rem;
    font-weight: 400;
}

/* ── Triage cards ── */
.triage-card {
    border-radius: 14px;
    padding: 1.4rem 1.6rem;
    margin: 0.8rem 0;
    backdrop-filter: blur(12px);
    border: 1px solid rgba(255,255,255,0.08);
    box-shadow: 0 8px 32px rgba(0,0,0,0.25);
}
.triage-red {
    background: linear-gradient(135deg, rgba(220,38,38,0.18) 0%, rgba(185,28,28,0.12) 100%);
    border-left: 5px solid #ef4444;
}
.triage-yellow {
    background: linear-gradient(135deg, rgba(245,158,11,0.18) 0%, rgba(217,119,6,0.12) 100%);
    border-left: 5px solid #f59e0b;
}
.triage-green {
    background: linear-gradient(135deg, rgba(34,197,94,0.18) 0%, rgba(22,163,74,0.12) 100%);
    border-left: 5px solid #22c55e;
}
.triage-refusal {
    background: linear-gradient(135deg, rgba(100,116,139,0.18) 0%, rgba(71,85,105,0.12) 100%);
    border-left: 5px solid #64748b;
}

.triage-label {
    font-size: 1.1rem;
    font-weight: 700;
    margin-bottom: 0.5rem;
}

/* ── Evidence chunk cards ── */
.evidence-card {
    background: rgba(30, 41, 59, 0.5);
    backdrop-filter: blur(10px);
    border: 1px solid rgba(255,255,255,0.06);
    border-radius: 12px;
    padding: 1.1rem 1.2rem;
    margin-bottom: 0.8rem;
    transition: all 0.2s ease;
    box-shadow: 0 4px 16px rgba(0,0,0,0.15);
}
.evidence-card:hover {
    border-color: rgba(59, 130, 246, 0.3);
    box-shadow: 0 4px 24px rgba(59, 130, 246, 0.12);
    transform: translateY(-1px);
}

/* ── Score badges ── */
.score-badge {
    display: inline-block;
    padding: 0.2rem 0.65rem;
    border-radius: 20px;
    font-size: 0.78rem;
    font-weight: 600;
    letter-spacing: 0.3px;
}
.score-high { background: rgba(34,197,94,0.2); color: #4ade80; }
.score-medium { background: rgba(245,158,11,0.2); color: #fbbf24; }
.score-low { background: rgba(239,68,68,0.2); color: #f87171; }

.used-badge {
    display: inline-block;
    padding: 0.15rem 0.55rem;
    border-radius: 20px;
    font-size: 0.72rem;
    font-weight: 600;
    margin-left: 0.4rem;
}
.used-yes { background: rgba(34,197,94,0.2); color: #4ade80; }
.used-no { background: rgba(100,116,139,0.2); color: #94a3b8; }

/* ── Confidence gauge ── */
.confidence-gauge {
    display: inline-block;
    padding: 0.3rem 0.9rem;
    border-radius: 20px;
    font-size: 0.85rem;
    font-weight: 700;
    letter-spacing: 0.5px;
}
.conf-high { background: linear-gradient(135deg, #22c55e, #16a34a); color: white; }
.conf-medium { background: linear-gradient(135deg, #f59e0b, #d97706); color: white; }
.conf-low { background: linear-gradient(135deg, #ef4444, #dc2626); color: white; }

/* ── Section headers ── */
.section-header {
    font-size: 0.92rem;
    font-weight: 700;
    color: #cbd5e1;
    text-transform: uppercase;
    letter-spacing: 1.2px;
    padding-bottom: 0.5rem;
    border-bottom: 2px solid rgba(59,130,246,0.3);
    margin-bottom: 0.8rem;
}

/* ── PDF viewer ── */
.pdf-nav-btn {
    display: inline-block;
    padding: 0.3rem 0.8rem;
    border-radius: 8px;
    font-weight: 600;
    font-size: 0.82rem;
}

/* ── Demo buttons row ── */
.demo-btn-row {
    display: flex;
    flex-wrap: wrap;
    gap: 0.4rem;
    margin-bottom: 0.8rem;
}

/* ── Sidebar styling ── */
[data-testid="stSidebar"] {
    background: linear-gradient(180deg, #0f172a 0%, #1e293b 100%);
}

/* ── Citation table styling ── */
.citation-table {
    width: 100%;
    border-collapse: collapse;
    font-size: 0.82rem;
}
.citation-table th {
    background: rgba(59,130,246,0.15);
    color: #93c5fd;
    padding: 0.5rem 0.7rem;
    text-align: left;
    font-weight: 600;
    border-bottom: 2px solid rgba(59,130,246,0.3);
}
.citation-table td {
    padding: 0.4rem 0.7rem;
    border-bottom: 1px solid rgba(255,255,255,0.05);
    color: #cbd5e1;
}
.citation-table tr:hover td {
    background: rgba(59,130,246,0.05);
}

/* ── Sidebar history badges ── */
.history-badge {
    display: inline-block;
    width: 10px;
    height: 10px;
    border-radius: 50%;
    margin-right: 6px;
}
.hb-red { background: #ef4444; }
.hb-yellow { background: #f59e0b; }
.hb-green { background: #22c55e; }
.hb-gray { background: #64748b; }
</style>
"""


# ─────────────────────────────────────────────
# SESSION STATE INITIALIZATION
# ─────────────────────────────────────────────

def init_session_state():
    """Initialize all session state variables."""
    defaults = {
        "history": [],           # List of {query, result} dicts
        "current_result": None,  # Latest query result dict
        "current_query": "",     # Latest query text
        "pdf_page": 1,           # Current PDF viewer page
        "demo_query": None,      # Demo case to auto-fill
    }
    for key, val in defaults.items():
        if key not in st.session_state:
            st.session_state[key] = val


# ─────────────────────────────────────────────
# HELPER RENDERERS
# ─────────────────────────────────────────────

def get_triage_config(level: str) -> dict:
    """Return display config for a triage level."""
    configs = {
        "RED": {
            "css": "triage-red",
            "emoji": "🔴",
            "label": "URGENT REFERRAL",
            "desc": "Pre-referral treatment & immediate hospital referral required",
            "color": "#ef4444",
        },
        "YELLOW": {
            "css": "triage-yellow",
            "emoji": "🟡",
            "label": "CLINIC TREATMENT",
            "desc": "Specific medical treatment at clinic with follow-up",
            "color": "#f59e0b",
        },
        "GREEN": {
            "css": "triage-green",
            "emoji": "🟢",
            "label": "HOME MANAGEMENT",
            "desc": "Supportive home care, feeding, and fluids",
            "color": "#22c55e",
        },
        "REFUSAL": {
            "css": "triage-refusal",
            "emoji": "🛡️",
            "label": "OUT OF SCOPE / REFUSAL",
            "desc": "Query outside IMCI guidelines scope",
            "color": "#64748b",
        },
    }
    return configs.get(level, configs["REFUSAL"])


def get_score_badge_html(score: float) -> str:
    """Generate HTML for a cosine similarity score badge."""
    if score >= 70:
        cls = "score-high"
    elif score >= 55:
        cls = "score-medium"
    else:
        cls = "score-low"
    return f'<span class="score-badge {cls}">{score:.1f}% Match</span>'


def get_confidence_html(confidence: str, score: float) -> str:
    """Generate HTML for the confidence gauge."""
    cls_map = {"HIGH": "conf-high", "MEDIUM": "conf-medium", "LOW": "conf-low"}
    emoji_map = {"HIGH": "🟢", "MEDIUM": "🟡", "LOW": "🔴"}
    cls = cls_map.get(confidence, "conf-low")
    emoji = emoji_map.get(confidence, "🔴")
    return (
        f'<span class="confidence-gauge {cls}">'
        f'{emoji} {confidence} — {score:.1f}%</span>'
    )


def render_triage_card(result: dict):
    """Render the triage classification card."""
    cfg = get_triage_config(result["triage_level"])
    st.markdown(
        f"""
        <div class="triage-card {cfg['css']}">
            <div class="triage-label">{cfg['emoji']} {cfg['label']}</div>
            <div style="color:#94a3b8; font-size:0.85rem;">{cfg['desc']}</div>
        </div>
        """,
        unsafe_allow_html=True,
    )


def render_citation_table(result: dict):
    """Render the citation metadata table."""
    chunks = result.get("chunks", [])
    cited_pages = result.get("cited_pages", [])
    if not chunks:
        return

    rows_html = ""
    for i, chunk in enumerate(chunks, 1):
        page = chunk.get("page", "N/A")
        section = chunk.get("section", "N/A")
        # Truncate section title
        if len(str(section)) > 60:
            section = str(section)[:57] + "..."
        used = chunk.get("used", False)
        used_icon = "✅" if used else "—"
        rows_html += f"""
        <tr>
            <td>{i}</td>
            <td>{DOCUMENT_TITLE}</td>
            <td>{section}</td>
            <td>p. {page}</td>
            <td style="text-align:center">{used_icon}</td>
        </tr>
        """

    st.markdown(
        f"""
        <table class="citation-table">
            <thead>
                <tr>
                    <th>#</th>
                    <th>Document</th>
                    <th>Section</th>
                    <th>Page</th>
                    <th>Cited</th>
                </tr>
            </thead>
            <tbody>{rows_html}</tbody>
        </table>
        """,
        unsafe_allow_html=True,
    )


# ─────────────────────────────────────────────
# SIDEBAR
# ─────────────────────────────────────────────

def render_sidebar():
    """Render the sidebar configuration panel."""
    with st.sidebar:
        st.markdown("## ⚙️ Configuration")

        st.markdown("---")

        # API Keys
        st.markdown("#### 🔑 API Keys")
        gemini_key = st.text_input(
            "Gemini API Key",
            value=os.getenv("GEMINI_API_KEY", ""),
            type="password",
            help="Override the .env Gemini API key",
        )
        pinecone_key = st.text_input(
            "Pinecone API Key",
            value=os.getenv("PINECONE_API_KEY", ""),
            type="password",
            help="Override the .env Pinecone API key",
        )

        st.markdown("---")

        # Backend DB Toggle
        st.markdown("#### 🗄️ Vector Database")
        backend_options = ["ChromaDB (Local)"]
        if PINECONE_AVAILABLE:
            backend_options.append("Pinecone (Cloud)")

        backend_label = st.radio(
            "Select Backend",
            options=backend_options,
            index=0,
            horizontal=True,
        )
        backend = "chroma" if "ChromaDB" in backend_label else "pinecone"

        if PINECONE_AVAILABLE:
            st.success("🌲 Pinecone: Connected", icon="✅")
        else:
            st.warning("🌲 Pinecone: Unavailable", icon="⚠️")

        st.markdown("---")

        # Thresholds
        st.markdown("#### 🎚️ Parameters")
        threshold = st.slider(
            "Confidence Threshold (%)",
            min_value=30.0,
            max_value=80.0,
            value=CONFIDENCE_THRESHOLD,
            step=0.5,
            help="Minimum cosine similarity to allow LLM generation",
        )

        top_k = st.slider(
            "Top-K Evidence Chunks",
            min_value=2,
            max_value=8,
            value=4,
            step=1,
        )

        st.markdown("---")

        # Session History
        st.markdown("#### 📋 Session History")
        history = st.session_state.get("history", [])
        if not history:
            st.caption("No queries yet.")
        else:
            for i, entry in enumerate(reversed(history)):
                triage = entry.get("result", {}).get("triage_level", "REFUSAL")
                badge_cls = {
                    "RED": "hb-red",
                    "YELLOW": "hb-yellow",
                    "GREEN": "hb-green",
                    "REFUSAL": "hb-gray",
                }.get(triage, "hb-gray")

                query_short = entry["query"][:45] + ("..." if len(entry["query"]) > 45 else "")
                if st.button(
                    f"{'🔴' if triage == 'RED' else '🟡' if triage == 'YELLOW' else '🟢' if triage == 'GREEN' else '🛡️'} {query_short}",
                    key=f"hist_{i}",
                    use_container_width=True,
                ):
                    st.session_state["current_result"] = entry["result"]
                    st.session_state["current_query"] = entry["query"]

        st.markdown("---")
        st.caption("🩺 PEDI-GUIDE AI v2.0 — WHO IMCI Guidelines")
        st.caption("Built with Streamlit + ChromaDB/Pinecone + Gemini")

    return {
        "gemini_key": gemini_key,
        "pinecone_key": pinecone_key,
        "backend": backend,
        "threshold": threshold,
        "top_k": top_k,
    }


# ─────────────────────────────────────────────
# MAIN APPLICATION
# ─────────────────────────────────────────────

def main():
    """Main Streamlit application entry point."""
    init_session_state()

    # Inject CSS
    st.markdown(CUSTOM_CSS, unsafe_allow_html=True)

    # Header
    st.markdown(
        """
        <div class="main-header">
            <h1>🩺 PEDI-GUIDE AI</h1>
            <p>WHO IMCI Clinical Decision Support System — Evidence-Grounded Pediatric Triage</p>
        </div>
        """,
        unsafe_allow_html=True,
    )

    # Sidebar
    config = render_sidebar()

    # PDF path discovery
    pdf_path = find_pdf_path()

    # ══════════════════════════════════════════
    # QUICK DEMO CASE BUTTONS
    # ══════════════════════════════════════════
    st.markdown('<div class="section-header">⚡ Quick Demo Cases</div>', unsafe_allow_html=True)
    demo_cols = st.columns(len(DEMO_CASES))
    for idx, (label, query) in enumerate(DEMO_CASES.items()):
        with demo_cols[idx]:
            if st.button(label, key=f"demo_{idx}", use_container_width=True):
                st.session_state["demo_query"] = query

    # ══════════════════════════════════════════
    # INPUT AREA
    # ══════════════════════════════════════════
    prefill = st.session_state.get("demo_query", "")

    input_col1, input_col2 = st.columns([5, 1])
    with input_col1:
        user_query = st.text_area(
            "📝 Clinical Scenario",
            value=prefill,
            height=100,
            placeholder="Describe the clinical case... (English or Arabic)\nمثال: طفل عمره ٦ أشهر مع حمى شديدة وتقيؤ متكرر",
            key="query_input",
        )
    with input_col2:
        st.markdown("<br>", unsafe_allow_html=True)
        analyze_clicked = st.button(
            "🔍 Analyze Case",
            type="primary",
            use_container_width=True,
        )

    # Clear demo_query after it's been consumed
    if prefill:
        st.session_state["demo_query"] = None

    # ══════════════════════════════════════════
    # EXECUTE QUERY
    # ══════════════════════════════════════════
    if analyze_clicked and user_query.strip():
        with st.spinner("🧠 Analyzing clinical scenario... Retrieving evidence and generating assessment..."):
            result = run_clinical_query(
                doctor_query=user_query.strip(),
                backend=config["backend"],
                top_k=config["top_k"],
                threshold=config["threshold"],
                api_key=config["gemini_key"],
            )
            st.session_state["current_result"] = result
            st.session_state["current_query"] = user_query.strip()

            # Set PDF page to first cited page
            cited = result.get("cited_pages", [])
            if cited:
                st.session_state["pdf_page"] = cited[0]

            # Save to history
            st.session_state["history"].append(
                {"query": user_query.strip(), "result": result}
            )

    # ══════════════════════════════════════════
    # 3-COLUMN DASHBOARD
    # ══════════════════════════════════════════
    result = st.session_state.get("current_result")

    if result is None:
        # Welcome state
        st.markdown("---")
        st.info(
            "👆 **Enter a clinical scenario above** or click a **Quick Demo Case** button to get started.\n\n"
            "This system provides WHO IMCI-grounded triage classification, evidence-based recommendations, "
            "and verified citations for pediatric clinical scenarios.",
            icon="🩺",
        )
        return

    # ── Layout: 3 columns ──
    col_left, col_mid, col_right = st.columns([1.2, 1.0, 1.0], gap="medium")

    # ═══════════════════════════════════════════
    # COLUMN A — Clinical Assessment & Output
    # ═══════════════════════════════════════════
    with col_left:
        st.markdown(
            '<div class="section-header">📋 Clinical Assessment</div>',
            unsafe_allow_html=True,
        )

        # ── Triage Card ──
        render_triage_card(result)

        # ── Confidence Gauge ──
        conf_html = get_confidence_html(result["confidence"], result["top_score"])
        st.markdown(f"**Confidence:** {conf_html}", unsafe_allow_html=True)

        # ── Search Query (if translated) ──
        current_query = st.session_state.get("current_query", "")
        if result.get("search_query") and result["search_query"] != current_query:
            st.caption(f"🔄 Search Query (EN): *{result['search_query']}*")

        st.markdown("---")

        # ── Recommendation & Evidence ──
        if result["status"] == "success":
            response_text = result["response_text"]

            # Split response into sections for cleaner display
            # Remove the differential questions section from the main display
            # (we show them separately in the expander)
            display_text = response_text
            dq_match = re.search(
                r"(?:🔎\s*)?(?:\*\*)?Differential Verification Questions(?:\*\*)?.*",
                display_text,
                re.IGNORECASE | re.DOTALL,
            )
            if dq_match:
                display_text = display_text[: dq_match.start()].rstrip()

            st.markdown(display_text)
        else:
            st.markdown(result["response_text"])

        st.markdown("---")

        # ── Differential Symptom Verification ──
        diff_questions = result.get("differential_questions", [])
        if diff_questions:
            with st.expander("🔎 Differential Verification Questions (IMCI Protocol)", expanded=True):
                for q in diff_questions:
                    st.markdown(f"• {q}")
        elif result["status"] == "success":
            with st.expander("🔎 Differential Verification Questions"):
                st.caption("No specific follow-up questions generated for this case.")

        # ── Citation Metadata Table ──
        st.markdown("---")
        st.markdown("**🏷️ Citation Sources**")
        render_citation_table(result)

    # ═══════════════════════════════════════════
    # COLUMN B — Evidence Explainability
    # ═══════════════════════════════════════════
    with col_mid:
        st.markdown(
            '<div class="section-header">📖 Retrieved Evidence</div>',
            unsafe_allow_html=True,
        )

        chunks = result.get("chunks", [])
        if not chunks:
            st.caption("No evidence chunks retrieved.")
        else:
            for i, chunk in enumerate(chunks, 1):
                score = chunk.get("score", 0)
                page = chunk.get("page", "N/A")
                section = chunk.get("section", "N/A")
                used = chunk.get("used", False)
                text = chunk.get("text", "")

                # Truncate section for display
                section_display = str(section)
                if len(section_display) > 50:
                    section_display = section_display[:47] + "..."

                # Score badge
                score_html = get_score_badge_html(score)

                # Used badge
                if used:
                    used_html = '<span class="used-badge used-yes">✅ Used in answer</span>'
                else:
                    used_html = '<span class="used-badge used-no">⬜ Not used</span>'

                # Card header
                st.markdown(
                    f"""
                    <div class="evidence-card">
                        <div style="margin-bottom:0.5rem;">
                            <strong style="color:#e2e8f0;">Chunk {i}</strong>
                            &nbsp;{score_html}&nbsp;{used_html}
                        </div>
                        <div style="color:#94a3b8; font-size:0.78rem; margin-bottom:0.6rem;">
                            📑 {section_display} &nbsp;|&nbsp; 📄 p. {page}
                        </div>
                    </div>
                    """,
                    unsafe_allow_html=True,
                )

                # Text content in an expandable area
                with st.expander(f"📄 View full text — Chunk {i}", expanded=(i <= 2)):
                    st.markdown(
                        f"<div style='font-size:0.82rem; line-height:1.5; color:#cbd5e1;'>{text[:1500]}</div>",
                        unsafe_allow_html=True,
                    )
                    if len(text) > 1500:
                        st.caption(f"... ({len(text)} total characters)")

    # ═══════════════════════════════════════════
    # COLUMN C — PDF Live Preview
    # ═══════════════════════════════════════════
    with col_right:
        st.markdown(
            '<div class="section-header">📄 Source Document Preview</div>',
            unsafe_allow_html=True,
        )

        if not pdf_path:
            st.warning(
                "⚠️ **WHO.pdf not found.**\n\n"
                "Searched in:\n"
                + "\n".join(f"- `{p}`" for p in PDF_SEARCH_PATHS[:3]),
                icon="📄",
            )
        elif not PYMUPDF_AVAILABLE:
            st.warning(
                "⚠️ **PyMuPDF not installed.**\n\n"
                "Run: `pip install PyMuPDF`",
                icon="📦",
            )
        else:
            total_pages = get_pdf_page_count(pdf_path)
            cited_pages = result.get("cited_pages", [])

            # Cited pages quick-jump buttons
            if cited_pages:
                st.markdown("**📌 Cited Pages:**")
                cite_cols = st.columns(min(len(cited_pages), 4))
                for idx, cp in enumerate(cited_pages[:4]):
                    with cite_cols[idx]:
                        if st.button(f"p. {cp}", key=f"cite_page_{cp}", use_container_width=True):
                            st.session_state["pdf_page"] = cp

            st.markdown("---")

            # Navigation row
            nav_col1, nav_col2, nav_col3 = st.columns([1, 2, 1])
            current_page = st.session_state.get("pdf_page", 1)

            with nav_col1:
                if st.button("◀ Prev", disabled=(current_page <= 1), use_container_width=True):
                    st.session_state["pdf_page"] = max(1, current_page - 1)
                    current_page = st.session_state["pdf_page"]

            with nav_col2:
                st.markdown(
                    f"<div style='text-align:center; padding:0.5rem; color:#93c5fd; font-weight:600;'>"
                    f"Page {current_page} of {total_pages}</div>",
                    unsafe_allow_html=True,
                )

            with nav_col3:
                if st.button("Next ▶", disabled=(current_page >= total_pages), use_container_width=True):
                    st.session_state["pdf_page"] = min(total_pages, current_page + 1)
                    current_page = st.session_state["pdf_page"]

            # Render page
            img_bytes = render_pdf_page(pdf_path, current_page)
            if img_bytes:
                st.image(img_bytes, use_container_width=True)
            else:
                st.error(f"Failed to render page {current_page}.")

            # Page number input for direct jump
            direct_page = st.number_input(
                "Go to page:",
                min_value=1,
                max_value=total_pages,
                value=current_page,
                step=1,
                key="direct_page_input",
            )
            if direct_page != current_page:
                st.session_state["pdf_page"] = direct_page
                st.rerun()


# ─────────────────────────────────────────────
# RUN
# ─────────────────────────────────────────────
if __name__ == "__main__":
    main()
