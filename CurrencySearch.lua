local addonName, cs = ...

local searchBox
local eventReceiver = CreateFrame("Frame")
eventReceiver:RegisterEvent("PLAYER_ENTERING_WORLD")

CURRENCYSEARCH_SETTINGS = {}

local category = Settings.RegisterVerticalLayoutCategory(addonName)

local baseList = {}
local map = {}

local expandedList = {}

local function expandAllHeaders()
    local currencyIndex = 1
    local currencyData = C_CurrencyInfo.GetCurrencyListInfo(currencyIndex);

    while(currencyData) do
        if(currencyData.isHeader) then
            C_CurrencyInfo.ExpandCurrencyList(currencyIndex, true)

        end

        currencyIndex = currencyIndex + 1
        currencyData = C_CurrencyInfo.GetCurrencyListInfo(currencyIndex);
    end
end

local function sortCurrencyMapTable(k1, k2)
    if(baseList[k1.currencyIndex].currencyID > 0 and baseList[k2.currencyIndex].currencyID > 0) then
        return baseList[k1.currencyIndex].currencyID > baseList[k2.currencyIndex].currencyID

    else
        return k1.currencyIndex < k2.currencyIndex

    end
end

local function updateCurrencyMap()
    map = {}

    local lastUpperIndex, lastMiddleIndex

    for k, v in ipairs(baseList) do
        local currencyData = v

        if(currencyData.isHeader) then
            if(currencyData.currencyListDepth == 0) then
                table.insert(map, {currencyIndex = currencyData.currencyIndex, children = {}})
                lastUpperIndex = #map
                lastMiddleIndex = nil

            elseif(currencyData.currencyListDepth == 1) then
                table.insert(map[lastUpperIndex].children, {currencyIndex = currencyData.currencyIndex, children = {}})
                lastMiddleIndex = #map[lastUpperIndex].children

            end
        else
            if(currencyData.depth1Header) then
                table.insert(map[lastUpperIndex].children[lastMiddleIndex].children , {currencyIndex = currencyData.currencyIndex})
                
            else
                table.insert(map[lastUpperIndex].children, {currencyIndex = currencyData.currencyIndex})
                lastMiddleIndex = #map[lastUpperIndex].children

            end
        end
    end
    
    if(CURRENCYSEARCH_SETTINGS.sortByID) then
        for _, v in ipairs(map) do
            if(v.children) then
                table.sort(v.children, sortCurrencyMapTable)

                for _, y in ipairs(v.children) do
                    if(y.children) then
                        table.sort(y.children, sortCurrencyMapTable)

                    end
                end
            end
        end
    end
end

local function resetExpandedList()
    local currencyIndex = 1
    local currencyData = C_CurrencyInfo.GetCurrencyListInfo(currencyIndex);

    while(currencyData) do
        if(currencyData.isHeader) then
            if(expandedList[currencyData.name] ~= nil) then
                C_CurrencyInfo.ExpandCurrencyList(currencyIndex, expandedList[currencyData.name])

            else
                C_CurrencyInfo.ExpandCurrencyList(currencyIndex, currencyData.isHeaderExpanded)

            end
        end

        currencyIndex = currencyIndex + 1
        currencyData = C_CurrencyInfo.GetCurrencyListInfo(currencyIndex);
    end
end

local function saveExpandedList()
    local currencyIndex = 1
    local currencyData = C_CurrencyInfo.GetCurrencyListInfo(currencyIndex);

    while(currencyData) do
        if(currencyData.isHeader) then
            expandedList[currencyData.name] = currencyData.isHeaderExpanded

        end

        currencyIndex = currencyIndex + 1
        currencyData = C_CurrencyInfo.GetCurrencyListInfo(currencyIndex);
    end
end

local function updateBaseCurrencyList(expand)
    if(expand) then
        expandAllHeaders()

    end

    local upperHeader = nil
    local middleHeader = nil

    baseList = {}

    for currencyIndex = 1, C_CurrencyInfo.GetCurrencyListSize() do
        local currencyData = C_CurrencyInfo.GetCurrencyListInfo(currencyIndex);

        if currencyData then
            if(currencyData.isHeader == true) then
                if(currencyData.currencyListDepth == 0) then
                    upperHeader = currencyIndex
                    middleHeader = nil

                elseif(currencyData.currencyListDepth == 1) then
                    middleHeader = currencyIndex
                    currencyData.depth0Header = upperHeader

                end
            else
                currencyData.depth0Header = upperHeader
                currencyData.depth1Header = middleHeader

            end

            currencyData.currencyIndex = currencyIndex;
            tinsert(baseList, currencyData)

        end
    end

    updateCurrencyMap()
