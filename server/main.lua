-- Khởi tạo ESX và biến toàn cục
ESX = exports['es_extended']:getSharedObject()
local totalPool = 0
local lastDrawTime = 0

-- Hàm kiểm tra quyền admin
local function isAdmin(source)
    local xPlayer = ESX.GetPlayerFromId(source)
    return xPlayer and xPlayer.getGroup() == "admin"
end

-- Gửi thông báo Discord cho kết quả xổ số
local function SendResultToDiscord(winningNumber, prizePool, winnerCount, drawTime, jackpot)
    if Config.ResultWebhookURL and Config.ResultWebhookURL ~= 'YOUR_DISCORD_WEBHOOK_URL_HERE' then
        local embed = {
            {
                color = 65280,
                title = "🎉 Kết Quả Xổ Số 🎉",
                description = "Kỳ xổ số vừa kết thúc!",
                thumbnail = {url = "https://media.discordapp.net/attachments/1259110783711842324/1344135691759779862/logo5.png?ex=67ed4b29&is=67ebf9a9&hm=18072fd5a833e4ca40990d73335cba51197fd26bb487845762f1a163f3d013b4&=&format=webp&quality=lossless&width=544&height=544"},
                fields = {
                    {name = "Số trúng thưởng", value = "**" .. winningNumber .. "**", inline = true},
                    {name = "Tổng giải thưởng", value = "**" .. prizePool .. "$**", inline = true},
                    {name = "Người trúng", value = "**" .. winnerCount .. "**", inline = true},
                    {name = "Jackpot hiện tại", value = "**" .. jackpot .. "$**", inline = true}
                },
                timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
                footer = {text = "Lottery Feinix City"}
            }
        }
        PerformHttpRequest(Config.ResultWebhookURL, function(err, text, headers) end, 'POST', json.encode({embeds = embed}), { ['Content-Type'] = 'application/json' })
    end
end

-- Gửi thông báo Discord cho hành động người chơi
local function SendPlayerActionToDiscord(playerName, playerId, action)
    if Config.PlayerActionWebhookURL and Config.PlayerActionWebhookURL ~= 'YOUR_DISCORD_WEBHOOK_URL_HERE' then
        local embed = {
            {
                color = 16776960,
                title = "📋 Hành Động Người Chơi",
                description = action,
                fields = {
                    {name = "Người chơi", value = "**" .. playerName .. "** (ID: " .. playerId .. ")", inline = true}
                },
                timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
                footer = {text = "Admin Log - Simple Lottery"}
            }
        }
        PerformHttpRequest(Config.PlayerActionWebhookURL, function(err, text, headers) end, 'POST', json.encode({embeds = embed}), { ['Content-Type'] = 'application/json' })
    end
end

-- Ghi log vào MySQL
local function LogActivity(message)
    MySQL.insert('INSERT INTO lottery_logs (message, date) VALUES (?, NOW())', {message})
    print("[Lottery Log] " .. message)
end

-- Lưu trạng thái vào MySQL
local function SaveState(drawTime)
    MySQL.query('INSERT INTO lottery_state (id, last_draw_time, total_pool) VALUES (1, FROM_UNIXTIME(?), ?) ON DUPLICATE KEY UPDATE last_draw_time = FROM_UNIXTIME(?), total_pool = ?', {
        drawTime, totalPool, drawTime, totalPool
    })
end

-- Tải trạng thái từ MySQL khi khởi động
AddEventHandler('onResourceStart', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end
    local currentTime = os.time() -- Lấy thời gian thực từ VPS
    local result = MySQL.single.await('SELECT last_draw_time, total_pool FROM lottery_state WHERE id = 1')
    lastDrawTime = result and result.last_draw_time or currentTime
    totalPool = result and result.total_pool or 0

    -- Kiểm tra nếu lastDrawTime không hợp lệ (trong tương lai xa), reset về currentTime
    if lastDrawTime > currentTime + 3600 then
        lastDrawTime = currentTime
        SaveState(lastDrawTime)
        print("[Lottery] Reset lastDrawTime do giá trị không hợp lệ: " .. os.date("%d/%m/%Y - %H:%M:%S", lastDrawTime))
    end

    print("[Lottery] Initialized lastDrawTime: " .. os.date("%d/%m/%Y - %H:%M:%S", lastDrawTime) .. ", totalPool: " .. totalPool)
end)

-- Gửi jackpot và thời gian quay số tiếp theo về client
RegisterNetEvent('lottery:getJackpot', function()
    local src = source
    local currentTime = os.time()
    local currentDate = os.date("*t", currentTime)
    local nextDrawHour = currentDate.hour + 1 -- Lấy giờ tiếp theo
    local nextDrawTime = string.format("%02d:%02d:%02d", nextDrawHour % 24, 0, 0) -- Đặt phút và giây về 00
    TriggerClientEvent('lottery:receiveJackpot', src, totalPool, nextDrawTime)
end)

