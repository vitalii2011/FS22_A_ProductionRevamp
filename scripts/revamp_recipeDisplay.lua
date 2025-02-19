--[[
Production Revamp
Revamp Recipe Display

Copyright (C) braeven, Achimobil, 2022

Author: braeven, Achimobil

Date: 08.01.2023
Version: 1.6.5.0

Contact/Help/Tutorials:
discord.gg/gHmnFZAypk


Changelog:
1.0.0.0 @ 10.08.2022 - Aus revamp.lua in eigene Datei ausgelagert.
1.1.0.0 @ 21.08.2022 - Neue Produktionsmöglichkeiten eingebaut
1.1.1.0 @ 30.08.2022 - Neue Icons für Umgekehrten Modus eingefügt
1.2.0.0 @ 30.08.2022 - Produktionen sortierbar gemacht nach aktiv/inaktiv/alle
1.2.1.0 @ 31.08.2022 - Bugfix: Produktionen sollten nichtmehr ungewollt aus dem Menü verschwinden.
1.2.2.0 @ 31.08.2022 - Bugfix: Produktionsmenü-Filter sollte sich wieder resetten beim neu öffnen
1.2.3.0 @ 04.09.2022 - Bugfix: Übersetzungsfehler behoben
1.3.0.0 @ 27.09.2022 - Kompabilität mit PnH
1.4.0.0 @ 21.10.2022 - Unterstützung für multiple Production Modes
1.5.0.0 @ 08.11.2022 - Produktions-Modi für Produktions-Linien
1.5.0.1 @ 08.11.2022 - Schreibfehler behoben
1.6.0.0 @ 26.11.2022 - Korrektur der Rezept und Füllstandsanzeigen bei extra breiten Monitoren
1.6.1.0 @ 27.11.2022 - Versteckte Produktionslinien ermöglicht
1.6.2.0 @ 20.12.2022 - Code Cleanup
1.6.2.1 @ 03.01.2023 - Bugfix PnH und versteckte Produktionen
1.6.3.0 @ 03.01.2023 - Umbau Versteckte Storages
1.6.4.0 @ 04.01.2023 - Anzeige der Produktionsmodi erfolgt jetzt über mehrere Zeilen
1.6.5.0 @ 08.01.2023 - Versteckte Produktionen/Linien werden nicht mehr in der infoTable angezeigt


Important:.
No changes are allowed to this script without permission from Braeven AND Achimobil.
If you want to make a production with this script, look in the documentation, discord channels for tutorials/help or download the FS22_Revamp_Productions Pack for reference
Don't copy the script into a production, load the mod as a dependency!

Es dürfen an diesem Script keine Veränderungen ohne Erlaubnis von Braeven UND Achimobil gemacht werden.
Wenn du eine Produktion mit diesem Script bauen möchtest, lese dir die Dokumentation, die angepinnten Tutorials im Discord durch oder guck dir die FS22_Revamp_Productions an.
Nicht das Script in Produktionen kopieren, ladet den Mod über eine Dependency!

]]

RevampDisplay = {}

--Production Revamp: II oder Y hinzufügen sollte sharedThroughputCapacity aktiv sein
function RevampDisplay:getName(superFunc, revamp)
	local name = nil
	if self.name ~= nil then
		name = self.name
	else
		name = self.owningPlaceable:getName()
	end
	if revamp then
		if self.sharedThroughputCapacity == true then
			name = name .. "    -  Y"
		else
			name = name .. "    -  II"
		end
	end
	return name
end

ProductionPoint.getName = Utils.overwrittenFunction(ProductionPoint.getName, RevampDisplay.getName)



--Production Revamp: Nötig um sharedThroughputCapacity anzeigen zu können
function RevampDisplay:getTitleForSectionHeader(superFunc, list, section)
	if list == self.productionList then
		local productionPoint = self:getProductionPoints()[section]

		-- Pump'n'Hoses Produktionen ignorieren
		if productionPoint:isa(SandboxProductionPoint) or (productionPoint.owningPlaceable.isSandboxPlaceable ~= nil and productionPoint.owningPlaceable:isSandboxPlaceable()) then
			return superFunc(self, list, section)
		end

		return productionPoint:getName(true)
	elseif section == 1 then
		return g_i18n:getText("ui_productions_incomingMaterials")
	else
		return g_i18n:getText("ui_productions_outgoingProducts")
	end
end

