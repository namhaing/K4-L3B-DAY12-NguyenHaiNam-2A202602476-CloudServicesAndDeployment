# Phiếu Phản Ánh — K4 Level 3B, Ngày 12

> **Bài làm cá nhân.** Trả lời bằng lời của chính bạn, dựa trên những gì bạn
> quan sát được khi chạy code — không sao chép đáp án của người khác.
>
> Cách trả lời: thay dòng placeholder (in nghiêng "Câu trả lời của bạn") bằng câu trả lời.
> `grade.py` đếm số câu đã trả lời (15 điểm cho 10 câu).
>
> Họ và tên: Nguyễn Hải Nam  Mã học viên: 2A202602476

---

### Câu 1 — Fail fast (CP1)

Trong `Settings`, `agent_api_key` không có giá trị mặc định nên app chết ngay
khi khởi động nếu thiếu biến môi trường. Hãy mô tả một tình huống cụ thể mà
việc "chết sớm" này cứu bạn, so với việc để mặc định `"changeme"`.

> Tình huống này xảy ra thật khi em deploy lên Railway: em set biến trong cmd
> bằng nháy đơn nên Railway tạo ra biến tên `'AGENT_API_KEY` (có dấu `'`), còn
> biến `AGENT_API_KEY` thật thì không có. Vì `agent_api_key` không có mặc định,
> `Settings()` raise `ValidationError` → `/ask` trả 500, không ai dùng được →
> em biết ngay là có vấn đề và đi tìm.
>
> Nếu để mặc định `"changeme"`: app vẫn chạy "bình thường" với khóa
> `changeme` — một giá trị ai đọc source trên GitHub (repo public) cũng biết.
> Mọi người trên Internet gọi được `/ask` bằng khóa đó, tiêu ngân sách LLM của
> em, trong khi health check vẫn xanh nên em không hề biết đã quên set secret.
>
> Em cũng rút ra: app của em vẫn **khởi động được** và qua `/health` dù thiếu
> khóa, vì `Settings` chỉ được đọc khi có request đầu tiên. Muốn fail fast thật
> thì nên gọi `get_settings()` ngay trong `lifespan` để deploy thất bại tại chỗ.

---

### Câu 2 — Log cho máy đọc (CP1)

Chạy service và gọi `/ask` vài lần. Dán một dòng log JSON bạn thu được, rồi
nêu **hai** việc bạn làm được với dòng log đó mà `print("đã trả lời xong")`
không làm được.

> Dòng log em thu được khi chạy `uvicorn` ở máy:
>
> ```
> {"event": "ask_completed", "level": "info", "timestamp": "2026-09-29T04:10:32.947479+00:00", "user_id": "sv-local", "tokens_in": 3, "tokens_out": 41, "cost_usd": 2.505e-05}
> ```
>
> Trên Railway, cùng dòng log đó được platform tự đọc thành log có cấu trúc:
> `[INFO] event="ask_completed" user_id="cp5-test" tokens_in=41 tokens_out=45 cost_usd=0.00003315`.
>
> 1. **Lọc và tổng hợp theo trường**: lọc mọi request của một `user_id`, cộng
>    `cost_usd` theo giờ/ngày để biết ai đang tiêu nhiều tiền, hoặc thấy
>    `tokens_in` tăng dần (3 → 48 ở lượt sau) vì lịch sử được gửi kèm prompt.
>    Với `print` thì chỉ có một câu chữ, không có con số nào để tính.
> 2. **Đặt cảnh báo tự động**: vd. số dòng `level = "error"` quá N lần/phút,
>    hoặc `cost_usd` của một user vượt ngưỡng → gửi alert. Máy đọc được
>    `level` nên Railway còn tự gắn nhãn `[INFO]` cho dòng log; `print` thì
>    platform không biết mức độ nghiêm trọng của nó.

---

### Câu 3 — Kích thước image (CP2)

Build cả hai phiên bản và ghi lại số đo thật:

```bash
docker build -f <Dockerfile-1-stage> -t agent:single .
docker build -t agent:multi .
docker images | grep agent
```

| Bản | Dung lượng |
|-----|-----------|
| 1 stage (bản đầu) | 1.73 GB (≈ 1770 MB) |
| Multi-stage | 310 MB |

Giải thích: phần dung lượng chênh lệch đó là những gì?

