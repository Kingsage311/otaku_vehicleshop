local QBCore = exports['qb-core']:GetCoreObject()
local HasAlreadyEnteredMarker = false
local LastZone = nil
local CurrentAction = nil
local CurrentActionMsg = ""
local CurrentActionData = {}
local IsInShopMenu = false
local Categories = {}
local Vehicles = {}
local SaleVehicles = {}


if Config.VehicleshopInterior then --Checks if Config.VehicleshopInterior is set to true/false
	Citizen.CreateThread(
		function()
			RequestIpl("shr_int") -- Load walls and floor

			local interiorID = 7170
			LoadInterior(interiorID)
			EnableInteriorProp(interiorID, "csr_beforeMission") -- Load large window
			RefreshInterior(interiorID)
		end
	)
end

Citizen.CreateThread( function()
	QBCore.Functions.TriggerCallback("otaku_vehicleshop:getCategories", function(categories)
			Categories = categories
	end)

	QBCore.Functions.TriggerCallback("otaku_vehicleshop:getVehicles", function(vehicles)
		Vehicles = vehicles
		SaleVehicles = {}

		for k, v in pairs(vehicles) do
			if v.instore then
				table.insert(SaleVehicles, v)
			end
		end
	end)
end)


RegisterNetEvent("otaku_vehicleshop:sendCategories")
AddEventHandler(
	"otaku_vehicleshop:sendCategories",
	function(categories)
		Categories = categories
	end
)

RegisterNetEvent("otaku_vehicleshop:sendVehicles")
AddEventHandler(
	"otaku_vehicleshop:sendVehicles",
	function(vehicles)
		Vehicles = vehicles

		SaleVehicles = {}
		for k, v in pairs(vehicles) do
			if v.instore then
				table.insert(SaleVehicles, v)
			end
		end
	end
)

function StartShopRestriction()
	Citizen.CreateThread(
		function()
			while IsInShopMenu do
				Citizen.Wait(1)

				DisableControlAction(0, 75, true) -- Disable exit vehicle
				DisableControlAction(27, 75, true) -- Disable exit vehicle
			end
		end
	)
end

RegisterNUICallback("BuyVehicle", function(data, cb)    
    SetNuiFocus(false, false)
    local veh = data.vehicle
    local playerPed = PlayerPedId()
    IsInShopMenu = false

    QBCore.Functions.TriggerCallback("otaku_vehicleshop:buyVehicle", function(hasEnoughMoney)
        if hasEnoughMoney then
            QBCore.Functions.SpawnVehicle(veh.model, function(vehicle)
                TaskWarpPedIntoVehicle(playerPed, vehicle, -1)
                local newPlate = string.upper(GetRandomLetter(2) .. GetRandomNumber(2) .. GetRandomLetter(2) .. GetRandomNumber(2))
                local vehicleProps = QBCore.Functions.GetVehicleProperties(vehicle)
                vehicleProps.plate = newPlate
                SetVehicleNumberPlateText(vehicle, newPlate)
				TriggerEvent('vehiclekeys:client:SetOwner')
                TriggerServerEvent("otaku_vehicleshop:setVehicleOwned", vehicleProps)
            end, Config.Zones.ShopOutside.Pos, true)
        else
            QBCore.Functions.Notify('Not Enough Money', 'error', 5000)
        end
    end, veh.model)
end)

RegisterNUICallback(
	"CloseMenu",
	function()
		SetNuiFocus(false, false)
		IsInShopMenu = false
	end
)

function Round(value, numDecimalPlaces)
    if numDecimalPlaces then
        local power = 10^numDecimalPlaces
        return math.floor((value * power) + 0.5) / (power)
    else
        return math.floor(value + 0.5)
    end
end 

function Trim(value)
    if value then
        return (string.gsub(value, "^%s*(.-)%s*$", "%1"))
    else
        return nil
    end
end 

function GroupDigits(value)
    local left,num,right = string.match(value,'^([^%d]*%d)(%d*)(.-)$')
    return left..(num:reverse():gsub('(%d%d%d)','%1' .. ','):reverse())..right