InGameMenuProductionFrame.getTitleForSectionHeader = Utils.overwrittenFunction(InGameMenuProductionFrame.getTitleForSectionHeader, RevampDisplay.getTitleForSectionHeader)
print("Production Revamp: Production Gui overwritten #2")



--Production Revamp: Überschrieben um versteckte Produktionen zu ermöglichen
function RevampDisplay:getProductionPoints(superFunc)
	local TempProductions = self.chainManager:getProductionPointsForFarmId(self.playerFarm.farmId)
	local rProductions = {}
	for _, item in ipairs(TempProductions) do
		if not item.hideFromMenu then
			local productionLines = {}

			--Backup laden falls vorhanden
			if item.productionsBackup ~= nil then
				item.productions = item.productionsBackup
				item.productionsBackup = nil
			end
			item.productionsBackup = item.productions

			for _, production in ipairs(item.productions) do
				if not production.hideFromMenu == true then
					if InGameMenuProductionFrame.viewProductions == nil then
						table.insert(productionLines, production)
					elseif InGameMenuProductionFrame.viewProductions == 1 and production.status ~= ProductionPoint.PROD_STATUS.INACTIVE then
						table.insert(productionLines, production)
					elseif InGameMenuProductionFrame.viewProductions == 2 and production.status == ProductionPoint.PROD_STATUS.INACTIVE then
						table.insert(productionLines, production)
					end
				end
			end
			if #productionLines > 0 then
				item.productions = productionLines
				table.insert(rProductions, item)
			end
		end
	end
	table.sort(rProductions,compProductionPoints)
	return rProductions
end



--Production Revamp: Comp-Function from Achimobil InfoDisplayExpension, Sorts Productions by Name
function compProductionPoints(w1,w2)
	return w1:getName() .. w1.id < w2:getName() .. w2.id
end

InGameMenuProductionFrame.getProductionPoints = Utils.overwrittenFunction(InGameMenuProductionFrame.getProductionPoints, RevampDisplay.getProductionPoints)



--Production Revamp: Überschrieben damit in beiden Fällen die OutputCell verwendet wird(Input hat keine Schriftzeile)
function RevampDisplay:getCellTypeForItemInSection(superFunc, list, section, index)
	if list == self.storageList then
		return "outputCell"
	end
end

InGameMenuProductionFrame.getCellTypeForItemInSection = Utils.overwrittenFunction(InGameMenuProductionFrame.getCellTypeForItemInSection, RevampDisplay.getCellTypeForItemInSection)