> Em build lại Dockerfile gốc (lấy từ git: `git show 493afed:Dockerfile`) thành
> `agent:single` và bản hiện tại thành `agent:multi`. `docker images`:
> `agent:single 1.73GB`, `agent:multi 310MB` — nhỏ hơn khoảng **5,6 lần**, chênh
> ~1.42 GB.
>
> Soi bằng `docker history`, phần chênh lệch gần như **toàn bộ nằm ở base image**:
> `python:3.11` bản đầy đủ nặng 1.6 GB, còn `python:3.11-slim` chỉ 187 MB. Bản
> đầy đủ mang theo cả bộ công cụ build và thư viện hệ thống mà lúc chạy app không
> cần: `gcc`/`make`, header `-dev` của hàng loạt thư viện C, git, curl, ImageMagick
> headers, tài liệu... Còn layer thư viện Python thì hai bản gần bằng nhau
> (`pip install` 95.1 MB ở bản single, `/opt/venv` 96 MB ở bản multi) và code
> của em chỉ ~120 KB.
>
> Multi-stage giúp giữ được image slim ở stage cuối: nếu có thư viện cần biên
> dịch, em cài compiler ở stage `builder` rồi chỉ copy `/opt/venv` đã cài sang
> stage `runtime` — compiler, cache pip và file tạm ở lại builder. Với
> requirements hiện tại mọi gói đều có wheel sẵn nên không cần compiler, vì vậy
> phần lợi rõ nhất đến từ việc đổi base image sang slim.
>
> Lưu ý: em build bản single với `.dockerignore` hiện tại. Với `.dockerignore`
> gốc (chỉ có `.git`), `COPY . .` còn chép cả `.venv`, `.env`, `tests/`... vào
> image, nên bản 1-stage thật sự của đề còn nặng hơn và còn lộ secret.

---

### Câu 4 — Thứ tự lệnh trong Dockerfile (CP2)

Sửa một ký tự trong `app/main.py` rồi build lại. Với Dockerfile của bạn, những
layer nào được dùng lại từ cache, layer nào phải chạy lại? Nếu bạn đặt
`COPY . .` lên trước `RUN pip install` thì kết quả khác thế nào?

> Em thêm một dòng comment vào `app/main.py` rồi build lại, output của
> `docker build --progress=plain`:
>
> ```
> [builder 3/4] COPY requirements.txt .                  CACHED
> [builder 4/4] RUN python -m venv ... pip install ...    CACHED
> [runtime 2/6] RUN useradd ...                           CACHED
> [runtime 4/6] COPY --from=builder /opt/venv /opt/venv   CACHED
> [runtime 5/6] COPY app/ ./app/                          chạy lại
> [runtime 6/6] COPY utils/ ./utils/                      chạy lại
> ```
>
> Chỉ 2 layer cuối chạy lại: `COPY app/` vì nội dung `app/` đổi, và
> `COPY utils/` vì nó đứng **sau** một layer vừa đổi (Docker vô hiệu cache của
> mọi layer phía sau). Layer nặng nhất là `pip install` (~96MB, lần đầu mất
> ~3 phút) được dùng lại, nên build lại chỉ vài giây.
>
> Nếu `COPY . .` đứng trước `RUN pip install` (như Dockerfile gốc): sửa bất kỳ
> file nào cũng làm layer `COPY . .` đổi → `pip install` phía sau mất cache →
> tải và cài lại toàn bộ thư viện mỗi lần sửa một ký tự code.

---

### Câu 5 — Vì sao không chạy bằng root (CP2)

Container mặc định chạy bằng root. Mô tả chuỗi sự kiện dẫn từ "một lỗ hổng
trong code Python của bạn" tới "kẻ tấn công có quyền cao trên máy host", và
lệnh `USER` cắt đứt chuỗi đó ở chỗ nào.

> Chuỗi sự kiện khi container chạy bằng root:
>
> 1. Code Python có lỗ hổng (vd. một thư viện bị lỗi deserialize, hoặc code
>    đưa input của user vào `eval`/shell) → kẻ tấn công chạy được lệnh tùy ý
>    (RCE) trong process của app.
> 2. Process đó là **root** (uid 0) → kẻ tấn công là root trong container: đọc
>    mọi file, cài công cụ, sửa code/thư viện của app để cài backdoor.
> 3. Root trong container cũng là uid 0 của kernel host (container dùng chung
>    kernel). Chỉ cần một điểm yếu — lỗ hổng kernel/runtime, volume mount thư
>    mục host, `docker.sock` bị mount, container `--privileged` — là thoát ra
>    host với quyền root.
>
> `USER appuser` cắt chuỗi ở **bước 2**: RCE chỉ có quyền của `appuser`
> (uid 10001). Em kiểm tra trong image: `whoami` → `appuser`,
> `id` → `uid=10001(appuser)`. Thư mục `/opt/venv` thuộc root nên kẻ tấn công
> không sửa được thư viện, không cài được gói; và nếu có thoát ra host thì cũng
> chỉ là một user thường, không phải root.

