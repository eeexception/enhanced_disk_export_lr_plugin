#!/bin/sh
# compile.sh

# 1. Delete any existing EnhancedDiskExport.lrplugin folder
if [ -d "EnhancedDiskExport.lrplugin" ]; then
    echo "Removing existing EnhancedDiskExport.lrplugin..."
    rm -rf "EnhancedDiskExport.lrplugin"
fi

# 2. Create an empty EnhancedDiskExport.lrplugin folder
echo "Creating EnhancedDiskExport.lrplugin folder..."
mkdir "EnhancedDiskExport.lrplugin"

# 3. Compile each Lua file from EnhancedDiskExport.lrdevplugin into EnhancedDiskExport.lrplugin,
#    outputting the compiled code as .lua files.
echo "Compiling Lua files..."
for file in EnhancedDiskExport.lrdevplugin/*.lua; do
    base=$(basename "$file" .lua)
    echo "Compiling $file -> EnhancedDiskExport.lrplugin/${base}.lua"
    ./luac -o "EnhancedDiskExport.lrplugin/${base}.lua" "$file"
done

echo "Compilation complete."
