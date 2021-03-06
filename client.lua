local PickerIsOpen = false
local InteractionMarker = 0

local entityEnumerator = {
	__gc = function(enum)
		if enum.destructor and enum.handle then
			enum.destructor(enum.handle)
		end
		enum.destructor = nil
		enum.handle = nil
	end
}

function EnumerateEntities(firstFunc, nextFunc, endFunc)
	return coroutine.wrap(function()
		local iter, id = firstFunc()

		if not id or id == 0 then
			endFunc(iter)
			return
		end

		local enum = {handle = iter, destructor = endFunc}
		setmetatable(enum, entityEnumerator)

		local next = true
		repeat
			coroutine.yield(id)
			next, id = nextFunc(iter)
		until not next

		enum.destructor, enum.handle = nil, nil
		endFunc(iter)
	end)
end

function EnumerateObjects()
	return EnumerateEntities(FindFirstObject, FindNextObject, EndFindObject)
end

function IsPlayerNearCoords(coords, radius)
	local playerCoords = GetEntityCoords(PlayerPedId())

	return GetDistanceBetweenCoords(playerCoords.x, playerCoords.y, playerCoords.z, coords.x, coords.y, coords.z, true) <= radius
end

function HasCompatibleModel(entity, models)
	local entityModel = GetEntityModel(entity)

	for _, model in ipairs(models) do
		if entityModel  == GetHashKey(model) then
			return model
		end
	end
	return nil
end

function CanStartInteractionAtObject(interaction, object, objectCoords)
	if not IsPlayerNearCoords(objectCoords, interaction.radius) then
		return nil
	end

	return HasCompatibleModel(object, interaction.objects)
end

function StartInteractionAtObject(interaction)
	local objectHeading = GetEntityHeading(interaction.object)
	local objectCoords = GetEntityCoords(interaction.object)

	local r = math.rad(objectHeading)
	local cosr = math.cos(r)
	local sinr = math.sin(r)

	local x = interaction.x * cosr - interaction.y * sinr + objectCoords.x
	local y = interaction.y * cosr + interaction.x * sinr + objectCoords.y
	local z = interaction.z + objectCoords.z
	local h = interaction.heading + objectHeading

	ClearPedTasksImmediately(PlayerPedId())
	
	SetEntityCanBeDamaged(PlayerPedId(), false)
        ClearEntityLastDamageEntity(PlayerPedId())
        SetEntityOnlyDamagedByPlayer(PlayerPedId(), false)

	FreezeEntityPosition(PlayerPedId(), true)

	TaskStartScenarioAtPosition(PlayerPedId(), GetHashKey(interaction.scenario), x, y, z, h, -1, false, true)
end

function IsCompatible(t)
	return not t.isCompatible or t.isCompatible()
end

function SortInteractions(a, b)
	if a.distance == b.distance then
		if a.object == b.object then
			return a.scenario < b.scenario
		else
			return a.object < b.object
		end
	else
		return a.distance < b.distance
	end
end

function StartInteraction()
	local playerCoords = GetEntityCoords(PlayerPedId())

	local availableInteractions = {}

	for _, interaction in ipairs(Config.Interactions) do
		if IsCompatible(interaction) then
			for object in EnumerateObjects() do
				local objectCoords = GetEntityCoords(object)

				local modelName = CanStartInteractionAtObject(interaction, object, objectCoords)

				if modelName then
					local distance = GetDistanceBetweenCoords(playerCoords.x, playerCoords.y, playerCoords.z, objectCoords.x, objectCoords.y, objectCoords.z, true)

					for _, scenario in ipairs(interaction.scenarios) do
						if IsCompatible(scenario) then
							table.insert(availableInteractions, {
								x = interaction.x,
								y = interaction.y,
								z = interaction.z,
								heading = interaction.heading,
								scenario = scenario.name,
								object = object,
								modelName = modelName,
								distance = distance,
								label = interaction.label
							})
						end
					end
				end
			end
		end

		Wait(0)
	end

	if #availableInteractions > 0 then
		table.sort(availableInteractions, SortInteractions)
		SendNUIMessage({
			type = 'showInteractionPicker',
			interactions = json.encode(availableInteractions)
		})
		PickerIsOpen = true
	else
		SendNUIMessage({
			type = 'hideInteractionPicker'
		})
		SetInteractionMarker(0)
		PickerIsOpen = false
	end
end

function StopInteraction()
	ClearPedTasks(PlayerPedId())
	FreezeEntityPosition(PlayerPedId(), false)
end

function SetInteractionMarker(entity)
	InteractionMarker = entity
end

RegisterNUICallback('startInteraction', function(data, cb)
	StartInteractionAtObject(data)
	cb({})
end)

RegisterNUICallback('stopInteraction', function(data, cb)
	StopInteraction()
	cb({})
end)

RegisterNUICallback('setInteractionMarker', function(data, cb)
	SetInteractionMarker(data.entity)
	cb({})
end)

RegisterCommand('interact', function(source, args, raw)
	StartInteraction()
end, false)

AddEventHandler('onResourceStop', function(resourceName)
	if GetCurrentResourceName() == resourceName then
		SetInteractionMarker(0)
	end
end)

