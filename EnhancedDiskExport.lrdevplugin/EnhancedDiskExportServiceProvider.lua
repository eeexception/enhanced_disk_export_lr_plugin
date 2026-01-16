-- Import the UI and task modules
require "EnhancedDiskExportDialogSections"
require "EnhancedDiskExportExecutor"

-- Define the service provider return table
return {
    allowFileFormats = nil,   -- nil means allow all available formats
    allowColorSpaces = nil,   -- nil means allow all available color spaces

    exportPresetFields = {
        { key = "enhancedExportFolder", default = "" },  -- Folder field (user selects)
        { key = "enhancedSubfolder", default = "{{catalog}}/" },  -- Subfolder template
        { key = "fullPath", default = "" },
        { key = "existingFilesAction", default = "ask" },
        { key = "enhancedPostProcessingAction", default = "doNothing" },
        { key = "enhancedPostProcessingApplication", default = "" },
        { key = "enhancedPostProcessingScript", default = "" },
    },

    hideSections = { "exportLocation" }, 

    showSections = {
        "fileNaming",          -- File Naming
        "video",               -- Video
        "fileSettings",        -- File Settings
        "contentCredentials",  -- Content Credentials
        "imageSettings",       -- Image Sizing
        "outputSharpening",    -- Output Sharpening
        "metadata",            -- Metadata
        "watermarking",        -- Watermarking
    },

    -- Hook into the dialog lifecycle
    startDialog = EnhancedDiskExportDialogSections.startDialog,

    -- Register the UI panel at the top (Enhanced Export Location)
    sectionsForTopOfDialog = EnhancedDiskExportDialogSections.sectionsForTopOfDialog,
    sectionsForBottomOfDialog = EnhancedDiskExportDialogSections.sectionsForBottomOfDialog,

    -- The function responsible for processing and exporting files
    processRenderedPhotos = EnhancedDiskExportExecutor.processRenderedPhotos,
}