--Production Revamp: updateDetails überarbeitet um neue Darstellung der Rezepte zu ermöglichen
function RevampDisplay:updateDetails(superFunc)
	local production, rProductionPoint = self:getSelectedProduction()
	if production == nil then
		return false
	end
	-- entfernen aller erstellten inneren elemente vom basegame, da diese neu erstellt werden
	for i = #self.detailRecipeInputLayout.elements, 1, -1 do
		self.detailRecipeInputLayout.elements[i]:delete()
	end
	for i = #self.detailRecipeOutputLayout.elements, 1, -1 do
		self.detailRecipeOutputLayout.elements[i]:delete()
	end

	-- entfernen aller erstellten elemente von revamp, da diese neu erstellt werden
	for i = #self.detailsBox.elements, 1, -1 do
		if self.detailsBox.elements[i] ~= nil and self.detailsBox.elements[i].revampLine ~= nil and self.detailsBox.elements[i].revampLine then
			self.detailsBox.elements[i]:delete()
		end
	end

	-- postion wiederherstellen vom pfeil element
	self.detailsBox.elements[10].position[2] = self.detailRecipeInputLayout.position[2] - self.detailRecipeInputLayout.size[2] - (self.detailsBox.elements[10].size[2] / 2)

	-- Pump'n'Hoses Produktionen ignorieren
	if rProductionPoint:isa(SandboxProductionPoint) or (rProductionPoint.owningPlaceable.isSandboxPlaceable ~= nil and rProductionPoint.owningPlaceable:isSandboxPlaceable()) then
		return superFunc(self)
	end

	local status = production.status
	local statusKey = ProductionPoint.PROD_STATUS_TO_L10N[production.status] or "unknown"	
	local statusProfile = "ingameMenuProductionDetailValue"

	if status == ProductionPoint.PROD_STATUS.MISSING_INPUTS then
		statusProfile = "ingameMenuProductionDetailValueError"
	elseif status == ProductionPoint.PROD_STATUS.NO_OUTPUT_SPACE then
		statusProfile = "ingameMenuProductionDetailValueError"
	end

	self.detailProductionStatus:applyProfile(statusProfile)
	self.detailProductionStatus:setLocaKey(statusKey)

	local costsPerActiveMonth = (production.costsPerActiveMonth / 24)* production.activeHours
	self.detailCostsPerMonth:setValue(costsPerActiveMonth)

	local maxboost = 0
	local masterboost = 0

	--Production Revamp: local function für die Output-Seite vom Rezept, berücksichtigend boost-Inputs, Zeilenumbruch und Farbanzeige abhängig von Booster
	local function createOutputRecipe(list, layout, newline)
		for i = 1, #layout.elements do
			layout.elements[1]:delete()
		end

		for index, item in ipairs(list) do
			if index > 1 then
				self.recipePlus:clone(layout)
			end
			local count = self.recipeText:clone(layout)
			if maxboost > 0 then
				local bamount = item.amount
				if item.boost == true then
					bamount = bamount * (1 + maxboost)
				elseif item.boost == "reverse" then
					bamount = bamount * (1 - maxboost)
				end
				count.didApplyAspectScaling = true
				count:setText(g_i18n:formatNumber(bamount, 2))

				local fillType = g_fillTypeManager:getFillTypeByIndex(item.type)
				local icon = self.recipeFillIcon:clone(layout)

				icon:setImageFilename(fillType.hudOverlayFilename)

				if item.boost == true then
					local count = self.recipeText:clone(layout)
					count.didApplyAspectScaling = true
					count:setText( "(= " .. g_i18n:formatNumber((maxboost + 1)*100, 2) .. "%) ")
					count:setTextColor(0.9157, 0.1420, 0.0002, 1)
				elseif item.boost == "reverse" then
					local rbooster = 1 - maxboost
					if rbooster < 0 then
						rbooster = 0
					end
					local count = self.recipeText:clone(layout)
					count.didApplyAspectScaling = true
					count:setText( "(= " .. g_i18n:formatNumber(rbooster*100, 2) .. "%) ")
					count:setTextColor(0.9157, 0.1420, 0.0002, 1)
				end
			else
				count.didApplyAspectScaling = true
				count:setText(g_i18n:formatNumber(item.amount, 2))
				local fillType = g_fillTypeManager:getFillTypeByIndex(item.type)
				local icon = self.recipeFillIcon:clone(layout)

				icon:setImageFilename(fillType.hudOverlayFilename)
			end
		end
		if newline then
			self.recipePlus:clone(layout)
		end
	end

	--Production Revamp: local function für die Input-Seite vom Rezept, berücksichtigend boost- und mix-Inputs, Zeilenumbruch und Farbanzeige Abhängig von Verfügbarkeit
	local function createInputRecipe(list, layout, mixIndex, newline)
		for i = 1, #layout.elements do
			layout.elements[i]:delete()
		end

		for index, item in ipairs(list) do
			if index > 1 then
				if mixIndex == 1 then
					 self.recipePlus:clone(layout)
				else
					local count = self.recipeText:clone(layout)
					count.didApplyAspectScaling = true
					count:setText(" || ")
				end
			end

			local count = self.recipeText:clone(layout)
			count.didApplyAspectScaling = true
			count:setText(g_i18n:formatNumber(item.amount, 2))
			if item.color == 1 then
				count:setTextColor(1, 0, 0, 1)
			elseif item.color == 2 then
				count:setTextColor(0.9157, 0.1420, 0.0002, 1)
			end
			local fillType = g_fillTypeManager:getFillTypeByIndex(item.type)
			local icon = self.recipeFillIcon:clone(layout)

			if mixIndex == 7 then
				local count = self.recipeText:clone(layout)
				count.didApplyAspectScaling = true
				count:setText( "(+ " .. g_i18n:formatNumber(item.boostfactor*100, 2) .. "%) ")
				if item.color == 2 then
					count:setTextColor(0.9157, 0.1420, 0.0002, 1)
				else
					maxboost = maxboost + item.boostfactor
				end
			end

			if mixIndex == 8 then
				local count = self.recipeText:clone(layout)
				count.didApplyAspectScaling = true
				count:setText( "(++ " .. g_i18n:formatNumber(item.boostfactor*100, 2) .. "%) ")
				if item.color == 2 then
					count:setTextColor(0, 1, 1, 1)
				else
					masterboost = masterboost + item.boostfactor
				end
			end
			icon:setImageFilename(fillType.hudOverlayFilename)
		end
		if newline then
			if mixIndex == 1 then
				 self.recipePlus:clone(layout)
			else
				local count = self.recipeText:clone(layout)
				count.didApplyAspectScaling = true
				count:setText(" || ")
			end
		end
	end

	--Production Revamp: Anzeige der Produktionsmodi auswerten
	local function processProductionMode(production, mode, productionModes, numModes)
		if productionModes ~= "" then
			productionModes = productionModes.. ", "
		end
		if mode=="hourly" then
			productionModes = string.format(g_i18n:getText("Revamp_productionHoursDependent"), productionModes, production.hours)
			numModes = numModes + 1
		elseif mode=="sun" then
			productionModes = string.format(g_i18n:getText("Revamp_sunProduction"), productionModes)
			numModes = numModes + 1
		elseif mode=="rain" then
			productionModes = string.format(g_i18n:getText("Revamp_rainProduction"), productionModes)
			numModes = numModes + 1
		elseif mode=="wind" then
			productionModes = string.format(g_i18n:getText("Revamp_windProduction"), productionModes)
			numModes = numModes + 1
		elseif mode=="temp" then
			productionModes = string.format(g_i18n:getText("Revamp_temperatureProduction"), productionModes)
			numModes = numModes + 1
		elseif mode=="tempNegative" then
			productionModes = string.format(g_i18n:getText("Revamp_temperatureNegativeProduction"), productionModes)
			numModes = numModes + 1
		elseif mode=="seasonal" then
			productionModes = string.format(g_i18n:getText("Revamp_seasonalProduction"), productionModes)
			numModes = numModes + 1
		elseif mode=="monthly" then
			productionModes = string.format(g_i18n:getText("Revamp_monthlyProduction"), productionModes)
			numModes = numModes + 1
		end

		return productionModes, numModes
	end

	--Production Revamp: Anzeige der Produktionsmodi einrichten
	local function addMode(productionModes, lineCounter)
		if lineCounter == 0 then
			local productionModeText = TextElement.new()
			productionModeText:copyAttributes(self.productionCostsDesc)
			productionModeText.revampLine = true
			productionModeText.text = g_i18n:getText("Revamp_productionMode")
			productionModeText.position[2] = self.detailCostsPerMonth.position[2] + ((self.detailCostsPerMonth.position[2] - self.detailCyclesPerMonth.position[2]))
			self.detailsBox:addElement(productionModeText)
			productionModeText:updateAbsolutePosition()
		end
		
		lineCounter = lineCounter + 1
		
		local productionMode = TextElement.new()
		productionMode:copyAttributes(self.detailCostsPerMonth)
		productionMode.revampLine = true
		productionMode.text = productionModes
		productionMode.position[2] = self.productionCostsDesc.position[2] + ((self.productionCostsDesc.position[2] - self.productionCyclesDesc.position[2]) * lineCounter)
		self.detailsBox:addElement(productionMode)
		productionMode:updateAbsolutePosition()

		productionModes = ""
		return productionModes, lineCounter
	end

	local lineCounter = 0
	local productionModes = ""
	local modes = string.split(production.mode, " ")
	local numModes = 0
	
	for _, mode in pairs(modes) do
		productionModes, numModes = processProductionMode(production, mode, productionModes, numModes)
		
		if numModes == 2 then
			productionModes, lineCounter = addMode(productionModes, lineCounter)
			numModes = 0
		end
	end

	if numModes ~= 0 then
		productionModes, lineCounter = addMode(productionModes, lineCounter)
	end
		
	--Production Revamp: ProduktionsInputs auslesen und in sortierte Listen speichern abhängig von ihrer Gruppe
	local InputList = {}
	InputList[1] = {}
	InputList[2] = {}
	InputList[3] = {}
	InputList[4] = {}
	InputList[5] = {}
	InputList[6] = {}
	InputList[7] = {}
	InputList[8] = {}
	local item = {}
	for index, item in ipairs(production.inputs) do
		local insert = item.mix +1
		local myListItem = InputList[insert]
		table.insert(myListItem, item)
	end

	--Production Revamp: Rezept-Übersicht erstellen, Input Seite
	local outputmax = 4
	local lineCounterBefore = lineCounter
	for mixIndex, list in pairs(InputList) do
		if list ~= nil and #list ~= 0 then 

			--Production Revamp: PlusZeichen zwischen zwei Zutaten-Listen, ausgenommen erste Zeile
			if lineCounter ~= lineCounterBefore then
				local myElement = FlowLayoutElement.new()
				myElement:copyAttributes(self.detailRecipeInputLayout)
				myElement.position[2] = self.detailRecipeInputLayout.position[2] - (self.detailRecipeInputLayout.size[2] * (lineCounter))
				myElement.revampLine = true

				lineCounter = lineCounter + 1
				self.recipePlus:clone(myElement)
				self.detailsBox:addElement(myElement)
				myElement:updateAbsolutePosition()
				myElement:invalidateLayout()
			end

			--Production Revamp: Zeilenumbruch nach 4 bzw. 2 Inputs durch Aufteilen der Listen
			local recipePuffer = {}
			local recipemax = 4
			if mixIndex >= 7 then
				recipemax = 2
				outputmax = 2
			end
			local numList = #list
			for index, item in ipairs(list) do
				table.insert(recipePuffer, item)
				if #recipePuffer == recipemax then
					local myElement = FlowLayoutElement.new()
					myElement:copyAttributes(self.detailRecipeInputLayout)
					myElement.position[2] = self.detailRecipeInputLayout.position[2] - (self.detailRecipeInputLayout.size[2] * (lineCounter))
					myElement.revampLine = true

					lineCounter = lineCounter + 1
					if numList > recipemax then
						createInputRecipe(recipePuffer, myElement, mixIndex, true)
					else
						createInputRecipe(recipePuffer, myElement, mixIndex, false)
					end
					self.detailsBox:addElement(myElement)

					myElement:updateAbsolutePosition()
					myElement:invalidateLayout()
					recipePuffer = {}
				end
			end

			--Production Revamp: sollte der Puffer nicht leer sein, letzte Input-Zeile generieren
			if #recipePuffer > 0 then
				local myElement = FlowLayoutElement.new()
				myElement:copyAttributes(self.detailRecipeInputLayout)
				myElement.position[2] = self.detailRecipeInputLayout.position[2] - (self.detailRecipeInputLayout.size[2] * (lineCounter))
				myElement.revampLine = true

				lineCounter = lineCounter + 1
				createInputRecipe(recipePuffer, myElement, mixIndex, false)
				self.detailsBox:addElement(myElement)

				myElement:updateAbsolutePosition()
				myElement:invalidateLayout()
			end
		end
	end

	--Production Revamp: Rezept-Text verschieben
	self.detailsBox.elements[8].position[2] = self.productionCostsDesc.position[2] - (self.detailRecipeInputLayout.size[2] * (lineCounterBefore + 1))
	self.detailsBox.elements[8]:updateAbsolutePosition()
	--lineCounter = lineCounter + 1
	
	--Production Revamp: Ergebniss-Pfeil verschieben
	self.detailsBox.elements[10].position[2] = self.detailRecipeInputLayout.position[2] - (self.detailRecipeInputLayout.size[2] * lineCounter) - (self.detailsBox.elements[10].size[2] / 2)
	self.detailsBox.elements[10]:updateAbsolutePosition()
	lineCounter = lineCounter + 1

	--Production Revamp: Rezept-Übersicht erstellen, Output Seite
	local numOutput = #production.outputs
	local outputPuffer = {}
	for index, item in ipairs(production.outputs) do
		table.insert(outputPuffer, item)

		--Production Revamp: Zeilenumbruch nach 4 bzw. 2 Inputs durch Aufteilen der Listen
		if #outputPuffer == outputmax then
			local myElement = FlowLayoutElement.new()
			myElement:copyAttributes(self.detailRecipeOutputLayout)
			myElement.position[2] = self.detailRecipeInputLayout.position[2] - (self.detailRecipeInputLayout.size[2] * lineCounter)
			myElement.revampLine = true

			lineCounter = lineCounter + 1
			if numOutput > outputmax then
				createOutputRecipe(outputPuffer, myElement, true)
			else
				createOutputRecipe(outputPuffer, myElement, false)
			end

			self.detailsBox:addElement(myElement)

			myElement:updateAbsolutePosition()
			myElement:invalidateLayout()
			outputPuffer = {}
		end
	end

	--Production Revamp: sollte der Puffer nicht leer sein, letzte Output-Zeile generieren
	if #outputPuffer > 0 then
		local myElement = FlowLayoutElement.new()
		myElement:copyAttributes(self.detailRecipeOutputLayout)
		myElement.position[2] = self.detailRecipeInputLayout.position[2] - (self.detailRecipeInputLayout.size[2] * lineCounter)
		myElement.revampLine = true

		createOutputRecipe(outputPuffer, myElement, false)
		self.detailsBox:addElement(myElement)

		myElement:updateAbsolutePosition()
		myElement:invalidateLayout()
	end

	local cyclesPerMonth = production.cyclesPerMonth
	if masterboost > 0 then
		cyclesPerMonth = cyclesPerMonth * (1 + masterboost)
		self.detailCyclesPerMonth:setTextColor(0.9157, 0.1420, 0.0002, 1)
	else
		self.detailCyclesPerMonth:setTextColor(1, 1, 1, 1)
	end

	cyclesPerMonth = MathUtil.round(cyclesPerMonth, 2)
	self.detailCyclesPerMonth:setText(cyclesPerMonth)

	self.storageList:reloadData()
