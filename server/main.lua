-- Khởi tạo ESX và biến toàn cục
ESX = exports['es_extended']:getSharedObject()
local totalPool = 0
local lastDrawTime = 0

-- Hàm kiểm tra quyền admin
local function isAdmin(source)
    local xPlayer = ESX.GetPlayerFromId(source)
    return xPlayer and xPlayer.getGroup() == "admin"
end

-- Gửi thông báo Discord cho kết quả xổ số (bỏ timestamp)
local function SendResultToDiscord(winningNumber, prizePool, winnerCount, drawTime, jackpot, secondWinners, thirdWinners, consolationWinners)
    if Config.ResultWebhookURL and Config.ResultWebhookURL ~= 'YOUR_DISCORD_WEBHOOK_URL_HERE' then
        local embed = {
            {
                color = 65280,
                title = "🎉 Kết Quả Xổ Số 🎉",
                description = "Kỳ xổ số vừa kết thúc!",
                thumbnail = {url = "...."},
                fields = {
                    {name = "Số trúng thưởng", value = "**" .. winningNumber .. "**", inline = true},
                    {name = "Tổng giải thưởng", value = "**" .. prizePool .. "$**", inline = true},
                    {name = "Người trúng Jackpot", value = "**" .. winnerCount .. "**", inline = true},
                    {name = "Giải nhì (30,000$/vé)", value = "**" .. secondWinners .. "**", inline = true},
                    {name = "Giải ba (20,000$/vé)", value = "**" .. thirdWinners .. "**", inline = true},
                    {name = "Giải khuyến khích (5,000$/vé)", value = "**" .. consolationWinners .. "**", inline = true},
                    {name = "Jackpot hiện tại", value = "**" .. jackpot .. "$**", inline = true}
                },
                footer = {text = "Lottery Feinix City"}
            }
        }
        PerformHttpRequest(Config.ResultWebhookURL, function(err, text, headers) end, 'POST', json.encode({embeds = embed}), { ['Content-Type'] = 'application/json' })
    end
end

-- Gửi thông báo Discord cho hành động người chơi (bỏ timestamp)
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
                footer = {text = "Admin Log - Simple Lottery"}
            }
        }
        PerformHttpRequest(Config.PlayerActionWebhookURL, function(err, text, headers) end, 'POST', json.encode({embeds = embed}), { ['Content-Type'] = 'application/json' })
    end
end

-- Ghi log vào MySQL
local function LogActivity(message)
    MySQL.insert('INSERT INTO lottery_logs (message, date) VALUES (?, NOW())', {message})
end

-- Lưu trạng thái vào MySQL
local function SaveState(drawTime)
    MySQL.query('INSERT INTO lottery_state (id, last_draw_time, total_pool) VALUES (1, FROM_UNIXTIME(?), ?) ON DUPLICATE KEY UPDATE last_draw_time = FROM_UNIXTIME(?), total_pool = ?', {
        drawTime, totalPool, drawTime, totalPool
    })
end

-- Lưu lịch sử jackpot
local function SaveJackpotHistory(winningNumber, drawTime, prizePool)
    MySQL.insert('INSERT INTO lottery_jackpot_history (winning_number, draw_time, prize_pool) VALUES (?, FROM_UNIXTIME(?), ?)', {
        winningNumber, drawTime, prizePool
    })
    -- Xóa các bản ghi cũ nếu vượt quá 5
    MySQL.query('DELETE FROM lottery_jackpot_history WHERE id NOT IN (SELECT id FROM (SELECT id FROM lottery_jackpot_history ORDER BY draw_time DESC LIMIT 5) AS temp)')
end

-- Tải trạng thái từ MySQL khi khởi động
AddEventHandler('onResourceStart', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end
    local currentTime = os.time()
    local result = MySQL.single.await('SELECT UNIX_TIMESTAMP(last_draw_time) as last_draw_time, total_pool FROM lottery_state WHERE id = 1')
    if result then
        lastDrawTime = result.last_draw_time and tonumber(result.last_draw_time) or currentTime
        totalPool = result.total_pool and tonumber(result.total_pool) or 501320 -- Gán giá trị mặc định từ SQL
        if not result.total_pool or result.total_pool == 0 then
            totalPool = 501320
            MySQL.query('UPDATE lottery_state SET total_pool = ? WHERE id = 1', {totalPool})
        end
    else
        lastDrawTime = currentTime
        totalPool = 501320
        MySQL.query('INSERT INTO lottery_state (id, last_draw_time, total_pool) VALUES (1, FROM_UNIXTIME(?), ?) ON DUPLICATE KEY UPDATE last_draw_time = FROM_UNIXTIME(?), total_pool = ?', {
            currentTime, totalPool, currentTime, totalPool
        })
    end
end)