end 

function OpenShopMenu()
	if not IsInShopMenu then
		IsInShopMenu = true
		SetNuiFocus(true, true)

		local selectedCategory = "ltdedition"
		if not Config.LtdEditions then
			selectedCategory = Categories[1].name
		end

		SendNUIMessage(
			{
				show = true,
				cars = SaleVehicles,
				categories = Categories,
				selectedCategory = selectedCategory
			}
		)
	end
end

function WaitForVehicleToLoad(modelHash)
	modelHash = (type(modelHash) == "number" and modelHash or GetHashKey(modelHash))

	if not HasModelLoaded(modelHash) then
		RequestModel(modelHash)

		while not HasModelLoaded(modelHash) do
			Citizen.Wait(1)

			DisableControlAction(0, 27, true) -- Up
			DisableControlAction(0, 173, true) -- Down
			DisableControlAction(0, 174, true) -- Left
			DisableControlAction(0, 175, true) -- Right
			DisableControlAction(0, 176, true) -- Enter
			DisableControlAction(0, 177, true) -- Backspace

			drawLoadingText(_U("shop_awaiting_model"), 255, 255, 255, 255)
		end
	end
end

AddEventHandler(
	"otaku_vehicleshop:hasEnteredMarker",
	function(zone)
		if zone == "ShopEntering" then
			CurrentAction = "shop_menu"
			CurrentActionMsg = "press ~INPUT_CONTEXT~ to access the menu"
			CurrentActionData = {}

			AddTextEntry(GetCurrentResourceName(), CurrentActionMsg)
			DisplayHelpTextThisFrame(GetCurrentResourceName(), false)
		elseif zone == "ResellVehicle" then
			local playerPed = PlayerPedId()

			if IsPedSittingInAnyVehicle(playerPed) then
				local vehicle = GetVehiclePedIsIn(playerPed, false)
				local vehicleData, model, resellPrice, plate

				if GetPedInVehicleSeat(vehicle, -1) == playerPed then
					for k, v in pairs(Vehicles) do
						if GetHashKey(v.model) == GetEntityModel(vehicle) then
							vehicleData = v
							break
						end
					end

					resellPrice = Round(vehicleData.price / 100 * Config.ResellPercentage)
					model = GetEntityModel(vehicle)
					plate = Trim(GetVehicleNumberPlateText(vehicle))

					CurrentAction = "resell_vehicle"
					CurrentActionMsg = _U("sell_menu", vehicleData.name, GroupDigits(resellPrice))

					CurrentActionData = {
						vehicle = vehicle,
						label = vehicleData.name,
						price = resellPrice,
						model = model,
						plate = plate
					}

					AddTextEntry(GetCurrentResourceName(), CurrentActionMsg)
					DisplayHelpTextThisFrame(GetCurrentResourceName(), false)
				end
			end
		end
	end
)

AddEventHandler(
	"otaku_vehicleshop:hasExitedMarker",
	function(zone)
		if not IsInShopMenu then
			SetNuiFocus(false, false)
		end

		CurrentAction = nil
	end
)

AddEventHandler(
	"onResourceStop",
	function(resource)
		if resource == GetCurrentResourceName() then
			if IsInShopMenu then
				SetNuiFocus(false, false)

				local playerPed = PlayerPedId()
				FreezeEntityPosition(playerPed, false)
				SetEntityVisible(playerPed, true)
				SetEntityCoords(playerPed, Config.Zones.ShopEntering.Pos.x, Config.Zones.ShopEntering.Pos.y, Config.Zones.ShopEntering.Pos.z)
			end
		end
	end
)

-- Create Blips
Citizen.CreateThread(
	function()
		local blip = AddBlipForCoord(Config.Zones.ShopEntering.Pos.x, Config.Zones.ShopEntering.Pos.y, Config.Zones.ShopEntering.Pos.z)

		SetBlipSprite(blip, 326)
		SetBlipDisplay(blip, 4)
		SetBlipScale(blip, 0.8)
		SetBlipAsShortRange(blip, true)

		BeginTextCommandSetBlipName("STRING")
		AddTextComponentString("Car Dealer")
		EndTextCommandSetBlipName(blip)
	end
)