end

InGameMenuProductionFrame.updateDetails = Utils.overwrittenFunction(InGameMenuProductionFrame.updateDetails, RevampDisplay.updateDetails)



--Production Revamp: Production GUI überschrieben um Füllstände, Einlagern und Input-Priority anzeigen zu können
function RevampDisplay:populateCellForItemInSection(superFunc, list, section, index, cell)
	if list == self.productionList then
		local productionPoint = self:getProductionPoints()[section]

		-- Pump'n'Hoses Produktionen ignorieren
		if productionPoint:isa(SandboxProductionPoint) or (productionPoint.owningPlaceable.isSandboxPlaceable ~= nil and productionPoint.owningPlaceable:isSandboxPlaceable()) then
			return superFunc(self, list, section, index, cell)
		end

		local production = productionPoint.productions[index]
		local fillTypeDesc = g_fillTypeManager:getFillTypeByIndex(production.primaryProductFillType)

		if fillTypeDesc ~= nil then
			cell:getAttribute("icon"):setImageFilename(fillTypeDesc.hudOverlayFilename)
		end

		cell:getAttribute("icon"):setVisible(fillTypeDesc ~= nil)
		cell:getAttribute("name"):setText(production.name or fillTypeDesc.title)

		local status = production.status
		local activityElement = cell:getAttribute("activity")

		if status == ProductionPoint.PROD_STATUS.RUNNING then
			activityElement:applyProfile("ingameMenuProductionProductionActivityActive")
		elseif status == ProductionPoint.PROD_STATUS.MISSING_INPUTS or status == ProductionPoint.PROD_STATUS.NO_OUTPUT_SPACE then
			activityElement:applyProfile("ingameMenuProductionProductionActivityIssue")
		else
			activityElement:applyProfile("ingameMenuProductionProductionActivity")
		end
	else
		local _, productionPoint = self:getSelectedProduction()
		local fillType, isInput = nil

		-- Pump'n'Hoses Produktionen ignorieren
		if productionPoint:isa(SandboxProductionPoint) or (productionPoint.owningPlaceable.isSandboxPlaceable ~= nil and productionPoint.owningPlaceable:isSandboxPlaceable()) then
			if cell.attributes["outputMode"] ~= nil then
				cell:getAttribute("outputMode"):setText("")
			end
			return superFunc(self, list, section, index, cell)
		end

		if section == 1 then
			fillType = self.selectedProductionPoint.inputFillTypeIdsArray[index]
			isInput = true
		else
			fillType = self.selectedProductionPoint.outputFillTypeIdsArray[index]
			isInput = false
		end

		if fillType ~= FillType.UNKNOWN then
			for i = #cell.elements, 1, -1 do
				if i >= 6 and cell.elements[i] ~= nil then
					cell.elements[i]:delete()
				end
			end
			local fillLevel = self.selectedProductionPoint:getFillLevel(fillType)
			local capacity = self.selectedProductionPoint:getCapacity(fillType)
			local fillTypeDesc = g_fillTypeManager:getFillTypeByIndex(fillType)

			cell:getAttribute("icon"):setImageFilename(fillTypeDesc.hudOverlayFilename)

			cell:getAttribute("fillType"):setText(fillTypeDesc.title)

			local weatherAffected = false
			local weatherFactor = false
			if isInput then
				for y = 1, #productionPoint.productions do
					local production = productionPoint.productions[y]
					for x = 1, #production.inputs do
						local input = production.inputs[x]
						if not input.weatherAffected==false and input.type == fillType then
							weatherAffected = input.weatherAffected
							weatherFactor = input.weatherFactor
						end
					end
				end
			else
				for y = 1, #productionPoint.productions do
					local production = productionPoint.productions[y]
					for x = 1, #production.outputs do
						local output = production.outputs[x]
						if not output.weatherAffected==false and output.type == fillType then
							weatherAffected = output.weatherAffected
							weatherFactor = output.weatherFactor
						end
					end
				end
			end

			if not weatherAffected==false then
				local weatherIcon = cell:getAttribute("icon")
				weatherIcon.name = "icon2"
				weatherIcon:clone(cell)

				if weatherFactor < 0 then
					weatherAffected = weatherAffected .."_reverse"
				end
				local path = ProductionPoint.Revamp .."images/weather_affected_".. weatherAffected ..".png"
				cell.elements[6]:setImageFilename(path)

				cell.elements[6].position[1] = cell.elements[6].position[1] + 0.009
				cell.elements[6].position[2] = cell.elements[6].position[2] - 0.025
				cell.elements[6].size[1] = cell.elements[6].size[1] * 0.9
				cell.elements[6].size[2] = cell.elements[6].size[2] * 0.9
			end

			-- für große breiten rechts ausrichten
			cell:getAttribute("fillLevel").textAlignment = RenderText.ALIGN_RIGHT
			cell:getAttribute("outputMode").textAlignment = RenderText.ALIGN_RIGHT

			--Production Revamp: Abgeändert um das Maximal Volumen anzeigen zu können
			cell:getAttribute("fillLevel"):setText(RevampHelper:formatCapacity(fillLevel, capacity, 0, fillTypeDesc.unitShort))

			if not isInput then
				local outputMode = productionPoint:getOutputDistributionMode(fillType)
				local outputModeText = g_i18n:getText("Revamp_Spawn")

				if outputMode == ProductionPoint.OUTPUT_MODE.DIRECT_SELL then
					outputModeText = self.i18n:getText("ui_production_output_selling")
				elseif outputMode == ProductionPoint.OUTPUT_MODE.AUTO_DELIVER then
					outputModeText = self.i18n:getText("ui_production_output_distributing")
				--Production Revamp: Hinzugefügt um die "Einlagern" Option anzeigen zu können
				elseif outputMode == ProductionPoint.OUTPUT_MODE.STORE then
					outputModeText = g_i18n:getText("Revamp_Store")
				end

				cell:getAttribute("outputMode"):setText(outputModeText)
			else
				if RevampSettings.current.PrioSystemActive then
					--Production Revamp: Hinzugefügt um Prioritäten anzeigen zu können
					local priority = productionPoint:getInputPriority(fillType)
					local outputModeText = g_i18n:getText("Revamp_DeliveryPriority")
					outputModeText = outputModeText.. ": " ..priority
					if priority <= 0 then
						outputModeText = g_i18n:getText("Revamp_DeliveryPriorityDeactivated")
					end

					cell:getAttribute("outputMode"):setText(outputModeText)
				else
					cell:getAttribute("outputMode"):setText("")
				end
			end

			self:setStatusBarValue(cell:getAttribute("bar"), fillLevel / capacity, isInput)
		end
	end