-- Gửi jackpot về client (bỏ thời gian quay số)
RegisterNetEvent('lottery:getJackpot', function()
    local src = source
    TriggerClientEvent('lottery:receiveJackpot', src, totalPool)
end)

-- Mua vé số
RegisterNetEvent('lottery:buyTicket', function()
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then return end

    local currentTime = os.time()
    local currentMinute = tonumber(os.date("%M", currentTime))

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

-- Lấy lịch sử jackpot (chỉ lấy winning_number và prize_pool)
RegisterNetEvent('lottery:getJackpotHistory', function()
    local src = source
    local history = MySQL.query.await('SELECT winning_number, prize_pool FROM lottery_jackpot_history ORDER BY draw_time DESC LIMIT 5')
    TriggerClientEvent('lottery:receiveJackpotHistory', src, history)
end)

-- Kiểm tra thời gian thực và quay số (giữ logic quay số nhưng không hiển thị thời gian)
Citizen.CreateThread(function()
    local lastDrawHour = -1
    local notifiedMinutes = {}

    while true do
        Wait(100)
        local currentTime = os.time()
        local currentDate = os.date("*t", currentTime)
        local currentHour = currentDate.hour
        local currentMinute = currentDate.min
        local currentSecond = currentDate.sec

        local notifyMinute = nil
        local notifyMessage = nil
        if currentMinute == 50 then
            notifyMinute = 50
            notifyMessage = "Xổ số sắp diễn ra!"
        elseif currentMinute == 55 then
            notifyMinute = 55
            notifyMessage = "Xổ số sắp diễn ra!"
        elseif currentMinute == 57 then
            notifyMinute = 57
            notifyMessage = "Xổ số sắp diễn ra!"
        elseif currentMinute == 58 then
            notifyMinute = 58
            notifyMessage = "Xổ số sắp diễn ra!"
        elseif currentMinute == 59 then
            notifyMinute = 59
            notifyMessage = "Xổ số sắp diễn ra!"
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
            LogActivity("Thông báo: " .. notifyMessage)
            notifiedMinutes[currentHour .. ":" .. notifyMinute] = true
        end

        if currentMinute == 0 and currentSecond == 0 and currentHour ~= lastDrawHour then
            local winningNumber = math.random(0, 99)
            local formattedNumber = string.format("%02d", winningNumber)
            DrawLottery(formattedNumber, currentTime)
            lastDrawTime = currentTime
            lastDrawHour = currentHour
            SaveState(lastDrawTime)
            LogActivity("Quay số kết quả: " .. formattedNumber .. " - Tổng giải thưởng: " .. totalPool .. "$")
            notifiedMinutes = {}
        end
    end
end)

-- Quay số và chia thưởng
function DrawLottery(winningNumber, drawTime)
    local tickets = MySQL.query.await('SELECT identifier, number FROM lottery_tickets')
    local winners = {} -- Giải jackpot
    local secondPrizeWinners = {} -- Giải nhì
    local thirdPrizeWinners = {} -- Giải ba
    local consolationWinners = {} -- Giải khuyến khích
    local ticketCount = 0

    local winningNumInt = tonumber(winningNumber)
    local unitDigit = winningNumInt % 10
    local tensDigit = math.floor(winningNumInt / 10)
    local prevNum = string.format("%02d", (winningNumInt - 1) % 100)
    local nextNum = string.format("%02d", (winningNumInt + 1) % 100)

    for _, ticket in ipairs(tickets) do
        ticketCount = ticketCount + 1
        local ticketNumInt = tonumber(ticket.number)
        local ticketUnitDigit = ticketNumInt % 10
        local ticketTensDigit = math.floor(ticketNumInt / 10)

        if ticket.number == winningNumber then
            local xPlayer = ESX.GetPlayerFromIdentifier(ticket.identifier)
            if xPlayer then winners[#winners + 1] = xPlayer.source end
        elseif ticketUnitDigit == unitDigit then
            local xPlayer = ESX.GetPlayerFromIdentifier(ticket.identifier)
            if xPlayer then secondPrizeWinners[#secondPrizeWinners + 1] = xPlayer.source end
        elseif ticketTensDigit == tensDigit then
            local xPlayer = ESX.GetPlayerFromIdentifier(ticket.identifier)
            if xPlayer then thirdPrizeWinners[#thirdPrizeWinners + 1] = xPlayer.source end
        elseif ticket.number == prevNum or ticket.number == nextNum then
            local xPlayer = ESX.GetPlayerFromIdentifier(ticket.identifier)
            if xPlayer then consolationWinners[#consolationWinners + 1] = xPlayer.source end
        end
    end

    local prizePool = totalPool + (ticketCount * Config.BonusPerTicket)
    totalPool = 0
    MySQL.query('TRUNCATE TABLE lottery_tickets')

    -- Giải jackpot
    if #winners > 0 then
        local prizePerWinner = math.floor(prizePool / #winners)
        local taxedPrize = math.floor(prizePerWinner * (1 - Config.TaxRate))
        for _, winnerSrc in ipairs(winners) do
            local xPlayer = ESX.GetPlayerFromId(winnerSrc)
            if xPlayer then
                xPlayer.addAccountMoney('bank', taxedPrize)
                TriggerClientEvent('lottery:winPrize', winnerSrc, taxedPrize, "Jackpot")
                LogActivity("Người chơi " .. xPlayer.getName() .. " (ID: " .. winnerSrc .. ") trúng Jackpot: " .. taxedPrize .. "$ (số: " .. winningNumber .. ")")
                SendPlayerActionToDiscord(xPlayer.getName(), winnerSrc, "Trúng Jackpot " .. taxedPrize .. "$ (Số: " .. winningNumber .. ")")
            end
        end
    else
        totalPool = math.floor(prizePool * Config.JackpotCarryover)
    end

    -- Giải nhì (30,000$/vé)
    local secondPrize = 30000
    for _, winnerSrc in ipairs(secondPrizeWinners) do
        local xPlayer = ESX.GetPlayerFromId(winnerSrc)
        if xPlayer then
            xPlayer.addAccountMoney('bank', secondPrize)
            TriggerClientEvent('lottery:winPrize', winnerSrc, secondPrize, "Giải nhì")
            LogActivity("Người chơi " .. xPlayer.getName() .. " (ID: " .. winnerSrc .. ") trúng Giải nhì: " .. secondPrize .. "$ (số: " .. winningNumber .. ")")
            SendPlayerActionToDiscord(xPlayer.getName(), winnerSrc, "Trúng Giải nhì " .. secondPrize .. "$ (Số: " .. winningNumber .. ")")
        end
    end

    -- Giải ba (20,000$/vé)
    local thirdPrize = 20000
    for _, winnerSrc in ipairs(thirdPrizeWinners) do
        local xPlayer = ESX.GetPlayerFromId(winnerSrc)
        if xPlayer then
            xPlayer.addAccountMoney('bank', thirdPrize)
            TriggerClientEvent('lottery:winPrize', winnerSrc, thirdPrize, "Giải ba")
            LogActivity("Người chơi " .. xPlayer.getName() .. " (ID: " .. winnerSrc .. ") trúng Giải ba: " .. thirdPrize .. "$ (số: " .. winningNumber .. ")")
            SendPlayerActionToDiscord(xPlayer.getName(), winnerSrc, "Trúng Giải ba " .. thirdPrize .. "$ (Số: " .. winningNumber .. ")")
        end
    end

    -- Giải khuyến khích (5,000$/vé)
    local consolationPrize = 5000
    for _, winnerSrc in ipairs(consolationWinners) do
        local xPlayer = ESX.GetPlayerFromId(winnerSrc)
        if xPlayer then
            xPlayer.addAccountMoney('bank', consolationPrize)
            TriggerClientEvent('lottery:winPrize', winnerSrc, consolationPrize, "Giải khuyến khích")
            LogActivity("Người chơi " .. xPlayer.getName() .. " (ID: " .. winnerSrc .. ") trúng Giải khuyến khích: " .. consolationPrize .. "$ (số: " .. winningNumber .. ")")
            SendPlayerActionToDiscord(xPlayer.getName(), winnerSrc, "Trúng Giải khuyến khích " .. consolationPrize .. "$ (Số: " .. winningNumber .. ")")
        end
    end

    -- Lưu lịch sử jackpot
    SaveJackpotHistory(winningNumber, drawTime, prizePool)

    -- Gửi kết quả quay số
    TriggerClientEvent('lottery:drawResult', -1, winningNumber, prizePool, #winners, #secondPrizeWinners, #thirdPrizeWinners, #consolationWinners)
    SendResultToDiscord(winningNumber, prizePool, #winners, drawTime, totalPool, #secondPrizeWinners, #thirdPrizeWinners, #consolationWinners)
end

-- Lệnh admin quay số thử nghiệm
RegisterCommand('lottery_draw_test', function(source, args)
    if source == 0 or isAdmin(source) then
        local currentTime = os.time()
        local timeSinceLastDraw = lastDrawTime == 0 and math.huge or (currentTime - lastDrawTime)
        if timeSinceLastDraw >= 3600 then
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
