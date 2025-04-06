### Sổ Xố (lottery)
*Xổ Số Theo Thời Gian Thực 60 phút*

- Reset dữ liệu nếu cần: Nếu bạn cần reset dữ liệu (ví dụ: khi thử nghiệm hoặc triển khai lại), có thể chạy các lệnh sau:

```
TRUNCATE TABLE lottery_state;
INSERT INTO lottery_state (id, last_draw_time, total_pool) VALUES (1, UNIX_TIMESTAMP(), 0);
TRUNCATE TABLE lottery_tickets;
TRUNCATE TABLE lottery_logs;
```