-- Mua vé số
RegisterNetEvent('lottery:buyTicket', function()
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then return end

    local currentTime = os.time() -- Lấy thời gian thực từ VPS
    local currentMinute = tonumber(os.date("%M", currentTime))

    -- Khóa mua vé từ phút 50 trở đi
    if currentMinute >= 50 then
        TriggerClientEvent('lottery:buyLocked', src)
        return
    end

    local ticketCount = MySQL.scalar.await('SELECT COUNT(*) FROM lottery_tickets WHERE identifier = ?', {xPlayer.identifier})
    if ticketCount >= Config.MaxTicketsPerPlayer then
        lib.notify(src, {
            title = "Xổ số",
            description = "Bạn đã mua tối đa 2 vé cho kỳ này!",
            type = "error",
            position = "center-left",
            duration = Config.NotifyDuration
        })
        return
    end

    if xPlayer.getMoney() >= Config.TicketPrice then
        xPlayer.removeMoney(Config.TicketPrice)
        local ticketNumber = math.random(0, 99)
        local formattedNumber = string.format("%02d", ticketNumber)
        local purchaseTime = currentTime

        MySQL.insert('INSERT INTO lottery_tickets (identifier, number, date) VALUES (?, ?, FROM_UNIXTIME(?))', {
            xPlayer.identifier, formattedNumber, purchaseTime
        })

        totalPool = totalPool + Config.TicketPrice
        SaveState(lastDrawTime)
        lib.notify(src, {
            title = "Xổ số",
            description = "Bạn đã mua vé số: " .. formattedNumber,
            type = "success",
            position = "center-left",
            duration = Config.NotifyDuration
        })
        LogActivity("Người chơi " .. xPlayer.getName() .. " (ID: " .. src .. ") đã mua vé số: " .. formattedNumber)
        SendPlayerActionToDiscord(xPlayer.getName(), src, "Mua vé số: " .. formattedNumber)
        -- Thông báo cho tất cả người chơi khi Jackpot tăng
        TriggerClientEvent('lottery:jackpotUpdated', -1, totalPool)
    else
        lib.notify(src, {
            title = "Xổ số",
            description = "Bạn không đủ tiền mặt!",
            type = "error",
            position = "center-left",
            duration = Config.NotifyDuration
        })
    end
end)

-- Xem vé đã mua
RegisterNetEvent('lottery:checkTickets', function()
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then return end

    local tickets = MySQL.query.await('SELECT number, DATE_FORMAT(date, "%d/%m/%Y") as date FROM lottery_tickets WHERE identifier = ?', {xPlayer.identifier})
    TriggerClientEvent('lottery:showTickets', src, tickets)
end)

-- Kiểm tra thời gian thực và quay số khi phút = 00
Citizen.CreateThread(function()
    local lastDrawHour = -1
    local notifiedMinutes = {} -- Lưu trạng thái thông báo cho từng phút

    while true do
        Wait(100) -- Kiểm tra mỗi 100ms để chính xác hơn
        local currentTime = os.time() -- Lấy thời gian thực từ VPS
        local currentDate = os.date("*t", currentTime)
        local currentHour = currentDate.hour
        local currentMinute = currentDate.min
        local currentSecond = currentDate.sec

        -- Kiểm tra các mốc thông báo đếm ngược (50, 55, 57, 58, 59)
        local notifyMinute = nil
        local notifyMessage = nil
        if currentMinute == 50 then
            notifyMinute = 50
            notifyMessage = "Xổ số sẽ diễn ra sau 10 phút!"
        elseif currentMinute == 55 then
            notifyMinute = 55
            notifyMessage = "Còn 5 phút đến giờ quay số!"
        elseif currentMinute == 57 then
            notifyMinute = 57
            notifyMessage = "Còn 3 phút đến giờ quay số!"
        elseif currentMinute == 58 then
            notifyMinute = 58
            notifyMessage = "Còn 2 phút đến giờ quay số!"
        elseif currentMinute == 59 then
            notifyMinute = 59
            notifyMessage = "Còn 1 phút đến giờ quay số!"
        end

        if notifyMinute and currentSecond == 0 and not notifiedMinutes[currentHour .. ":" .. notifyMinute] then
            TriggerClientEvent('lottery:reminder', -1, notifyMessage)
            lib.notify(-1, {
                title = "Xổ số",
                description = notifyMessage,
                type = "info",
                position = "center-left",
                duration = Config.NotifyDuration
            })
            LogActivity("Thông báo: " .. notifyMessage .. " lúc " .. os.date("%H:%M:%S", currentTime))
            notifiedMinutes[currentHour .. ":" .. notifyMinute] = true
        end

        -- Kiểm tra quay số lúc phút = 00, giây = 00
        if currentMinute == 0 and currentSecond == 0 and currentHour ~= lastDrawHour then
            local winningNumber = math.random(0, 99)
            local formattedNumber = string.format("%02d", winningNumber)
            DrawLottery(formattedNumber, currentTime)
            lastDrawTime = currentTime
            lastDrawHour = currentHour
            SaveState(lastDrawTime)
            LogActivity("Quay số kết quả: " .. formattedNumber .. " - Tổng giải thưởng: " .. totalPool .. "$ lúc " .. os.date("%H:%M:%S", currentTime))
            -- Reset trạng thái thông báo cho giờ mới
            notifiedMinutes = {}
        end
    end
end)

