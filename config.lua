Config = {}

-- Giá vé số
Config.TicketPrice = 20000 -- 20,000$ mỗi vé

-- Giới hạn số vé mỗi người
Config.MaxTicketsPerPlayer = 2

-- Vị trí NPC bán vé
Config.TicketSeller = {
    {coords = vector3(229.72, -891.76, 30.68), heading = 161.48}
}

-- Thuế trúng thưởng
Config.TaxRate = 0.1 -- 10%
Config.JackpotCarryover = 2/3 -- 2/3 số tiền cộng dồn nếu không có người trúng
Config.BonusPerTicket = 20000 -- 20,000$ cộng thêm cho mỗi vé bán ra

-- Thời gian hiển thị thông báo (ms)
Config.NotifyDuration = 10000 -- 10 giây

-- Webhook Discord để thông báo kết quả
Config.ResultWebhookURL = 'https://discord.com/api/webhooks/1356784846415986798/rHWgdLm5LrhTQv_d54mkto57w6SJXP8-NC3P60awNtP5GdeLyn1t_Rv9fwvc3h0z9j27'

-- Webhook Discord để thông báo hành động người chơi
Config.PlayerActionWebhookURL = 'https://discord.com/api/webhooks/1356781692219818196/EO4uL8citceL8ORuR58co8Bne5fM_ZitipldccP7ZHoK7jeq1hTMHCM3x29sRZga4K_D'