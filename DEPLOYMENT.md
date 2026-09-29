# Thông Tin Deploy — Checkpoint 5

> Điền file này sau khi deploy xong. `pytest tests/test_cp5.py` đọc file này
> để tìm địa chỉ service của bạn và gọi thử.
>
> **Chỉ ghi TÊN biến môi trường, tuyệt đối không dán giá trị API key vào đây.**
> Repo này công khai — dán khóa vào là mất khóa.

## Thông Tin Học Viên

| Mục | Nội dung |
|-----|----------|
| Họ và tên | Nguyễn Hải Nam |
| Mã học viên | 2A202602476 |
| Repo | https://github.com/namhaing/K4-L3B-DAY12-NguyenHaiNam-2A202602476-CloudServicesAndDeployment |

## Service

| Mục | Nội dung |
|-----|----------|
| Public URL | https://agent-production-96f4.up.railway.app |
| Platform | Railway (build từ `Dockerfile`, cấu hình `railway.toml`) |
| Ngày deploy | 2026-09-29 |

Project Railway `day12-agent` gồm 2 service:

| Service | Vai trò |
|---------|---------|
| `agent` | FastAPI app, build từ `Dockerfile`, health check `/health` |
| `Redis` | Redis add-on của Railway — lưu lịch sử hội thoại, rate limit, chi phí |

## Biến Môi Trường Đã Set Trên Cloud

Ghi tên biến và **nguồn giá trị**, không ghi giá trị:

| Biến | Đã set | Ghi chú |
|------|--------|---------|
| `PORT` | ✅ | platform tự gán, không set tay |
| `AGENT_API_KEY` | ✅ | đặt trong dashboard Railway (service `agent` → Variables), không nằm trong repo |
| `REDIS_URL` | ✅ | tham chiếu Redis add-on của Railway: `${{Redis.REDIS_URL}}` (mạng nội bộ) |
| `RATE_LIMIT_PER_MINUTE` | ✅ | 10 |
| `MONTHLY_BUDGET_USD` | ✅ | 10.0 |
| `LOG_LEVEL` | ✅ | INFO |

## Lệnh Kiểm Tra

Thay `<URL>` bằng Public URL ở trên:

```bash
# 1. Liveness — mong đợi 200 {"status":"ok"}
curl -i <URL>/health

# 2. Readiness — mong đợi 200 {"status":"ready"} (đã nối được Redis)
curl -i <URL>/ready

# 3. Không có API key — mong đợi 401
curl -i -X POST <URL>/ask \
  -H "Content-Type: application/json" \
  -d '{"question":"Hello"}'

# 4. Có API key — mong đợi 200 kèm câu trả lời
curl -i -X POST <URL>/ask \
  -H "Content-Type: application/json" \
  -H "X-API-Key: $AGENT_API_KEY" \
  -H "X-User-Id: sv-test" \
  -d '{"question":"Deploy là gì?"}'

# 5. Rate limit — gọi 15 lần, những lần cuối phải trả 429
for i in $(seq 1 15); do
  curl -s -o /dev/null -w "%{http_code} " -X POST <URL>/ask \
    -H "Content-Type: application/json" \
    -H "X-API-Key: $AGENT_API_KEY" \
    -H "X-User-Id: sv-test" \
    -d '{"question":"test"}'
done; echo
```

## Kết Quả Chạy Thật

Chạy ngày 2026-09-29 vào `https://agent-production-96f4.up.railway.app` (đã rút gọn header, giữ status line và body):

```
$ curl -i <URL>/health
HTTP/1.1 200 OK
{"status":"ok","service":"day12-agent","version":"1.0.0"}

$ curl -i <URL>/ready
HTTP/1.1 200 OK
{"status":"ready","redis":true}

$ curl -i -X POST <URL>/ask  (không có API key)
HTTP/1.1 401 Unauthorized
{"detail":"invalid or missing API key"}

$ curl -i -X POST <URL>/ask  (có API key, X-User-Id: sv-demo, question "Deploy là gì?")
HTTP/1.1 200 OK
{"answer":"Câu hỏi hay. Deploy là gì thường được giải quyết bằng cách chuẩn hóa môi trường chạy: cùng một image chạy giống nhau ở laptop và trên cloud.","user_id":"sv-demo","history_length":0,"cost_usd":2.145e-05,"tokens":{"in":3,"out":35}}

$ (gọi lần 2, cùng user sv-demo) → lịch sử được lưu trong Redis trên cloud
"history_length":2

$ for i in $(seq 1 15); do curl ... -H "X-User-Id: sv-demo" ...; done   # 2 suất đã dùng ở trên
200 200 200 200 200 200 200 200 429 429 429 429 429 429 429

$ for i in $(seq 1 15); do curl ... -H "X-User-Id: sv-test" ...; done   # user mới, đủ 10 suất
200 200 200 200 200 200 200 200 200 200 429 429 429 429 429
```

Ghi chú: lần đầu chạy lệnh 4 từ Git Bash trên Windows bị `400 {"detail":"There was an error parsing the body"}` — câu hỏi tiếng Việt truyền qua dòng lệnh bị sai bảng mã nên body không phải UTF-8 hợp lệ. Gửi body từ file UTF-8 (`--data-binary @q.json`) thì trả 200 như trên.

## Sự Cố Khi Deploy

| Triệu chứng | Nguyên nhân | Cách tìm | Cách sửa |
|---|---|---|---|
| `/health` 200 nhưng `/ready` và `/ask` trả **500** | Chạy `railway variables --set 'KEY=value'` trong **cmd.exe**: cmd không coi `'` là dấu nháy → tạo ra biến tên `'AGENT_API_KEY`, `'REDIS_URL`... → app không thấy `AGENT_API_KEY` → `Settings()` raise `ValidationError` ở request đầu tiên | Liệt kê **tên** biến của service `agent` (không in giá trị) → thấy tên có dấu `'` ở đầu | Xóa 5 biến sai (`railway variable delete "'AGENT_API_KEY" --service agent`...), đặt lại bằng nháy kép |
| `/ask` có key vẫn **401** | Dấu nháy kép đặt lệch → cả phần đuôi lệnh (`REDIS_URL=... --service agent`) bị gộp vào giá trị `AGENT_API_KEY` (dài 210 ký tự thay vì 43); `REDIS_URL` thì rỗng | So độ dài / ký tự lạ của giá trị trên Railway với khóa đang dùng (không in giá trị) | Sửa giá trị `AGENT_API_KEY` trên dashboard, đặt lại `REDIS_URL=${{Redis.REDIS_URL}}` |

Bài học: app vẫn khởi động và qua health check dù thiếu `AGENT_API_KEY`, vì `Settings` chỉ được đọc lần đầu khi có request cần nó — "fail fast" chưa thật sự fast. Đọc cấu hình ngay trong `lifespan` sẽ làm deploy thất bại tức thì với thông báo rõ ràng.

## Ảnh Chụp Màn Hình

Đặt ảnh trong thư mục `screenshots/`:

- `screenshots/dashboard.png` — trang quản lý service trên platform
- `screenshots/health.png` — kết quả gọi `/health` từ trình duyệt hoặc curl
