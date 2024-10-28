## -- This script handles two things
# -- Removal of binds to co-driver configs (forces use of default RBR.ini)
# -- Adds 2D/3D Pacenotes & fixes broken flag IDs.

## -- To use it, you are going to need to handle two things
# -- In $pacenotes_map table, match pacenote ID's (from your codrivers config), to names of flags, which are specified in $flag_map.
# -- How the flags look, can be viewed in .\RBR\Generic\PC_1024_01.dds
# -- In $pacenotesDirectory & $outputFilePath, set the MyPacenotes directory with your pacenotes & where you want to put the exports.

# Ensure the ini module is installed
try {
    #Import-Module PsIni
    Import-Module -Name 'E:\Git\Personal\PsIni\PSIni\PsIni.psd1' -Force
}
catch {
    Install-Module -Scope CurrentUser PsIni
    Import-Module PsIni
}

# Path to the input & output directories
$pacenotesDirectory = "SOURCE_DIRECTORY"
$outputFilePath = "TARGET_DIRECTORY"

# Get list of all stages directories
$stages = Get-ChildItem -Path $pacenotesDirectory -Directory

# Mapping of my pacenote id's to flags
$pacenotes_map = @{
0 = "HAIRPINLEFT"; #LEFT_HAIRPIN
1 = "90_LEFT"; #LEFT_1
2 = "KLEFT"; #LEFT_2
3 = "MEDIUMLEFT"; #LEFT_3
4 = "FASTLEFT"; #LEFT_4
5 = "EASYLEFT"; #LEFT_5
6 = "EASYRIGHT"; #RIGHT_5
7 = "FASTRIGHT"; #RIGHT_4
8 = "MEDIUMRIGHT"; #RIGHT_3
9 = "KRIGHT"; #RIGHT_2
10 = "90_RIGHT"; #RIGHT_1
11 = "HAIRPINRIGHT"; #RIGHT_HAIRPIN
100 = "EASYLEFT"; #LEFT # TODO: Check if the image fits
101 = "FLATLEFT"; #LEFT_6
102 = "90_LEFT"; #LEFT_SQUARE
103 = "EASYLEFT"; #LEFT_INTO
# 104 = ; #LEFT_RIGHT # TODO: Make it twisty
105 = "HAIRPINLEFT"; #LEFT_ACUTE
106 = "HAIRPINLEFT"; #LEFT_AROUND
107 = "HAIRPINLEFT"; #LEFT_DONUT
108 = "FASTLEFT"; #LEFT_SHORT
109 = "FASTLEFT"; #LEFT_OVER
# 110 = ; #CHICANE_LEFT_ENTRY # TODO: Make it twisty

112 = "EASYRIGHT"; #RIGHT # TODO: Check if the image fits
113 = "FLATRIGHT"; #RIGHT_6
114 = "90_RIGHT"; #RIGHT_SQUARE
115 = "EASYRIGHT"; #RIGHT_INTO
# 116 = ; #RIGHT_LEFT # TODO: Make it twisty
117 = "HAIRPINRIGHT"; #RIGHT_ACUTE
118 = "HAIRPINLEFT"; #RIGHT_AROUND
119 = "HAIRPINLEFT"; #RIGHT_DONUT
120 = "FASTRIGHT"; #RIGHT_SHORT
121 = "FASTLEFT"; #RIGHT_OVER
# 122 = ; #CHICANE_RIGHT_ENTRY # TODO: Make it twisty

}

# Mapping of corner names to original ID's
$flags_map = @{
    "HAIRPINLEFT" = 0;
    "90_LEFT" = 1;
    "KLEFT" = 2;
    "MEDIUMLEFT" = 3;
    "FASTLEFT" = 4;
    "EASYLEFT" = 5;
    "FLATLEFT" = 26;

    "HAIRPINRIGHT" = 11
    "90_RIGHT" = 10;
    "KRIGHT" = 9;
    "MEDIUMRIGHT" = 8;
    "FASTRIGHT" = 7;
    "EASYRIGHT" = 6;
    "FLATRIGHT" = 25;

    # "CAUTION" = ??;
    # "WATER" = ??;
    # "TIGHTENS" = ??;
    # "WIDENS" = ??;
    # "BRIDGE" = ??;
    # "BUMP" = ??;
    # "TWISTY" = ??;
}

# Iterate over all stages directories
foreach ($stage in $stages) {
    # Get list of pacenote files for each stage
    $pacenotes = Get-ChildItem -Path $stage.FullName -File

    # Iterate over individual pacenote files
    foreach ($pacenote in $pacenotes) {
        if (Test-Path ($outputFilePath + "/" + $stage.Name + "/" + $pacenote.Name)) {
            continue
        }
        # Load contents of the original INI file
        $iniData = [ordered] @{}
        $iniData = Import-Ini $pacenote.FullName

        # Prepare structures for new INI file
        if ($iniData.Contains("PACENOTES")) {
            $filteredData = [ordered] @{
                _ = [ordered]@{
                    Comment1 = ($pacenote.Name + " pacenotes file generated for CoPilot mods compatible with FilipekMod.")
                    Comment2 = ("For more details, please visit https://amun.pl/blog")
                }
                PACENOTES = $iniData["PACENOTES"]
            }
        } else {
            $filteredData = [ordered] @{
                _ = [ordered]@{
                    Comment1 = ($pacenote.Name + " pacenotes file generated for CoPilot mods compatible with FilipekMod.")
                    Comment2 = ("For more details, please visit https://amun.pl/blog")
                }
                PACENOTES = [ordered] @{
                    count = "0"
                }
            }
        }

        $pCounter = 0

        $iniData.Remove("PACENOTES")
        $iniData.Remove("_")

        foreach ($section in $iniData.Keys) {
            # Remove entries with type > 5000
            if ([int64]$iniData[$section].type -gt 5000) {
                continue
            }
            else {
                $filteredData["P$pCounter"] = $iniData[$section]
                if ($pacenotes_map.ContainsKey([int32]$filteredData["P$pCounter"].type)) {
                    $note_id = $flags_map[ # Get the flag ID from flags_map
                        $pacenotes_map[ # Get the og Pacenote name from pacenotes_map
                           [int32]$filteredData["P$pCounter"].type # Get the pacenote ID
                        ]
                    ]
                    # Set the flag to Pacenote_id bitwise shifted left + 0b100000000000000 + ignore flag at 8th binary 2^8
                    $filteredData["P$pCounter"].flag = ([int32]($note_id -shl 19)) + 0b100000000000000 + ([int32]$filteredData["P$pCounter"].flag -band 256)
                } else {
                    $filteredData["P$pCounter"].flag = [string]([int32]$filteredData["P$pCounter"].flag -band 256) # Only check for the "ignore link" flag
                }
                # TODO: Add flag creation script in here. $filteredData["P$pCounter"].something = 
                $pCounter++
            }
        }

        if (-not (Test-Path -Path ($outputFilePath + "/" + $stage.Name))) {
            New-Item -Path ($outputFilePath + "/" + $stage.Name) -ItemType Directory
            Write-Output "Directory created: ($outputFilePath + "/" + $stage.Name)"
        }

        $filteredData["PACENOTES"].count = $pCounter
        Export-Ini -Format "pretty" -InputObject $filteredData -Encoding ASCII ($outputFilePath + "/" + $stage.Name + "/" + $pacenote.Name)

        Write-Output "INI file has been rebuilt successfully."
    }
}

function TranslatePacenote ($pacenote_file, $hashmap_of_values) {
    # TODO: Implement this based on provided maps
}
