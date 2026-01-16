-- Utils.lua
local LrApplication = import "LrApplication"
local LrPathUtils = import "LrPathUtils"
local LrDialogs     = import "LrDialogs"

local EnhancedDiskExportUtils = {}

-------------------------------------------------------------------------------
-- 📌 Forward Declarations (Tell Lua these functions exist)
-------------------------------------------------------------------------------
local getCatalogName
local removeExtension
local getPhotoOrientation
local getImageTimestamp
local getFolderName

local TokenEnum = {
    CATALOG_NAME = { token = "catalog name", description = "The name of the current catalog" },
    CATALOG      = { token = "catalog",      description = "The name of the current catalog" },
    DATE         = { token = "date",         description = "Today's date in YYYYMMDD format" },
    YYYY         = { token = "yyyy",         description = "Current year (4 digits)" },
    MM           = { token = "mm",           description = "Current month (2 digits)" },
    DD           = { token = "dd",           description = "Current day (2 digits)" },
    IMAGE_DATE   = { token = "image date",   description = "Image capture date in YYYYMMDD format" },
    IMAGE_YYYY   = { token = "image yyyy",   description = "Image capture year (4 digits)" },
    IMAGE_MM     = { token = "image mm",     description = "Image capture month (2 digits)" },
    IMAGE_DD     = { token = "image dd",     description = "Image capture day (2 digits)" },
    ORIENTATION  = { token = "orientation",  description = "Image orientation (Portrait, Landscape, or Square)" },
    FOLDER       = { token = "folder",       description = "Name of the folder where the photo is located" },
    RATING       = { token = "rating",       description = "The rating of the photo" },
    COLOR        = { token = "color",        description = "The color label of the photo" },
}

-------------------------------------------------------------------------------
-- 📌 Define `getTokenMap()` FIRST (Lazy Initialization)
-------------------------------------------------------------------------------
local function getTokenMap(photo)
    local tokenMap = 
    {
        [TokenEnum["CATALOG_NAME"].token] = getCatalogName(), 
        [TokenEnum["CATALOG"].token] = getCatalogName(), 
        [TokenEnum["DATE"].token] = os.date("%Y%m%d"),      
        [TokenEnum["YYYY"].token] = os.date("%Y"),
        [TokenEnum["MM"].token] = os.date("%m"),
        [TokenEnum["DD"].token] = os.date("%d"),
    }

    if photo then
        local imageTime = getImageTimestamp(photo) or os.time()
        tokenMap[TokenEnum["IMAGE_DATE"].token] = os.date("%Y%m%d", imageTime)
        tokenMap[TokenEnum["IMAGE_YYYY"].token] = os.date("%Y", imageTime)
        tokenMap[TokenEnum["IMAGE_MM"].token]   = os.date("%m", imageTime)
        tokenMap[TokenEnum["IMAGE_DD"].token]   = os.date("%d", imageTime)

        tokenMap[TokenEnum["ORIENTATION"].token] = getPhotoOrientation(photo)

        tokenMap[TokenEnum["FOLDER"].token] = getFolderName(photo)

        tokenMap[TokenEnum["RATING"].token] = tostring(photo:getRawMetadata("rating") or 0)

        tokenMap[TokenEnum["COLOR"].token] = photo:getFormattedMetadata("label") or "nocolor"
    end

    return tokenMap
end

function getFolderName(photo)
    local filePath = photo:getRawMetadata("path")
    if filePath then
        local parentPath = LrPathUtils.parent(filePath)
        if parentPath then
            return LrPathUtils.leafName(parentPath)
        end
    end
    return "{{folder}}"
end

--------------------------------------------------------------------------------
-- Function: getImageTimestamp
-- Parses the image's capture date from the "dateTimeOriginal" metadata.
-- Accepts Lightroom's typical "YYYY:MM:DD HH:MM:SS" as well as ISO-like "YYYY-MM-DD".
--------------------------------------------------------------------------------
function getImageTimestamp(photo)
    local dateStr = photo:getFormattedMetadata("dateTimeOriginal")
    if dateStr then
        dateStr = tostring(dateStr)
        -- Normalize whitespace by collapsing any sequence of whitespace into a single space and trimming.
        dateStr = dateStr:gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")
        -- Use a simple pattern to capture the first three components: Year, Month, and Day.
        local year, month, day = dateStr:match("^(%d%d%d%d)[:%-](%d%d)[:%-](%d%d)")
        if year and month and day then
            return os.time({
                year  = tonumber(year),
                month = tonumber(month),
                day   = tonumber(day),
                hour  = 0,
                min   = 0,
                sec   = 0,
            })
        end
    end
    return nil
end

-------------------------------------------------------------------------------
-- Function: removeExtension
-- Helper function to remove file extensions (like .lrcat)
-------------------------------------------------------------------------------
function removeExtension(filename)
    local dotIndex = filename:match("^.*()%.")
    if dotIndex then
        return filename:sub(1, dotIndex - 1)
    else
        return filename
    end
end

-------------------------------------------------------------------------------
-- Function: getCatalogName
-- Extracts the catalog name from Lightroom's active catalog
-------------------------------------------------------------------------------
function getCatalogName()
    local catalog = LrApplication.activeCatalog()
    local catalogFullPath = catalog:getPath()
    local catalogFileName = LrPathUtils.leafName(catalogFullPath)
    return removeExtension(catalogFileName)
end

function getPhotoOrientation(photo)
    -- Attempt to get the dimensions from the formatted metadata "dimensions"
    local dims = photo:getFormattedMetadata("dimensions")
    if not dims then
        return "Unknown"
    end

    -- dims is expected to be in the format "6240 x 4160"
    local width, height = dims:match("(%d+)%s*x%s*(%d+)")
    width = tonumber(width)
    height = tonumber(height)

    if not width or not height then
        return "Unknown"
    end

    -- Retrieve cropping settings from the Develop module
    local developSettings = photo:getDevelopSettings()
    local cropLeft = developSettings["CropLeft"] or 0
    local cropTop = developSettings["CropTop"] or 0
    local cropRight = developSettings["CropRight"] or 1
    local cropBottom = developSettings["CropBottom"] or 1

    -- Compute the final cropped dimensions based on the formatted dimensions
    local croppedWidth = width * (cropRight - cropLeft)
    local croppedHeight = height * (cropBottom - cropTop)

    -- Determine final orientation based on the cropped dimensions
    if croppedHeight > croppedWidth then
        return "Portrait"
    elseif croppedHeight < croppedWidth then
        return "Landscape"
    else
        return "Square"
    end
end


-------------------------------------------------------------------------------
-- Function: replaceTokens
-- Replaces all `{{MASK}}` placeholders dynamically (case-insensitive)
-------------------------------------------------------------------------------
function EnhancedDiskExportUtils.replaceTokens(path, photo)
    local tokenMap = getTokenMap(photo)
    
    -- ✅ Replace all occurrences of {{MASK}} dynamically
    local replacedPath = path:gsub("{{(.-)}}", function(mask)
        local cleanedMask = mask:lower():gsub("^%s*(.-)%s*$", "%1")  -- Convert to lowercase and trim spaces
        return tokenMap[cleanedMask] or "{{" .. mask .. "}}"  -- Keep unknown placeholders unchanged
    end)

    return replacedPath
end

EnhancedDiskExportUtils.TokenEnum = TokenEnum

-- ✅ Return the Utils table so other files can import it
return EnhancedDiskExportUtils
