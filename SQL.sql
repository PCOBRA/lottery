-- Tạo bảng lottery_state
CREATE TABLE lottery_state (
    id INT PRIMARY KEY DEFAULT 1,
    last_draw_time INT NOT NULL DEFAULT 0,
    total_pool INT NOT NULL DEFAULT 0
);

-- Khởi tạo dữ liệu ban đầu cho lottery_state
INSERT INTO lottery_state (id, last_draw_time, total_pool) VALUES (1, UNIX_TIMESTAMP(), 0);

-- Tạo bảng lottery_tickets
CREATE TABLE lottery_tickets (
    id INT AUTO_INCREMENT PRIMARY KEY,
    identifier VARCHAR(50) NOT NULL,
    number VARCHAR(2) NOT NULL,
    date DATETIME NOT NULL
);

-- Tạo bảng lottery_logs
CREATE TABLE lottery_logs (
    id INT AUTO_INCREMENT PRIMARY KEY,
    message TEXT NOT NULL,
    date DATETIME NOT NULL
);