---

### Câu 6 — Cửa sổ trượt (CP3)

Rate limit của bạn dùng sliding window 60 giây. Nếu thay bằng cách đếm theo
phút đồng hồ (reset lúc giây 00), một người dùng có thể gửi tối đa bao nhiêu
request trong 2 giây liên tiếp khi hạn mức là 10/phút? Giải thích cách đạt được
con số đó.

> Tối đa **20 request** trong 2 giây.
>
> Cách đạt được: gửi 10 request lúc 10:00:59 — đều hợp lệ vì phút 10:00 mới
> dùng 0/10. Đến 10:01:00 bộ đếm reset về 0, gửi tiếp 10 request — lại hợp lệ
> vì phút 10:01 mới dùng 0/10. Tổng cộng 20 request trong khoảng 1–2 giây, gấp
> đôi hạn mức mà vẫn "đúng luật".
>
> Sliding window của em đếm số request trong 60 giây **lùi lại từ thời điểm
> hiện tại** (xóa entry có score ≤ `now - 60` trong ZSET rồi `ZCARD`), nên bất
> kỳ khoảng 60 giây nào cũng tối đa 10. Em chạy thật 15 request liên tiếp vào
> bản deploy: `200 ×10` rồi `429 ×5`, response 429 có header `Retry-After: 60`.

---

### Câu 7 — Rate limit và cost guard (CP3)

Hai cơ chế này khác nhau ở điểm nào? Cho một tình huống mà rate limit cho qua
nhưng cost guard phải chặn, và một tình huống ngược lại.

> Rate limit giới hạn **số lượng request** trong 60 giây (trả 429); cost guard
> giới hạn **số tiền** mỗi user mỗi tháng (key `cost:{user}:{YYYY-MM}`, trả
> 402). Rate limit bảo vệ khỏi gọi dồn dập; cost guard bảo vệ hóa đơn.
>
> - **Rate limit cho qua, cost guard chặn**: một user gửi đều 5 request/phút,
>   mỗi request là một câu hỏi rất dài kèm lịch sử hội thoại dài → mỗi request
>   tốn nhiều token. Không bao giờ vượt 10/phút, nhưng sau vài ngày tổng
>   `cost_usd` vượt 10 USD → cost guard trả 402. Em test bằng cách set sẵn chi
>   phí 10.5 USD cho một user → `/ask` trả `402 monthly budget exceeded` dù user
>   đó chưa gửi request nào trong phút đó.
> - **Rate limit chặn, cost guard cho qua**: một script gửi 15 câu "test" ngắn
>   trong vài giây. Mỗi câu chỉ tốn ~0.00002 USD, tổng còn chưa tới 0.001 USD —
>   ngân sách còn gần đủ 10 USD — nhưng từ request thứ 11 bị 429.

---

### Câu 8 — /health khác /ready (CP4)

Nếu gộp hai endpoint làm một và cho nó kiểm tra Redis, chuyện gì xảy ra với cụm
3 container khi Redis mất kết nối 30 giây? Trả lời theo đúng thứ tự sự kiện.

> 1. Redis mất kết nối → endpoint gộp của **cả 3** container cùng trả 503.
> 2. Orchestrator dùng endpoint đó làm liveness probe → sau vài lần fail liên
>    tiếp nó kết luận cả 3 container "chết".
> 3. Orchestrator **restart cả 3 container** cùng lúc → request đang xử lý bị
>    cắt, không còn instance nào phục vụ.
> 4. Container khởi động lại trong khi Redis vẫn chưa về → probe lại fail → lại
>    bị restart → vòng lặp restart (crash loop), có thể kéo dài hơn cả 30 giây
>    Redis mất.
> 5. Redis về, nhưng các container phải chờ hết thời gian khởi động và vượt
>    probe lại mới nhận traffic → downtime dài hơn sự cố gốc.
>
> Khi tách ra (như code của em): Redis mất → `/ready` trả 503 nên load balancer
> tạm ngừng gửi request, còn `/health` vẫn 200 nên **không container nào bị
> restart**; Redis về là `/ready` 200 lại ngay. Em đã thử thật:
> `docker compose stop redis` → `/ready` = `503 {"status":"not ready","redis":false}`,
> `/health` = `200`; `docker compose start redis` → `/ready` = `200` mà không
> cần restart agent.

