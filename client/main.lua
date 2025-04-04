-- Khởi tạo ESX
ESX = exports['es_extended']:getSharedObject()

-- Tạo NPC bán vé số
Citizen.CreateThread(function()
    for _, seller in pairs(Config.TicketSeller) do
        local pedModel = GetHashKey("s_m_y_shop_mask")
        RequestModel(pedModel)
        while not HasModelLoaded(pedModel) do Wait(10) end
        local ped = CreatePed(4, pedModel, seller.coords.x, seller.coords.y, seller.coords.z - 1, seller.heading, false, true)
        FreezeEntityPosition(ped, true)
        SetEntityInvincible(ped, true)
        SetBlockingOfNonTemporaryEvents(ped, true)
        SetModelAsNoLongerNeeded(pedModel)

        exports.ox_target:addLocalEntity(ped, {
            {
                name = "buy_ticket",
                label = "Mua Vé Số",
                icon = "fas fa-ticket-alt",
                onSelect = function()
                    TriggerServerEvent('lottery:getJackpot')
                end
            },
            {
                name = "check_tickets",
                label = "Xem Vé Đã Mua",
                icon = "fas fa-list",
                onSelect = function()
                    TriggerServerEvent('lottery:checkTickets')
                end
            }
        })
    end
end)

-- Hiển thị menu mua vé số (bỏ thời gian quay số)
function ShowLotteryMenu(jackpot)
    local options = {
        {
            title = "💰 Jackpot: " .. tostring(jackpot or 0) .. "$",
            icon = "fas fa-coins",
            disabled = true
        },
        {
            title = "🎟️ Mua Vé Số",
            description = "Giá vé: 20000$ (Tối đa 2 vé) - Cơ hội trúng lớn đang chờ bạn!",
            icon = "fas fa-ticket-alt",
            iconColor = "#FFD700",
            onSelect = function()
                TriggerServerEvent('lottery:buyTicket')
            end
        },
        {
            title = "📜 Xem Lịch Sử Jackpot",
            icon = "fas fa-history",
            onSelect = function()
                TriggerServerEvent('lottery:getJackpotHistory')
            end
        }
    }
    lib.registerContext({
        id = 'lottery_menu',
        title = '🎰 XỔ SỐ - CƠ HỘI TRÚNG LỚN 🎰',
        options = options
    })
    lib.showContext('lottery_menu')
end

-- Hiển thị menu lịch sử jackpot (riêng biệt)
RegisterNetEvent('lottery:receiveJackpotHistory', function(history)
    local options = {
        {
            title = "📜 Lịch Sử Jackpot Gần Nhất",
            description = "5 kỳ quay số trước",
            icon = "fas fa-history",
            disabled = true
        }
    }

    if #history > 0 then
        for i, entry in ipairs(history) do
            table.insert(options, {
                title = "Kỳ " .. i .. ": " .. entry.winning_number,
                description = "Giải: " .. entry.prize_pool .. "$",
                icon = "fas fa-history"
            })
        end
    else
        table.insert(options, {
            title = "Không có dữ liệu lịch sử",
            description = "Chưa có kỳ quay số nào.",
            icon = "fas fa-info-circle",
            disabled = true
        })
    end

    lib.registerContext({
        id = 'lottery_history_menu',
        title = '📋 LỊCH SỬ JACKPOT',
        options = options
    })
    lib.showContext('lottery_history_menu')
end)

-- Hiển thị danh sách vé đã mua
RegisterNetEvent('lottery:showTickets', function(tickets)
    local options = {}
    for _, ticket in ipairs(tickets) do
        options[#options + 1] = {
            title = "Vé số: " .. ticket.number,
            description = "Mua ngày: " .. ticket.date
        }
    end

    lib.registerContext({
        id = 'lottery_tickets_menu',
        title = 'Vé Số Của Bạn',
        options = options
    })
    lib.showContext('lottery_tickets_menu')
end)

-- Thông báo kết quả quay số
RegisterNetEvent('lottery:drawResult', function(winningNumber, prize, jackpotWinners, secondWinners, thirdWinners, consolationWinners)
    lib.notify({
        title = "Kết quả xổ số",
        description = "Số trúng thưởng: " .. winningNumber .. ". Giải thưởng: " .. prize .. "$\n" ..
                      "Jackpot: " .. jackpotWinners .. " người - Giải nhì: " .. secondWinners .. " người\n" ..
                      "Giải ba: " .. thirdWinners .. " người - Khuyến khích: " .. consolationWinners .. " người",
        type = "inform",
        position = "center-left",
        duration = Config.NotifyDuration
    })
end)

-- Thông báo trúng thưởng
RegisterNetEvent('lottery:winPrize', function(amount, prizeType)
    lib.notify({
        title = "Chúc mừng!",
        description = "Bạn đã trúng " .. prizeType .. ": " .. amount .. "$ (đã vào ngân hàng)!",
        type = "success",
        position = "center-left",
        duration = Config.NotifyDuration
    })
end)

-- Thông báo nhắc nhở (bỏ thời gian)
RegisterNetEvent('lottery:reminder', function(message)
    lib.notify({
        title = "Xổ số",
        description = message or "Xổ số sắp diễn ra!",
        type = "info",
        position = "center-left",
        duration = Config.NotifyDuration
    })
end)

-- Thông báo khóa mua vé (bỏ thời gian)
RegisterNetEvent('lottery:buyLocked', function()
    lib.notify({
        title = "Xổ số",
        description = "Không thể mua vé, xổ số sắp diễn ra!",
        type = "error",
        position = "center-left",
        duration = Config.NotifyDuration
    })
end)

-- Nhận jackpot từ server (bỏ thời gian)
local totalPool = 0
RegisterNetEvent('lottery:receiveJackpot', function(jackpot)
    totalPool = jackpot
    ShowLotteryMenu(jackpot)
end)

-- Thông báo Jackpot tăng
RegisterNetEvent('lottery:jackpotUpdated', function(jackpot)
    totalPool = jackpot
    lib.notify({
        title = "Xổ số",
        description = "Jackpot đã tăng lên: " .. jackpot .. "$!",
        type = "info",
        position = "center-left",
        duration = Config.NotifyDuration
    })
end)
