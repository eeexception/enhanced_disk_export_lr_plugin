local LrDialogs     = import "LrDialogs"
local LrPathUtils   = import "LrPathUtils"
local LrFileUtils   = import "LrFileUtils"
local LrProgressScope = import "LrProgressScope"
local LrShell =       import "LrShell"
local LrTasks =       import "LrTasks"
local Utils = require "EnhancedDiskExportUtils"

EnhancedDiskExportExecutor = {}

-------------------------------------------------------------------------------
-- Function: processRenderedPhotos
-- Applies the enhanced subfolder logic during export
-------------------------------------------------------------------------------
function EnhancedDiskExportExecutor.processRenderedPhotos(functionContext, exportContext)
    local exportSession = exportContext.exportSession
    local props = exportContext.propertyTable
    local subfolderPattern = props.enhancedSubfolder or ""
    local baseExportFolder = props.enhancedExportFolder
    local enhancedPostProcessingAction = props.enhancedPostProcessingAction

    -- ✅ Ensure export folder is selected
    if not baseExportFolder or baseExportFolder == "" then
        LrDialogs.message("Error", "No export folder selected!", "critical")
        return
    end

    -- ✅ Create a progress bar
    local progressScope = LrProgressScope({
        title = "Exporting Photos...",
    })

    -- ✅ Get total renditions count
    local totalPhotos = exportSession:countRenditions()
    local completedPhotos = 0

    local uniqueFolders = {}
    local exportedImages = {}

    -- ✅ Iterate over all images to process them
    for _, rendition in exportSession:renditions() do
        local skipThisFile = false

        -- ✅ Check if the user canceled the export
        if progressScope:isCanceled() then
            break
        end

        local success, tmpFile = rendition:waitForRender()
        if success then
            -- Build the final output path
            local photo = rendition.photo
            local replacedSubfolder = Utils.replaceTokens(subfolderPattern, photo)
            local finalFolder = LrPathUtils.child(baseExportFolder, replacedSubfolder)

            -- Create the directory if it doesn’t exist
            LrFileUtils.createAllDirectories(finalFolder)

            uniqueFolders[finalFolder] = true

            -- Handle existing file behavior
            local fileName = LrPathUtils.leafName(tmpFile)
            local finalPath = LrPathUtils.child(finalFolder, fileName)

            if LrFileUtils.exists(finalPath) then
                if props.existingFilesAction == "ask" then
                    local choice = LrDialogs.confirm(
                        "File already exists: " .. fileName,
                        "What would you like to do?",
                        "Choose a new name",
                        "Overwrite",
                        "Skip"
                    )
                    if choice == "ok" then
                        -- Generate a new unique name
                        local base, ext = fileName:match("(.+)%.(%w+)$")
                        local counter = 1
                        repeat
                            counter = counter + 1
                            finalPath = LrPathUtils.child(finalFolder, base .. "_" .. counter .. "." .. ext)
                        until not LrFileUtils.exists(finalPath)
                    elseif choice == "other" then
                        -- User selected Overwrite
                        LrFileUtils.delete(finalPath)
                    elseif choice == "cancel" then
                        skipThisFile = true
                    end
                elseif props.existingFilesAction == "rename" then
                    -- Auto-generate a unique filename
                    local base, ext = fileName:match("(.+)%.(%w+)$")
                    local counter = 1
                    repeat
                        counter = counter + 1
                        finalPath = LrPathUtils.child(finalFolder, base .. "_" .. counter .. "." .. ext)
                    until not LrFileUtils.exists(finalPath)
                elseif props.existingFilesAction == "skip" then
                    skipThisFile = true  -- Skip this file
                elseif props.existingFilesAction == "overwrite" then
                    -- Overwrite without warning
                    LrFileUtils.delete(finalPath)
                end
            end

            if not skipThisFile then
                -- Move the rendered file
                LrFileUtils.move(tmpFile, finalPath)


                if props.enhancedPostProcessingAction == "openApplication" then
                    -- Open a user-selected application
                    local appPath = props.enhancedPostProcessingApplication
                    if not appPath or appPath == "" then
                        LrDialogs.message("Error", "No application selected.", "critical")
                    else
                        local command
                        if WIN_ENV then
                            -- Windows: Use 'start' with an empty title
                            command = 'start "" "' .. appPath .. '" "' .. finalPath .. '"'
                        else
                            -- macOS: Use 'open -a' to open an application with a file argument
                            command = 'open -a "' .. appPath .. '" "' .. finalPath .. '"'
                        end
                        LrTasks.execute(command)
                    end
            
                elseif props.enhancedPostProcessingAction == "runScript" then
                    -- Run an external script (execute the file directly on both platforms)
                    local scriptPath = props.enhancedPostProcessingScript
                    if not scriptPath or scriptPath == "" then
                        LrDialogs.message("Error", "No script selected.", "critical")
                    else
                        local command
                        local lowerPath = scriptPath:lower()
                        if WIN_ENV and (lowerPath:match("%.bat$") or lowerPath:match("%.cmd$")) then
                            command = 'cmd /c ""' .. scriptPath .. '" "' .. finalPath .. '""'
                        else
                            command = '"' .. scriptPath .. '" "' .. finalPath .. '"'
                        end
                        LrTasks.execute(command)
                    end
                end
            end
        end

        -- ✅ Update progress
        completedPhotos = completedPhotos + 1
        progressScope:setPortionComplete(completedPhotos, totalPhotos)
    end

    -- ✅ Mark progress as completed
    progressScope:done()

    -- At the end of processRenderedPhotos, after processing all images:
    if props.enhancedPostProcessingAction == "openFolder" then
        for folderPath, _ in pairs(uniqueFolders) do
            if folderPath and folderPath ~= "" then
                if LrShell and LrShell.openPaths then
                    LrShell.openPaths({ folderPath })
                else
                    local openCommand
                    if WIN_ENV then
                        openCommand = 'explorer "' .. folderPath .. '"'
                    else
                        openCommand = 'open "' .. folderPath .. '"'
                    end
                    LrTasks.execute(openCommand)
                end
            else
                LrDialogs.message("Error", "No export folder to open.", "critical")
            end
        end
    end

end