-- Quay số và chia thưởng
function DrawLottery(winningNumber, drawTime)
    local tickets = MySQL.query.await('SELECT identifier, number FROM lottery_tickets')
    local winners = {}
    local ticketCount = 0
    for _, ticket in ipairs(tickets) do
        ticketCount = ticketCount + 1
        if ticket.number == winningNumber then
            local xPlayer = ESX.GetPlayerFromIdentifier(ticket.identifier)
            if xPlayer then
                winners[#winners + 1] = xPlayer.source
            end
        end
    end

    local prizePool = totalPool + (ticketCount * Config.BonusPerTicket)
    totalPool = 0
    MySQL.query('TRUNCATE TABLE lottery_tickets')

    if #winners > 0 then
        local prizePerWinner = math.floor(prizePool / #winners)
        local taxedPrize = math.floor(prizePerWinner * (1 - Config.TaxRate))

        for _, winnerSrc in ipairs(winners) do
            local xPlayer = ESX.GetPlayerFromId(winnerSrc)
            if xPlayer then
                xPlayer.addAccountMoney('bank', taxedPrize)
                TriggerClientEvent('lottery:winPrize', winnerSrc, taxedPrize)
                LogActivity("Người chơi " .. xPlayer.getName() .. " (ID: " .. winnerSrc .. ") trúng thưởng: " .. taxedPrize .. "$ (số: " .. winningNumber .. ")")
                SendPlayerActionToDiscord(xPlayer.getName(), winnerSrc, "Trúng thưởng " .. taxedPrize .. "$ (Số: " .. winningNumber .. ")")
            end
        end
    else
        totalPool = math.floor(prizePool * Config.JackpotCarryover)
    end

    TriggerClientEvent('lottery:drawResult', -1, winningNumber, prizePool)
    SendResultToDiscord(winningNumber, prizePool, #winners, drawTime, totalPool)
end

-- Lệnh admin để quay số thử nghiệm
RegisterCommand('lottery_draw_test', function(source, args)
    if source == 0 or isAdmin(source) then
        local currentTime = os.time()
        local currentDate = os.date("*t", currentTime)
        local currentHour = currentDate.hour
        local timeSinceLastDraw = lastDrawTime == 0 and math.huge or (currentTime - lastDrawTime)
        if timeSinceLastDraw >= 3600 then -- 1 giờ
            local winningNumber = math.random(0, 99)
            local formattedNumber = string.format("%02d", winningNumber)
            DrawLottery(formattedNumber, currentTime)
            lastDrawTime = currentTime
            SaveState(lastDrawTime)
            if source ~= 0 then
                lib.notify(source, {
                    title = "Xổ số",
                    description = "Đã quay số thử nghiệm: " .. formattedNumber,
                    type = "success",
                    position = "center-left",
                    duration = Config.NotifyDuration
                })
            else
                print("Đã quay số thử nghiệm từ console: " .. formattedNumber)
            end
        else
            local timeRemaining = 3600 - (timeSinceLastDraw % 3600)
            if source ~= 0 then
                lib.notify(source, {
                    title = "Xổ số",
                    description = "Chưa đủ 60 phút! Còn " .. math.floor(timeRemaining / 60) .. " phút.",
                    type = "error",
                    position = "center-left",
                    duration = Config.NotifyDuration
                })
            else
                print("Chưa đủ 60 phút! Còn " .. math.floor(timeRemaining / 60) .. " phút.")
            end
        end
    else
        lib.notify(source, {
            title = "Xổ số",
            description = "Bạn không có quyền dùng lệnh này!",
            type = "error",
            position = "center-left",
            duration = Config.NotifyDuration
        })
    end
end, false)

-- Lệnh admin quay số bất kỳ lúc nào
RegisterCommand('lottery_draw', function(source, args)
    if source == 0 or isAdmin(source) then
        local currentTime = os.time()
        local winningNumber = math.random(0, 99)
        local formattedNumber = string.format("%02d", winningNumber)
        DrawLottery(formattedNumber, currentTime)
        lastDrawTime = currentTime
        SaveState(lastDrawTime)
        if source ~= 0 then
            lib.notify(source, {
                title = "Xổ số",
                description = "Đã quay số thủ công: " .. formattedNumber,
                type = "success",
                position = "center-left",
                duration = Config.NotifyDuration
            })
        else
            print("Đã quay số thủ công từ console: " .. formattedNumber)
        end
    else
        lib.notify(source, {
            title = "Xổ số",
            description = "Bạn không có quyền dùng lệnh này!",
            type = "error",
            position = "center-left",
            duration = Config.NotifyDuration
        })
    end
end, false)