function DrawMarker(type, posX, posY, posZ, dirX, dirY, dirZ, rotX, rotY, rotZ, scaleX, scaleY, scaleZ, red, green, blue, alpha, bobUpAndDown, faceCamera, p19, rotate, textureDict, textureName, drawOnEnts)
	Citizen.InvokeNative(0x2A32FAA57B937173, type, posX, posY, posZ, dirX, dirY, dirZ, rotX, rotY, rotZ, scaleX, scaleY, scaleZ, red, green, blue, alpha, bobUpAndDown, faceCamera, p19, rotate, textureDict, textureName, drawOnEnts)
end

function DrawInteractionMarker()
	if InteractionMarker == 0 then
		return
	end

	local x, y, z = table.unpack(GetEntityCoords(InteractionMarker))

	DrawMarker(Config.MarkerType, x, y, z, 0, 0, 0, 0, 0, 0, 1.0, 1.0, 1.0, Config.MarkerColor[1], Config.MarkerColor[2], Config.MarkerColor[3], Config.MarkerColor[4], 0, 0, 2, 0, 0, 0, 0)
end

CreateThread(function()
	while true do
		Wait(0)

		if IsControlJustPressed(0, Config.InteractControl) then
			StartInteraction()
		end

		if PickerIsOpen then
			DisableControlAction(0, 0x0522B243, true)
			DisableControlAction(0, 0x05CA7C52, true)
			DisableControlAction(0, 0x0B1BE2E8, true)
			DisableControlAction(0, 0x156F7119, true)
			DisableControlAction(0, 0x21651AD6, true)
			DisableControlAction(0, 0x24978A28, true)
			DisableControlAction(0, 0x26A18F47, true)
			DisableControlAction(0, 0x2CD5343E, true)
			DisableControlAction(0, 0x3076E97C, true)
			DisableControlAction(0, 0x308588E6, true)
			DisableControlAction(0, 0x3B24C470, true)
			DisableControlAction(0, 0x424BD2D2, true)
			DisableControlAction(0, 0x43DBF61F, true)
			DisableControlAction(0, 0x4403F97F, true)
			DisableControlAction(0, 0x4E42696E, true)
			DisableControlAction(0, 0x5181713D, true)
			DisableControlAction(0, 0x5734A944, true)
			DisableControlAction(0, 0x580C4473, true)
			DisableControlAction(0, 0x5B48F938, true)
			DisableControlAction(0, 0x6319DB71, true)
			DisableControlAction(0, 0x6be9c207, true)
			DisableControlAction(0, 0x6E9734E8, true)
			DisableControlAction(0, 0x73A8FD83, true)
			DisableControlAction(0, 0x760A9C6F, true)
			DisableControlAction(0, 0x78114AB3, true)
			DisableControlAction(0, 0x7914A3DD, true)
			DisableControlAction(0, 0x7DBCD016, true)
			DisableControlAction(0, 0x841240A9, true)
			DisableControlAction(0, 0x84543902, true)
			DisableControlAction(0, 0x8A7B8833, true)
			DisableControlAction(0, 0x8CFFE0A1, true)
			DisableControlAction(0, 0x8E90C7BB, true)
			DisableControlAction(0, 0x8FFC75D6, true)
			DisableControlAction(0, 0x911CB09E, true)
			DisableControlAction(0, 0x9384E0A8, true)
			DisableControlAction(0, 0xADEAF48C, true)
			DisableControlAction(0, 0xAE69478F, true)
			DisableControlAction(0, 0xB0BCE5D6, true)
			DisableControlAction(0, 0xB28318C0, true)
			DisableControlAction(0, 0xB2F377E8, true)
			DisableControlAction(0, 0xBC2AE312, true)
			DisableControlAction(0, 0xC5CF41B2, true)
			DisableControlAction(0, 0xC67E13BB, true)
			DisableControlAction(0, 0xC7B5340A, true)
			DisableControlAction(0, 0xCDC4E4E9, true)
			DisableControlAction(0, 0xCF8A4ECA, true)
			DisableControlAction(0, 0xD2CC4644, true)
			DisableControlAction(0, 0xD3ECF82F, true)
			DisableControlAction(0, 0xD8F73058, true)
			DisableControlAction(0, 0xD9C50532, true)
			DisableControlAction(0, 0xE30CD707, true)
			DisableControlAction(0, 0xE8342FF2, true)
			DisableControlAction(0, 0xE9094BA0, true)

			if IsDisabledControlJustPressed(0, 0x911CB09E) then
				SendNUIMessage({
					type = 'moveSelectionUp'
				})
			end

			if IsDisabledControlJustPressed(0, 0x4403F97F) then
				SendNUIMessage({
					type = 'moveSelectionDown'
				})
			end

			if IsDisabledControlJustPressed(0, 0x43DBF61F) then
				SendNUIMessage({
					type = 'startInteraction'
				})
				SetInteractionMarker(0)
				PickerIsOpen = false
			end

			if IsDisabledControlJustPressed(0, 0x308588E6) then
				SendNUIMessage({
					type = 'hideInteractionPicker'
				})
				SetInteractionMarker(0)
				PickerIsOpen = false
			end
		end

		DrawInteractionMarker()
	end
end)
