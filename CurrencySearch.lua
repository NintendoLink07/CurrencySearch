local addonName, rs = ...
local wticc = WrapTextInColorCode

local searchBox
local eventReceiver = CreateFrame("Frame")
eventReceiver:RegisterEvent("PLAYER_ENTERING_WORLD")

CURRENCYSEARCH_SETTINGS = {}

local category = Settings.RegisterVerticalLayoutCategory(addonName)
local currencyList = {}
local firstActualIndex = 1

local function addDataWithIndexToList(currencyData, index)
    currencyData.currencyIndex = index;
    StripHyperlinks(currencyData.name)
    tinsert(currencyList, currencyData);
end

local function isNameInList(name)
    for _, v in ipairs(currencyList) do
        if(StripHyperlinks(v.name) == name) then
            return v
        end
    end

    return nil
end

local function checkForDescription(description, boxText)
    local startIndex, endIndex, isNotTitle

    if(CURRENCYSEARCH_SETTINGS.includeDescriptions) then
        startIndex, endIndex = string.find(string.lower(description), boxText)

        if(startIndex) then
            isNotTitle = true
        end
    end

    return startIndex, endIndex, isNotTitle
end

local function loadCurrencySearch()
    if(TokenFrame) then
        local setting = Settings.RegisterAddOnSetting(category, "CURRENCYSEARCH_IncludeDescriptions", "includeDescriptions", CURRENCYSEARCH_SETTINGS, "boolean", "Include descriptions", false)
        Settings.CreateCheckbox(category, setting, "Include/exclude faction description searching (may lag on lower end machines).")
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
        searchBox:SetPoint("BOTTOMRIGHT", TokenFrame.filterDropdown, "BOTTOMLEFT", -5, 0)
        searchBox:SetPoint("BOTTOMLEFT", CharacterFramePortrait, "BOTTOMRIGHT", 5, 0)
        searchBox:SetScript("OnTextChanged", function(self)
            SearchBoxTemplate_OnTextChanged(self)
    
            TokenFrame:Update()
    
        end)
    
        TokenFrame.Update = function()
            --TokenFrame.ScrollBox:Flush()
    
            local boxText = searchBox:GetText() or ""
            local lowerBoxText = string.lower(boxText)
            local isNotTitle
            local lastUpper, lastMiddle
            local allMiddleAllowed, allLowsAllowed
            
            local numTokenTypes = C_CurrencyInfo.GetCurrencyListSize();
            CharacterFrameTab3:SetShown(numTokenTypes > 0);

            local currencyDataReady = not C_CurrencyInfo.DoesCurrentFilterRequireAccountCurrencyData() or C_CurrencyInfo.IsAccountCharacterCurrencyDataReady();
            TokenFrame:SetLoadingSpinnerShown(not currencyDataReady);
            if not currencyDataReady then
                return;
            end

            currencyList = {};

            for currencyIndex = 1, numTokenTypes do
                isNotTitle = false
                local currencyData = C_CurrencyInfo.GetCurrencyListInfo(currencyIndex);
                
                if(currencyData) then
                    if(currencyData.isHeader) then
                        C_CurrencyInfo.ExpandCurrencyList(currencyIndex, true)

                    end

                    local startIndex, endIndex = string.find(strlower(currencyData.name), lowerBoxText)

                    if(not startIndex) then
                        startIndex, endIndex, isNotTitle = checkForDescription(currencyData.description, lowerBoxText)

                    end

                    local isUpper = currencyData.isHeader and currencyData.currencyListDepth == 0
                    local isMiddle = currencyData.isHeader and currencyData.currencyListDepth > 0
                    local isChild = not currencyData.isHeader and currencyData.currencyListDepth > 0

                    if(isUpper) then
                        lastUpper = {currencyIndex = currencyIndex, name = currencyData.name}
                        lastMiddle = nil
                        allMiddleAllowed = false
                        allLowsAllowed = false
                        
                    elseif(isMiddle) then
                        lastMiddle = {currencyIndex = currencyIndex, name = currencyData.name}
                        allLowsAllowed = false
    
                    end


                    if(startIndex or allMiddleAllowed or allLowsAllowed) then
                        if(boxText ~= "") then
                            if(currencyData.isHeader == false and currencyData.currencyListDepth == 0) then
                                if(not isNameInList(lastUpper.name)) then
                                    addDataWithIndexToList(C_CurrencyInfo.GetCurrencyListInfo(lastUpper.currencyIndex), lastUpper.currencyIndex)
    
                                end
                            elseif(isChild) then
                                if(lastUpper and not isNameInList(lastUpper.name)) then
                                    addDataWithIndexToList(C_CurrencyInfo.GetCurrencyListInfo(lastUpper.currencyIndex), lastUpper.currencyIndex)
    
                                end
    
                                if(lastMiddle and not isNameInList(lastMiddle.name)) then
                                    addDataWithIndexToList(C_CurrencyInfo.GetCurrencyListInfo(lastMiddle.currencyIndex), lastMiddle.currencyIndex)
    
                                end
                            elseif(isMiddle) then
                                allLowsAllowed = true
    
                                if(lastUpper and not isNameInList(lastUpper.name)) then
                                    addDataWithIndexToList(C_CurrencyInfo.GetCurrencyListInfo(lastUpper.currencyIndex), lastUpper.currencyIndex)
    
                                end
                            elseif(isUpper) then
                                allMiddleAllowed = true
    
                            end
    
                        end
    
                        if(startIndex) then
                            if(not isNotTitle) then
                                currencyData.name = string.sub(currencyData.name, 0, startIndex - 1) .. wticc(string.sub(currencyData.name, startIndex, endIndex), "FF2ECC40") .. string.sub(currencyData.name, endIndex + 1)
                                
                            --else
                                --factionData.description = string.sub(factionData.description, 0, startIndex - 1) .. wticc(string.sub(factionData.description, startIndex, endIndex), "FF2ECC40") .. string.sub(factionData.description, endIndex + 1)
    
                            end
    
                        end
    
                        firstActualIndex = currencyData.currencyID > 0 and currencyIndex or firstActualIndex
                        
                        addDataWithIndexToList(currencyData, currencyIndex)
                    end
                    
                end
            end

            TokenFrame.ScrollBox:SetDataProvider(CreateDataProvider(currencyList), ScrollBoxConstants.RetainScrollPosition);

            -- If we're updating the currency list while the "Options" popup is open then we should refresh it as well
            if TokenFrame.selectedID and TokenFrame.Popup:IsShown() then
                local function FindSelectedTokenButton(button, elementData)
                    return elementData.currencyIndex == TokenFrame.selectedID;
                end

                local selectedEntry = TokenFrame.ScrollBox:FindFrameByPredicate(FindSelectedTokenButton);
                if selectedEntry then
                    TokenFrame:UpdatePopup(selectedEntry);
                end
            end
            TokenFrame.ScrollBox:RegisterCallback(ScrollBoxListMixin.Event.OnDataRangeChanged, GenerateClosure(TokenFrame.RefreshAccountTransferableCurrenciesTutorial), TokenFrame);
        end

        --TokenFrame:SetTokenWatched(firstActualIndex, backpack)
    end
end



local function events(_, event, ...)
    if(event == "PLAYER_ENTERING_WORLD") then
        if(TokenFrame and not _G["CurrencySearch_SettingsButton"]) then
            loadCurrencySearch()
        end
    else

    end
end

eventReceiver:SetScript("OnEvent", events)

function CURRENCYSEARCH_OpenInterfaceOptions()
    Settings.OpenToCategory(category:GetID())
end