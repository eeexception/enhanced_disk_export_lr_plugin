-- Lightroom SDK Imports
local LrView        = import "LrView"
local LrDialogs     = import "LrDialogs"
local bind          = LrView.bind
local share         = LrView.share
local LrApplication = import "LrApplication"
local LrPathUtils   = import "LrPathUtils"
local LrFileUtils   = import "LrFileUtils"
local LrProgressScope = import "LrProgressScope"
local LrShell =       import "LrShell"
local LrTasks =       import "LrTasks"
local Utils = require "EnhancedDiskExportUtils"

--==============================================================================
-- EnhancedDiskExportDialogSections
--==============================================================================

EnhancedDiskExportDialogSections = {}

-------------------------------------------------------------------------------
-- Function: updateExportStatus
-- Updates the UI field when the folder or subfolder template changes
-------------------------------------------------------------------------------
local function updateExportStatus(propertyTable)
    local message = nil

    if not propertyTable.enhancedExportFolder or propertyTable.enhancedExportFolder == "" then
        message = "Select an export folder"
    elseif not propertyTable.enhancedSubfolder or propertyTable.enhancedSubfolder == "" then
        message = "Enter a subfolder template"
    else
        -- Compute the full export path
        local previewPath = LrPathUtils.child(propertyTable.enhancedExportFolder, propertyTable.enhancedSubfolder)
        propertyTable.fullPath = previewPath
    end

    if message then
        propertyTable.message = message
        propertyTable.hasError = true
        propertyTable.hasNoError = false
        propertyTable.LR_cantExportBecause = message
    else
        propertyTable.message = nil
        propertyTable.hasError = false
        propertyTable.hasNoError = true
        propertyTable.LR_cantExportBecause = nil
    end
end

-------------------------------------------------------------------------------
-- Function: startDialog
-- Adds observers to update the UI dynamically
-------------------------------------------------------------------------------
function EnhancedDiskExportDialogSections.startDialog(propertyTable)
    if not propertyTable.selectedToken then
        propertyTable.selectedToken = Utils.TokenEnum.CATALOG_NAME.token
    end
    if not propertyTable.existingFilesAction then
        propertyTable.existingFilesAction = "ask"  
    end
    propertyTable:addObserver("enhancedExportFolder", updateExportStatus)
    propertyTable:addObserver("enhancedSubfolder", updateExportStatus)
    propertyTable:addObserver("existingFilesAction", updateExportStatus)
    propertyTable:addObserver("enhancedPostProcessingAction", updateExportStatus) 

    updateExportStatus(propertyTable)
end

-------------------------------------------------------------------------------
-- Function: sectionsForTopOfDialog
-- Creates the UI panel for Enhanced Export Location
-------------------------------------------------------------------------------
function EnhancedDiskExportDialogSections.sectionsForTopOfDialog(_, propertyTable)
    local f = LrView.osFactory()

    local result = {
        {
            title = LOC "$$$/EnhancedDiskExport/ExportDialog/EnhancedSettings=Enhanced Export Location",
            
            synopsis = bind { key = "fullPath", object = propertyTable },

            -- Row 1: Export Folder Selection (File Input)
            f:row {
                f:static_text {
                    title = LOC "$$$/EnhancedDiskExport/ExportDialog/EnhancedExportFolder=Export Folder:",
                    alignment = "right",
                    width = share "labelWidth",
                },

                f:edit_field {
                    value = bind "enhancedExportFolder",
                    width_in_chars = 35,
                    fill_horizontal = 1,
                },

                f:push_button {
                    title = LOC "$$$/EnhancedDiskExport/ExportDialog/ChooseFolder=Choose...",
                    action = function()
                        local result = LrDialogs.runOpenPanel({
                            title = LOC "$$$/EnhancedDiskExport/ExportDialog/SelectExportFolder=Select Export Folder",
                            canChooseFiles = false,
                            canChooseDirectories = true,
                            allowsMultipleSelection = false,
                        })

                        if result and #result > 0 then
                            propertyTable.enhancedExportFolder = result[1]
                        end
                    end
                },
            },

            -- Row 2: Subfolder input field
            f:row {
                f:static_text {
                    title = LOC "$$$/EnhancedDiskExport/ExportDialog/EnhancedSubfolder=Enhanced Subfolder:",
                    alignment = "right",
                    width = share "labelWidth",
                },

                f:edit_field {
                    value = bind "enhancedSubfolder",
                    width_in_chars = 30,
                    fill_horizontal = 1,
                },
            },

            -- New Row 3: Dropdown for tokens and Insert button
            f:row {
                f:static_text {
                    title = LOC "$$$/EnhancedDiskExport/ExportDialog/InsertTokenLabel=Insert Token:",
                    alignment = "right",
                    width = share "labelWidth",
                },
                f:popup_menu {
                    value = bind "selectedToken",
                    width = 200,
                    items = (function()
                        local items = {}
                        for key, entry in pairs(Utils.TokenEnum) do
                            table.insert(items, {
                                title = "{{" .. entry.token .. "}}",
                                value = entry.token,
                                tooltip = entry.description,  -- If tooltips are supported
                            })
                        end
                        return items
                    end)(),
                },
                f:push_button {
                    title = LOC "$$$/EnhancedDiskExport/ExportDialog/InsertToken=Insert",
                    action = function()
                        local current = propertyTable.enhancedSubfolder or ""
                        local tokenValue = propertyTable.selectedToken or ""
                        if tokenValue ~= "" then
                            local tokenText = "{{" .. tokenValue .. "}}"
                            -- Append with a separator if needed:
                            propertyTable.enhancedSubfolder = current .. tokenText
                        end
                    end,
                },
            },

            -- New Row: "Existing files" dropdown
            f:row {
                f:static_text {
                    title = LOC "$$$/EnhancedDiskExport/ExportDialog/ExistingFiles=Existing Files:",
                    alignment = "right",
                    width = share "labelWidth",
                },
                f:popup_menu {
                    value = bind "existingFilesAction",
                    width = 200,
                    items = {
                        { title = LOC "$$$/EnhancedDiskExport/ExportDialog/Ask=Ask what to do", value = "ask" },
                        { title = LOC "$$$/EnhancedDiskExport/ExportDialog/NewName=Choose a new name for the exported file", value = "rename" },
                        { title = LOC "$$$/EnhancedDiskExport/ExportDialog/Overwrite=Overwrite WITHOUT WARNING", value = "overwrite" },
                        { title = LOC "$$$/EnhancedDiskExport/ExportDialog/Skip=Skip", value = "skip" },
                    },
                },
            },

            -- Column: Resolved Path + Error Message
            f:column {
                place = "overlapping",
                fill_horizontal = 1,

                -- Resolved path row
                f:row {
                    f:static_text {
                        title = LOC "$$$/EnhancedDiskExport/ExportDialog/ResolvedPath=Resolved Path:",
                        alignment = "right",
                        width = share "labelWidth",
                        visible = bind "hasNoError",
                    },

                    f:static_text {
                        title = bind "fullPath",
                        fill_horizontal = 1,
                        width_in_chars = 40,
                        visible = bind "hasNoError",
                    },
                },

                -- Error message row
                f:row {
                    f:static_text {
                        fill_horizontal = 1,
                        title = bind "message",
                        visible = bind "hasError",
                        text_color = LrView.text_color_error,
                    },
                },
            },
        }
    }

    return result