end

local currencyList = {}
local addedCurrencies = {}

local function addCurrencyToOfficialList(currencyIndex)
    if(not addedCurrencies[currencyIndex] and baseList[currencyIndex]) then
        tinsert(currencyList, baseList[currencyIndex])
        addedCurrencies[currencyIndex] = true

    end
end

local hadText = false

local function enableAddonFunctionality()
    TokenFrame.Update = function()
        local self =  TokenFrame

        local numTokenTypes = C_CurrencyInfo.GetCurrencyListSize();
        CharacterFrameTab3:SetShown(numTokenTypes > 0);

        local currencyDataReady = not C_CurrencyInfo.DoesCurrentFilterRequireAccountCurrencyData() or C_CurrencyInfo.IsAccountCharacterCurrencyDataReady();
        self:SetLoadingSpinnerShown(not currencyDataReady);
        if not currencyDataReady then
            return;
        end

        local lowerBoxText = strlower(searchBox:GetText() or "")
        updateBaseCurrencyList(lowerBoxText ~= "")

        currencyList = {};
        addedCurrencies = {}

        local restAllowed, lastDepth

        for _, v in ipairs(map) do
            restAllowed = false
            local startIndex = string.find(strlower(baseList[v.currencyIndex].name), lowerBoxText)

            if(startIndex) then
                restAllowed = true
                addCurrencyToOfficialList(v.currencyIndex)
            end
    
            if(v.children) then
                for _, y in ipairs(v.children) do
                    startIndex = string.find(strlower(baseList[y.currencyIndex].name), lowerBoxText)

                    if(not startIndex and CURRENCYSEARCH_SETTINGS.includeDescriptions and baseList[y.currencyIndex].currencyID > 0) then
                        startIndex = string.find(strlower(C_CurrencyInfo.GetCurrencyInfo(baseList[y.currencyIndex].currencyID).description), lowerBoxText)

                    end

                    if(lastDepth and lastDepth > 1) then
                        restAllowed = false
                    end

                    if(startIndex or restAllowed) then
                        if(baseList[y.currencyIndex].isHeader) then
                            restAllowed = true
                        end
                        
                        addCurrencyToOfficialList(baseList[y.currencyIndex].depth0Header)
                        addCurrencyToOfficialList(y.currencyIndex)
                    end
                        
                    if(y.children) then
                        for _, b in ipairs(y.children) do
                            --DEPTH2
                            startIndex = string.find(strlower(baseList[b.currencyIndex].name), lowerBoxText)
    
                            if(not startIndex and CURRENCYSEARCH_SETTINGS.includeDescriptions and baseList[b.currencyIndex].currencyID > 0) then
                                startIndex = string.find(strlower(C_CurrencyInfo.GetCurrencyInfo(baseList[b.currencyIndex].currencyID).description), lowerBoxText)
    
                            end

                            if(startIndex or restAllowed) then
                                addCurrencyToOfficialList(baseList[b.currencyIndex].depth0Header)
                                addCurrencyToOfficialList(baseList[b.currencyIndex].depth1Header)
                                addCurrencyToOfficialList(b.currencyIndex)

                                lastDepth = 2
                            end
                        end
                    end
                end
            end
        end

        self.ScrollBox:SetDataProvider(CreateDataProvider(currencyList), ScrollBoxConstants.RetainScrollPosition);

        -- If we're updating the currency list while the "Options" popup is open then we should refresh it as well
        if self.selectedID and self.Popup:IsShown() then
            local function FindSelectedTokenButton(button, elementData)
                return elementData.currencyIndex == self.selectedID;
            end

            local selectedEntry = self.ScrollBox:FindFrameByPredicate(FindSelectedTokenButton);
            if selectedEntry then
                self:UpdatePopup(selectedEntry);
            end
        end

        self.ScrollBox:RegisterCallback(ScrollBoxListMixin.Event.OnDataRangeChanged, GenerateClosure(self.RefreshAccountTransferableCurrenciesTutorial), self);
    end
end