-- Display markers
Citizen.CreateThread(
	function()
		local waitTime = 500
		while SaleVehicles == {} or Categories == {} do
			Citizen.Wait(200)
		end

		while true do
			Citizen.Wait(waitTime)
			waitTime = 500

			local coords = GetEntityCoords(PlayerPedId())

			for k, v in pairs(Config.Zones) do
				if (v.Type ~= -1 and GetDistanceBetweenCoords(coords, v.Pos.x, v.Pos.y, v.Pos.z, true) < Config.DrawDistance) then
					waitTime = 0
					DrawMarker(
						v.Type,
						v.Pos.x,
						v.Pos.y,
						v.Pos.z,
						0.0,
						0.0,
						0.0,
						0.0,
						0.0,
						0.0,
						v.Size.x,
						v.Size.y,
						v.Size.z,
						120,
						120,
						240,
						100,
						false,
						true,
						2,
						false,
						false,
						false,
						false
					)
				end
			end
		end
	end
)

-- Enter / Exit marker events
Citizen.CreateThread(
	function()
		local waitTime = 500
		while SaleVehicles == {} or Categories == {} do
			Citizen.Wait(200)
		end

		while true do
			Citizen.Wait(waitTime)
			waitTime = 500

			local coords = GetEntityCoords(PlayerPedId())
			local isInMarker = false
			local currentZone = nil

			for k, v in pairs(Config.Zones) do
				if (GetDistanceBetweenCoords(coords, v.Pos.x, v.Pos.y, v.Pos.z, true) < v.Size.x) then
					waitTime = 0
					isInMarker = true
					currentZone = k
				end
			end

			if (isInMarker and not HasAlreadyEnteredMarker) or (isInMarker and LastZone ~= currentZone) then
				HasAlreadyEnteredMarker = true
				LastZone = currentZone
				TriggerEvent("otaku_vehicleshop:hasEnteredMarker", currentZone)
			end

			if not isInMarker and HasAlreadyEnteredMarker then
				HasAlreadyEnteredMarker = false
				TriggerEvent("otaku_vehicleshop:hasExitedMarker", LastZone)
			end
		end
	end
)

-- Key controls
Citizen.CreateThread(
	function()
		while true do
			Citizen.Wait(10)

			if CurrentAction == nil then
				Citizen.Wait(500)
			else
				if IsControlJustReleased(0, 38) then
					if CurrentAction == "shop_menu" then
						OpenShopMenu()
					elseif CurrentAction == "resell_vehicle" then
						QBCore.Functions.TriggerCallback(
							"otaku_vehicleshop:resellVehicle",
							function(vehicleSold)
								if vehicleSold then
									QBCore.Functions.DeleteVehicle(CurrentActionData.vehicle)
									QBCore.Functions.Notify('Vehicle Sold', 'succsess', 5000) 
								else
									QBCore.Functions.Notify('You dont own this Vehicle', 'error', 5000)
								end
							end,
							CurrentActionData.plate,
							CurrentActionData.model
						)
					end

					CurrentAction = nil
				end
			end
		end
	end
)

function drawLoadingText(text, red, green, blue, alpha)
	SetTextFont(4)
	SetTextProportional(0)
	SetTextScale(0.0, 0.5)
	SetTextColour(red, green, blue, alpha)
	SetTextDropShadow(0, 0, 0, 0, 255)
	SetTextEdge(1, 0, 0, 0, 255)
	SetTextDropShadow()
	SetTextOutline()
	SetTextCentre(true)

	BeginTextCommandDisplayText("STRING")
	AddTextComponentSubstringPlayerName(text)
	EndTextCommandDisplayText(0.5, 0.5)
end

function getVehicleData(model)
	for k, v in pairs(Vehicles) do
		if tostring(GetHashKey(v.model)) == tostring(model) then
			return v
		end
	end
end