---

### Câu 9 — Stateless (CP4)

Chạy `docker compose up --scale agent=3` rồi gọi `/ask` nhiều lần với cùng một
`X-User-Id`. Quan sát `history_length` trong response. Nếu lịch sử được lưu
trong một dict Python thay vì Redis, bạn sẽ thấy con số đó thay đổi thế nào?

> Lưu ý thực tế: với `ports: "8000:8000"`, lệnh scale báo lỗi
> `Bind for 0.0.0.0:8000 failed: port is already allocated`, nên em đổi sang
> dải cổng `8000-8002:8000` và thêm nginx (`--profile lb`, cổng 8080) làm cửa
> vào chung. Gửi 6 request qua nginx, cùng `X-User-Id: sv-scale`:
>
> | Lượt | Container xử lý | `history_length` (Redis) | Nếu dùng dict |
> |---|---|---|---|
> | 1 | agent-3 | 0 | 0 |
> | 2 | agent-3 | 2 | 2 |
> | 3 | agent-1 | 4 | **0** |
> | 4 | agent-1 | 6 | 2 |
> | 5 | agent-2 | 8 | **0** |
> | 6 | agent-2 | 10 | 2 |
>
> Với Redis, con số tăng đều 2 mỗi lượt dù request rơi vào 3 container khác
> nhau. Với dict, mỗi container có RAM riêng nên con số nhảy theo container:
> lần đầu gặp container mới là về 0 — agent "mất trí nhớ", và câu trả lời phụ
> thuộc vào việc load balancer gửi request đi đâu. Ngoài ra restart container
> là mất sạch; em đã thử `docker compose restart agent` và `history_length` vẫn
> tiếp tục từ 4 vì lịch sử nằm ở Redis.

---

### Câu 10 — Deploy thật (CP5)

Ghi lại **một** lỗi bạn gặp khi deploy lên cloud (build fail, health check
timeout, sai REDIS_URL, app không đọc `$PORT`...): thông báo lỗi là gì, bạn
tìm ra nguyên nhân bằng cách nào, và sửa ra sao?

> **Lỗi**: sau khi `railway up` thành công, `/health` trả 200 nhưng `/ready`
> và `/ask` (kể cả khi không gửi key) đều trả `500 Internal Server Error`.
>
> **Tìm nguyên nhân**: `/health` 200 nghĩa là container và `$PORT` đều ổn;
> `/ask` không key mà 500 thay vì 401 nghĩa là lỗi xảy ra trước cả bước so khóa
> — ở `get_settings()`. Em liệt kê **tên** các biến của service `agent` (chỉ in
> tên, không in giá trị) và thấy `'AGENT_API_KEY`, `'REDIS_URL`,
> `'LOG_LEVEL`... — tên có dấu `'` ở đầu. Nguyên nhân: em chạy
> `railway variables --set 'AGENT_API_KEY=...'` trong **cmd.exe**, mà cmd không
> coi `'` là dấu nháy nên nó thành một phần của tên và giá trị. App không thấy
> biến `AGENT_API_KEY` → `Settings()` raise `ValidationError` → 500.
>
> **Sửa**: xóa 5 biến sai bằng `railway variable delete "'AGENT_API_KEY" --service agent`,
> đặt lại bằng nháy kép (cú pháp của cmd). Lần đặt lại đầu tiên em còn để lệch
> dấu nháy nên cả đuôi lệnh bị dính vào giá trị khóa (dài 210 ký tự thay vì 43)
> → `/ask` có key vẫn 401; em sửa lại giá trị trên dashboard và set
> `REDIS_URL=${{Redis.REDIS_URL}}`. Sau đó `/ready` = 200, `/ask` có key = 200
> và `pytest tests/test_cp5.py` pass 9/9.
>
> Bài học: luôn kiểm tra lại tên biến sau khi set, và nên đọc `Settings` ngay lúc
> khởi động để thiếu secret là deploy fail ngay, không chờ tới request đầu tiên.