local function loadCurrencySearch()
    if(TokenFrame) then
        local descriptionSetting = Settings.RegisterAddOnSetting(category, "CURRENCYSEARCH_IncludeDescriptions", "includeDescriptions", CURRENCYSEARCH_SETTINGS, "boolean", "Include descriptions", false)
        Settings.CreateCheckbox(category, descriptionSetting, "Include/exclude currency description searching (may lag on lower end machines).")


        Settings.RegisterAddOnSetting(category, "CURRENCYSEARCH_AllowTransfer", "allowTransfer", CURRENCYSEARCH_SETTINGS, "boolean", "Allow transfers of currency (this functionality is limited by Blizzard)", true)

        local sortSetting = Settings.RegisterAddOnSetting(category, "CURRENCYSEARCH_SortByID", "sortByID", CURRENCYSEARCH_SETTINGS, "boolean", "Sort by currency ID", true)
        sortSetting:SetValueChangedCallback(function() updateBaseCurrencyList(true) end)
        Settings.CreateCheckbox(category, sortSetting, "Sort currencies by their ID and not by name.")
        Settings.RegisterAddOnCategory(category)
        
        local settingsButton = CreateFrame("Button", "CurrencySearch_SettingsButton", TokenFrame, "UIButtonTemplate")
        settingsButton:SetSize(14, 14)
        settingsButton:SetNormalAtlas("QuestLog-icon-setting")
        settingsButton:SetHighlightAtlas("QuestLog-icon-setting")
        settingsButton:SetScript("OnClick", function()
            CURRENCYSEARCH_OpenInterfaceOptions()

        end)
        settingsButton:SetFrameStrata("HIGH")
        settingsButton:SetPoint("RIGHT", CharacterFrameCloseButton, "LEFT", -2, 0)
    
        searchBox = CreateFrame("EditBox", "TokenFrameSearchBox", TokenFrame, "SearchBoxTemplate")
        searchBox:SetHeight(35)
        searchBox:SetWidth(140)
        searchBox:SetShown(not CURRENCYSEARCH_SETTINGS.allowTransfer)
        searchBox:SetPoint("RIGHT", TokenFrame.filterDropdown, "LEFT", -5, 0)
        searchBox:SetScript("OnTextChanged", function(self)
            SearchBoxTemplate_OnTextChanged(self)

            if(self:GetText() == "") then
                resetExpandedList()
                hadText = false
                
            elseif(not hadText) then
                saveExpandedList()
                hadText = true

            end
    
            if(not CURRENCYSEARCH_SETTINGS.allowTransfers) then
                TokenFrame:Update()

            end
        end)

        local taintButton = CreateFrame("CheckButton", "TokenFrameAllowTransfersButton", TokenFrame, "UICheckButtonTemplate")
        taintButton:SetSize(25, 25)
        taintButton:SetPoint("RIGHT", searchBox, "LEFT", -5, 0)
        taintButton:SetChecked(CURRENCYSEARCH_SETTINGS.allowTransfers)
        taintButton:SetScript("OnClick", function(self)
            CURRENCYSEARCH_SETTINGS.allowTransfers = self:GetChecked()

            if(CURRENCYSEARCH_SETTINGS.allowTransfers) then
                C_UI.Reload()

            else
                enableAddonFunctionality()

            end

            searchBox:SetShown(CURRENCYSEARCH_SETTINGS.allowTransfer)
        end)
        taintButton:SetScript("OnEnter", function(self)
            --HERE
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText("Transfer of currency is currently " .. (self:GetChecked() and "enabled" or "disabled") .. ".")
            GameTooltip:AddLine("If you want to search for currencies and have them sorted you have to disable this functionality.")
            GameTooltip:Show()
        end)
        taintButton:SetScript("OnLeave", GameTooltip_Hide)

        saveExpandedList()

        updateBaseCurrencyList(true)

        resetExpandedList()
        
        if(not CURRENCYSEARCH_SETTINGS.allowTransfers) then
            enableAddonFunctionality()
        end
        
        eventReceiver:RegisterEvent("CURRENCY_DISPLAY_UPDATE")
    end
end



local function events(_, event, ...)
    if(event == "PLAYER_ENTERING_WORLD") then
        if(TokenFrame and not _G["CurrencySearch_SettingsButton"]) then
            loadCurrencySearch()

        end
    elseif(event == "CURRENCY_DISPLAY_UPDATE") then
        updateBaseCurrencyList(true)

        if(not CURRENCYSEARCH_SETTINGS.allowTransfers) then
            TokenFrame:Update()

        end
    end
end

eventReceiver:SetScript("OnEvent", events)

function CURRENCYSEARCH_OpenInterfaceOptions()
    Settings.OpenToCategory(category:GetID())
end