end

InGameMenuProductionFrame.populateCellForItemInSection = Utils.overwrittenFunction(InGameMenuProductionFrame.populateCellForItemInSection, RevampDisplay.populateCellForItemInSection)



--Production Revamp: Funktion um die Rezept-Farben im Multiplayer anzeigen zu können
function ProductionPoint:setProductionInputColor(productionId, inputId, color, noEventSend)
	local production = self.productionsIdToObj[productionId]
	inputId = tonumber(inputId)
	color = tonumber(color)
	production.inputs[inputId].color = color

	ProductionPointProductionInputColorEvent.sendEvent(self, productionId, inputId, color, noEventSend)
end



--Production Revamp: MenüButton um zwischen Inaktive/Aktive/Allen Produktionen umzuschalten
function RevampDisplay:updateMenuButtons(superFunc)
	local buttonText = "Revamp_ViewActiveProductions"
	if InGameMenuProductionFrame.viewProductions == 1 then
		buttonText = "Revamp_ViewInActiveProductions"
	elseif InGameMenuProductionFrame.viewProductions == 2 then
		buttonText = "Revamp_ViewAllProductions"
	end

	table.insert(self.menuButtonInfo, {
		profile = "buttonOk",
		inputAction = InputAction.MENU_EXTRA_2,
		text = self.i18n:getText(buttonText),
		callback = function()
			self:toggleProductionList()
		end
	})
	self:setMenuButtonInfoDirty()
