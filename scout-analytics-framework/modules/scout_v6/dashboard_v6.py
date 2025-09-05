import os
import io
import pandas as pd
import streamlit as st
from datetime import datetime, timedelta

st.set_page_config(page_title="Scout v6 • Deep Dive Analytics", layout="wide")

@st.cache_data(show_spinner=False)
def load_csv(source: str, is_url: bool):
    if is_url:
        return pd.read_csv(source)
    else:
        return pd.read_csv(source)

@st.cache_data(show_spinner=False)
def load_csv_bytes(bytes_data: bytes):
    return pd.read_csv(io.BytesIO(bytes_data))

def infer_date_col(df: pd.DataFrame):
    # Heuristic: prefer common date-like names
    candidates = [c for c in df.columns if c.lower() in ("date","tx_date","transaction_date","order_date","timestamp")]
    if candidates:
        col = candidates[0]
        try:
            df[col] = pd.to_datetime(df[col], errors="coerce")
            if df[col].notna().any():
                return col
        except Exception:
            pass
    # Fallback: try first datetime-castable column
    for c in df.columns:
        try:
            s = pd.to_datetime(df[c], errors="coerce")
            if s.notna().sum() > 0:
                df[c] = s
                return c
        except Exception:
            continue
    return None

def sidebar_filters(df: pd.DataFrame, date_col: str | None):
    st.sidebar.header("Scout v6 Filters")

    if date_col:
        with st.sidebar.expander("Time", True):
            quick = st.selectbox("Quick range", ["All","Last 7d","Last 30d","Last 90d"], index=2)
            if quick == "Last 7d":
                cutoff = pd.Timestamp.utcnow() - pd.Timedelta(days=7)
                df = df[df[date_col] >= cutoff]
            elif quick == "Last 30d":
                cutoff = pd.Timestamp.utcnow() - pd.Timedelta(days=30)
                df = df[df[date_col] >= cutoff]
            elif quick == "Last 90d":
                cutoff = pd.Timestamp.utcnow() - pd.Timedelta(days=90)
                df = df[df[date_col] >= cutoff]

    # Generic categorical filters commonly seen in Lesson 7 style datasets
    for label in ["region","city","barangay","category","brand"]:
        cols = [c for c in df.columns if c.lower() == label]
        if cols:
            col = cols[0]
            with st.sidebar.expander(label.capitalize(), True):
                options = sorted([x for x in df[col].dropna().astype(str).unique()][:500])
                sel = st.multiselect(f"Choose {label}(s)", options)
                if sel:
                    df = df[df[col].astype(str).isin(sel)]
    return df

def main():
    st.title("Deep Dive Analytics")
    st.caption("Scout v6 • Performance • Geo • Consumer • Agentic Analytics")

    # CSV Source Controls
    with st.container():
        st.subheader("Data Source")
        c1, c2, c3 = st.columns([2,2,1])
        csv_path = c1.text_input(
            "Local CSV path (repo-relative) or absolute",
            value="scout-analytics-framework/data/lesson7/sample_lesson7.csv"
        )
        csv_url  = c2.text_input("…or CSV URL (raw GitHub, GCS, etc.)", value="")
        uploaded = c3.file_uploader("Upload CSV", type=["csv"])

    df = None
    load_err = None
    try:
        if uploaded is not None:
            df = load_csv_bytes(uploaded.read())
        elif csv_url.strip():
            df = load_csv(csv_url.strip(), is_url=True)
        elif csv_path.strip():
            if os.path.exists(csv_path):
                df = load_csv(csv_path.strip(), is_url=False)
            else:
                # Try repo-relative
                repo_root = os.getcwd()
                candidate = os.path.join(repo_root, csv_path.strip())
                if os.path.exists(candidate):
                    df = load_csv(candidate, is_url=False)
                else:
                    load_err = f"CSV not found at '{csv_path}'."
        else:
            load_err = "Provide a local path, URL, or upload a CSV."
    except Exception as e:
        load_err = f"Failed to load CSV: {e}"

    if load_err:
        st.warning(load_err)
        st.stop()

    if df is None or df.empty:
        st.info("Loaded dataframe is empty.")
        st.stop()

    # Basic profile
    with st.expander("Profile", True):
        st.write(f"Rows: **{len(df):,}**, Columns: **{len(df.columns)}**")
        st.dataframe(df.head(50), use_container_width=True)

    # Filters
    date_col = infer_date_col(df)
    df_f = sidebar_filters(df.copy(), date_col)

    # Simple metrics section (Lesson-7 style)
    st.subheader("⚡ Performance Metrics")
    k1, k2, k3, k4 = st.columns(4)
    k1.metric("Rows (filtered)", f"{len(df_f):,}")
    k2.metric("Columns", f"{len(df_f.columns)}")
    if date_col:
        k3.metric("Date Min", str(pd.to_datetime(df_f[date_col]).min()))
        k4.metric("Date Max", str(pd.to_datetime(df_f[date_col]).max()))
    else:
        k3.metric("Date Min", "—")
        k4.metric("Date Max", "—")

    # Preview filtered data
    st.subheader("🔎 Preview (Filtered)")
    st.dataframe(df_f.head(200), use_container_width=True)

    # Download filtered slice
    st.download_button(
        "Download filtered CSV",
        data=df_f.to_csv(index=False).encode("utf-8"),
        file_name="scout_v6_filtered.csv",
        mime="text/csv"
    )

if __name__ == "__main__":
    main()
