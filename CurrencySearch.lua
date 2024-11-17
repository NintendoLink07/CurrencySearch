local addonName, rs = ...
local wticc = WrapTextInColorCode

local searchBox
local eventReceiver = CreateFrame("Frame")
eventReceiver:RegisterEvent("PLAYER_ENTERING_WORLD")

CURRENCYSEARCH_SETTINGS = {}

local category = Settings.RegisterVerticalLayoutCategory(addonName)

local baseList = {}
local map = {}
local headers = {}

local function expandAllHeaders()
    for currencyIndex = 1, C_CurrencyInfo.GetCurrencyListSize() do
        local currencyData = C_CurrencyInfo.GetCurrencyListInfo(currencyIndex);

        if currencyData then
            if(currencyData.isHeader) then
                C_CurrencyInfo.ExpandCurrencyList(currencyIndex, true)

            end
        end
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

local function updateBaseCurrencyList()
    expandAllHeaders()

    local upperHeader = nil
    local middleHeader = nil

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

local actualIndex = 1

local function addCurrencyToOfficialList(currencyIndex)
    if(not addedCurrencies[currencyIndex]) then
        if(not baseList[currencyIndex].isHeader or baseList[currencyIndex].isHeader and baseList[currencyIndex].isHeaderExpanded) then
            tinsert(currencyList, baseList[currencyIndex])
            addedCurrencies[currencyIndex] = true
            
            actualIndex = actualIndex + 1

        end
    end
end

local function loadCurrencySearch()
    if(TokenFrame) then
        local descriptionSetting = Settings.RegisterAddOnSetting(category, "CURRENCYSEARCH_IncludeDescriptions", "includeDescriptions", CURRENCYSEARCH_SETTINGS, "boolean", "Include descriptions", false)
        Settings.CreateCheckbox(category, descriptionSetting, "Include/exclude currency description searching (may lag on lower end machines).")

        local sortSetting = Settings.RegisterAddOnSetting(category, "CURRENCYSEARCH_SortByID", "sortByID", CURRENCYSEARCH_SETTINGS, "boolean", "Sort by currency ID", true)
        sortSetting:SetValueChangedCallback(function() updateBaseCurrencyList() end)
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
    
        searchBox = CreateFrame("EditBox", nil, TokenFrame, "SearchBoxTemplate")
        searchBox:SetHeight(35)
        searchBox:SetWidth(160)
        searchBox:SetPoint("RIGHT", TokenFrame.filterDropdown, "LEFT", -5, 0)
        searchBox:SetScript("OnTextChanged", function(self)
            SearchBoxTemplate_OnTextChanged(self)
    
            TokenFrame:Update()
        end)

        updateBaseCurrencyList()
        
        TokenFrame.Update = function()
            local self =  TokenFrame

            local numTokenTypes = C_CurrencyInfo.GetCurrencyListSize();
            CharacterFrameTab3:SetShown(numTokenTypes > 0);

            local currencyDataReady = not C_CurrencyInfo.DoesCurrentFilterRequireAccountCurrencyData() or C_CurrencyInfo.IsAccountCharacterCurrencyDataReady();
            self:SetLoadingSpinnerShown(not currencyDataReady);
            if not currencyDataReady then
                return;
            end

            local boxText = searchBox:GetText() or ""

            expandAllHeaders() --needed for clickable currencies

            local lowerBoxText = string.lower(boxText)

            currencyList = {};
            addedCurrencies = {}

            local restAllowed

            actualIndex = 1

            for _, v in ipairs(map) do
                restAllowed = false
                --DEPTH0
                local startIndex = string.find(strlower(baseList[v.currencyIndex].name), lowerBoxText)

                if(startIndex) then
                    restAllowed = true
                    addCurrencyToOfficialList(v.currencyIndex)

                end
        
                if(v.children) then
                    for _, y in ipairs(v.children) do
                        --DEPTH1
                        startIndex = string.find(strlower(baseList[y.currencyIndex].name), lowerBoxText)

                        if(not startIndex and CURRENCYSEARCH_SETTINGS.includeDescriptions and baseList[y.currencyIndex].currencyID > 0) then
                            startIndex = string.find(strlower(C_CurrencyInfo.GetCurrencyInfo(baseList[y.currencyIndex].currencyID).description), lowerBoxText)

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
        
        eventReceiver:RegisterEvent("CURRENCY_DISPLAY_UPDATE")
    end
end



local function events(_, event, ...)
    if(event == "PLAYER_ENTERING_WORLD") then
        if(TokenFrame and not _G["CurrencySearch_SettingsButton"]) then
            loadCurrencySearch()
        end
    elseif(event == "CURRENCY_DISPLAY_UPDATE") then
        updateBaseCurrencyList()
        TokenFrame:Update()

    end
end

eventReceiver:SetScript("OnEvent", events)

function CURRENCYSEARCH_OpenInterfaceOptions()
    Settings.OpenToCategory(category:GetID())
end