# ═══════════════════════════════════════════════════════════════════
# CP2 — Containerization (production-ready)
#
#   [x] Multi-stage: `builder` cài dependency vào venv, `runtime` chỉ copy venv sang
#   [x] Base image slim
#   [x] COPY requirements.txt + pip install TRƯỚC khi COPY source (tận dụng layer cache)
#   [x] Chạy bằng user thường `appuser` (uid 10001), không phải root
#   [x] HEALTHCHECK gọi /health
#   [x] Đọc cổng từ biến môi trường PORT (mặc định 8000)
#
# Kiểm tra:  pytest tests/test_cp2.py -v
# Build thử: docker build -t day12-agent:prod .
#            docker images day12-agent:prod     # xem dung lượng
# ═══════════════════════════════════════════════════════════════════

# ── Stage 1: builder — cài thư viện vào một virtualenv riêng ──────────
FROM python:3.11-slim AS builder

ENV PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1

WORKDIR /build

# Chỉ copy requirements.txt: sửa code không làm mất cache của layer pip install
COPY requirements.txt .
RUN python -m venv /opt/venv \
    && /opt/venv/bin/pip install -r requirements.txt


# ── Stage 2: runtime — chỉ mang theo venv đã cài và source code ─────
FROM python:3.11-slim AS runtime

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PATH="/opt/venv/bin:$PATH" \
    PORT=8000

RUN useradd --create-home --uid 10001 appuser

WORKDIR /app

COPY --from=builder /opt/venv /opt/venv
COPY --chown=appuser:appuser app/ ./app/
COPY --chown=appuser:appuser utils/ ./utils/

USER appuser

EXPOSE 8000

# Image slim không có curl → dùng Python gọi /health; ${PORT} được shell mở rộng lúc chạy
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD python -c "import sys, urllib.request; urllib.request.urlopen(sys.argv[1], timeout=3)" \
        "http://127.0.0.1:${PORT:-8000}/health" || exit 1

# `exec` để uvicorn thay thế sh làm PID 1 → nhận thẳng SIGTERM khi container dừng (CP4)
CMD ["sh", "-c", "exec uvicorn app.main:app --host 0.0.0.0 --port ${PORT:-8000}"]