end

InGameMenuProductionFrame.updateMenuButtons = Utils.appendedFunction(InGameMenuProductionFrame.updateMenuButtons, RevampDisplay.updateMenuButtons)



--Production Revamp: Toggle-Funktion für die ProduktionsAnzeige
function InGameMenuProductionFrame:toggleProductionList(clearView)
	if clearView == true then
		InGameMenuProductionFrame.viewProductions = nil
	else
		if InGameMenuProductionFrame.viewProductions == nil then
			InGameMenuProductionFrame.viewProductions = 1
		elseif InGameMenuProductionFrame.viewProductions == 1 then
			InGameMenuProductionFrame.viewProductions = 2
		else
			InGameMenuProductionFrame.viewProductions = nil
		end
		self.productionList:reloadData()
	end
end



--Production Revamp: ProduktionsMenü-Filter zurück setzen beim neu öffnen
function RevampDisplay:onFrameOpen(superFunc, productionPoint)
	InGameMenuProductionFrame.viewProductions = nil
end

InGameMenuProductionFrame.onFrameOpen = Utils.prependedFunction(InGameMenuProductionFrame.onFrameOpen, RevampDisplay.onFrameOpen)



ProductionPointInfoExtension = {}
--Production Revamp: Erweitert um Versteckte Produktionslinien nicht anzuzeigen Ingame
function ProductionPointInfoExtension:updateInfoNeu(_, superFunc, infoTable)
	--superFunc(self, infoTable)
	local hidden = true
	local hideComplete = false
	local activeProduction = nil
	for i = 1, #self.activeProductions do
		activeProduction = self.activeProductions[i]
		if activeProduction.hideFromMenu == false then
			hidden = false
		end
		if activeProduction.hideComplete == true then
			hideComplete = true
		end
	end

	if hideComplete == false then
		local owningFarm = g_farmManager:getFarmById(self:getOwnerFarmId())

		table.insert(infoTable, {
			title = g_i18n:getText("fieldInfo_ownedBy"),
			text = owningFarm.name
		})

		if #self.activeProductions > 0 then
			--einmal durchgehen, ob eine Prdouktion mindestens sichtbar bleibt
			local activeProduction = nil
			if hidden == false then
				table.insert(infoTable, self.infoTables.activeProds)

				for i = 1, #self.activeProductions do
					activeProduction = self.activeProductions[i]
					if activeProduction.hideFromMenu == false then
						local productionName = activeProduction.name or g_fillTypeManager:getFillTypeTitleByIndex(activeProduction.primaryProductFillType)

						table.insert(infoTable, {
							title = productionName,
							text = g_i18n:getText(ProductionPoint.PROD_STATUS_TO_L10N[self:getProductionStatus(activeProduction.id)])
						})
					end
				end
			end
		else
			table.insert(infoTable, self.infoTables.noActiveProd)
		end

		local fillType, fillLevel = nil
		local fillTypesDisplayed = false

		table.insert(infoTable, self.infoTables.storage)

		for i = 1, #self.inputFillTypeIdsArray do
			fillType = self.inputFillTypeIdsArray[i]
			fillLevel = self:getFillLevel(fillType)

			if fillLevel > 1 then
				fillTypesDisplayed = true

				table.insert(infoTable, {
					title = g_fillTypeManager:getFillTypeTitleByIndex(fillType),
					text = g_i18n:formatVolume(fillLevel, 0)
				})
			end
		end

		for i = 1, #self.outputFillTypeIdsArray do
			fillType = self.outputFillTypeIdsArray[i]
			fillLevel = self:getFillLevel(fillType)

			if fillLevel > 1 then
				fillTypesDisplayed = true

				table.insert(infoTable, {
					title = g_fillTypeManager:getFillTypeTitleByIndex(fillType),
					text = g_i18n:formatVolume(fillLevel, 0)
				})
			end
		end

		if not fillTypesDisplayed then
			table.insert(infoTable, self.infoTables.storageEmpty)
		end

		if self.palletLimitReached then
			table.insert(infoTable, self.infoTables.palletLimitReached)
		end
	end
end

ProductionPoint.updateInfo = Utils.overwrittenFunction(ProductionPoint.updateInfo, ProductionPointInfoExtension.updateInfoNeu)



print("Production Revamp: Production Gui overwritten")