end

function EnhancedDiskExportDialogSections.sectionsForBottomOfDialog(_, propertyTable)
    local f = LrView.osFactory()

    local result = {
        {
            title = LOC "$$$/EnhancedDiskExport/ExportDialog/EnhancedPostProcessing=Enhanced Post-Processing",
    
            synopsis = bind { key = "enhancedPostProcessingAction", object = propertyTable },
    
            -- Row 1: Post-processing action dropdown
            f:row {
                f:static_text {
                    title = LOC "$$$/EnhancedDiskExport/ExportDialog/AfterExport=After Export:",
                    alignment = "right",
                    width = share "labelWidth",
                },
    
                f:popup_menu {
                    value = bind "enhancedPostProcessingAction",
                    width = 200,
                    items = {
                        { title = LOC "$$$/EnhancedDiskExport/ExportDialog/DoNothing=Do Nothing", value = "doNothing" },
                        { title = LOC "$$$/EnhancedDiskExport/ExportDialog/OpenFolder=Open in Finder/Explorer", value = "openFolder" },
                        { title = LOC "$$$/EnhancedDiskExport/ExportDialog/OpenApplication=Open in Application", value = "openApplication" },
                        { title = LOC "$$$/EnhancedDiskExport/ExportDialog/RunScript=Run External Script", value = "runScript" },
                    },
                },
            },
    
            -- Row 2: External script selection (only when "runScript" is selected)
            f:row {
                f:static_text {
                    title = LOC "$$$/EnhancedDiskExport/ExportDialog/ScriptPath=Script Path:",
                    alignment = "right",
                    width = share "labelWidth",
                    visible = bind { key = "enhancedPostProcessingAction", transform = function(value) return value == "runScript" end },
                },
                f:edit_field {
                    value = bind "enhancedPostProcessingScript",
                    width_in_chars = 35,
                    fill_horizontal = 1,
                    visible = bind { key = "enhancedPostProcessingAction", transform = function(value) return value == "runScript" end },
                },
                f:push_button {
                    title = LOC "$$$/EnhancedDiskExport/ExportDialog/ChooseScript=Choose...",
                    visible = bind { key = "enhancedPostProcessingAction", transform = function(value) return value == "runScript" end },
                    action = function()
                        local result = LrDialogs.runOpenPanel({
                            title = LOC "$$$/EnhancedDiskExport/ExportDialog/SelectScript=Select Script File",
                            canChooseFiles = true,
                            canChooseDirectories = false,
                            allowsMultipleSelection = false,
                        })
                        if result and #result > 0 then
                            propertyTable.enhancedPostProcessingScript = result[1]
                        end
                    end,
                },
            },
    
            -- New Row: Application selection (only when "openApplication" is selected)
            f:row {
                f:static_text {
                    title = LOC "$$$/EnhancedDiskExport/ExportDialog/ApplicationPath=Application Path:",
                    alignment = "right",
                    width = share "labelWidth",
                    visible = bind { key = "enhancedPostProcessingAction", transform = function(value) return value == "openApplication" end },
                },
                f:edit_field {
                    value = bind "enhancedPostProcessingApplication",
                    width_in_chars = 35,
                    fill_horizontal = 1,
                    visible = bind { key = "enhancedPostProcessingAction", transform = function(value) return value == "openApplication" end },
                },
                f:push_button {
                    title = LOC "$$$/EnhancedDiskExport/ExportDialog/ChooseApplication=Choose...",
                    visible = bind { key = "enhancedPostProcessingAction", transform = function(value) return value == "openApplication" end },
                    action = function()
                        local result = LrDialogs.runOpenPanel({
                            title = LOC "$$$/EnhancedDiskExport/ExportDialog/SelectApplication=Select Application",
                            canChooseFiles = true,
                            canChooseDirectories = false,
                            allowsMultipleSelection = false,
                        })
                        if result and #result > 0 then
                            propertyTable.enhancedPostProcessingApplication = result[1]
                        end
                    end,
                },
            },
        }
    }
    
    return result
end

