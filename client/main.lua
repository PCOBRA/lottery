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

-- Hiển thị menu mua vé số
function ShowLotteryMenu(jackpot, nextDrawTime)
    lib.registerContext({
        id = 'lottery_menu',
        title = '🎰 XỔ SỐ - CƠ HỘI TRÚNG LỚN 🎰',
        options = {
            {
                title = "💰 Jackpot: " .. jackpot .. "$",
                description = "Thời gian quay số tiếp theo: " .. nextDrawTime,
                icon = "fas fa-coins",
                disabled = true
            },
            {
                title = "🎟️ Mua Vé Số",
                description = "Giá vé: 20000$ (Tối đa 2 vé) - Cơ hội trúng lớn đang chờ bạn!",
                icon = "fas fa-ticket-alt",
                iconColor = "#FFD700", -- Màu vàng cho icon
                onSelect = function()
                    TriggerServerEvent('lottery:buyTicket')
                end
            }
        }
    })
    lib.showContext('lottery_menu')
end

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
RegisterNetEvent('lottery:drawResult', function(winningNumber, prize)
    lib.notify({
        title = "Kết quả xổ số",
        description = "Số trúng thưởng: " .. winningNumber .. ". Giải thưởng: " .. prize .. "$",
        type = "inform",
        position = "center-left",
        duration = Config.NotifyDuration
    })
end)

-- Thông báo trúng thưởng
RegisterNetEvent('lottery:winPrize', function(amount)
    lib.notify({
        title = "Chúc mừng!",
        description = "Bạn đã trúng thưởng " .. amount .. "$ (đã vào ngân hàng sau thuế)!",
        type = "success",
        position = "center-left",
        duration = Config.NotifyDuration
    })
end)

-- Thông báo nhắc nhở
RegisterNetEvent('lottery:reminder', function(message)
    lib.notify({
        title = "Xổ số",
        description = message or "Xổ số sẽ diễn ra trong 10 phút nữa!",
        type = "info",
        position = "center-left",
        duration = Config.NotifyDuration
    })
end)

-- Thông báo khóa mua vé
RegisterNetEvent('lottery:buyLocked', function()
    lib.notify({
        title = "Xổ số",
        description = "Không thể mua vé, còn dưới 10 phút đến giờ quay!",
        type = "error",
        position = "center-left",
        duration = Config.NotifyDuration
    })
end)

-- Nhận jackpot và thời gian quay số từ server
RegisterNetEvent('lottery:receiveJackpot', function(jackpot, nextDrawTime)
    ShowLotteryMenu(jackpot, nextDrawTime)
end)

-- Thông báo Jackpot tăng
RegisterNetEvent('lottery:jackpotUpdated', function(jackpot)
    lib.notify({
        title = "Xổ số",
        description = "Jackpot đã tăng lên: " .. jackpot .. "$!",
        type = "info",
        position = "center-left",
        duration = Config.NotifyDuration
    })
end)