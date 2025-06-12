param (
    [Parameter(Mandatory = $false, HelpMessage = "Do you want to execute translation based on the provided map? DEFAULT: FALSE")]
    [bool]$translate_flag = $false,

    # Path to the input & output directories
    [Parameter(Mandatory = $false, HelpMessage = "Source directory with foldered pacenotes DEFAULT: '.\Pacenotes'")]
    [string]$pacenotesDirectory = ".\MyPacenotes",

    [Parameter(Mandatory = $false, HelpMessage = "Target directory for the converted pacenotes DEFAULT: '.\Pacenotes_Fixed'")]
    [string]$outputFilePath = ".\MyPacenotes_Fixed"
)

if ( $PSBoundParameters.ContainsKey('Debug') ) {
    $DebugPreference = "Continue"
}

# Ensure the ini module is installed
try {
    #Import-Module PsIni
    Import-Module -Name 'E:\Git\Personal\PsIni\PSIni\PsIni.psd1' -Force
    #Note: To get intellisense, copy the above line to Powershell terminal & execute it
}
catch {
    Install-Module -Scope CurrentUser PsIni
    Import-Module PsIni
}

# Get list of all stages directories
$stages = Get-ChildItem -Path $pacenotesDirectory -Directory

# Map between old standard of pacenotes & new standard
try {
    $ids_map = @{}

    $csvData = Import-Csv -Path '.\MAP_CoDrivers.csv'

    foreach ($row in $csvData) {
         # Split the new_id value by '+' delimiter
        $new_ids = $row.new_id.Split('+') | ForEach-Object {
            [int32]$_
        }

        $ids_map[[int32]$row.old_id] = $new_ids;
    } # Unwrapping the CSV list into a hashmap
} catch {
    $translate_flag = $false
    Write-Output "TRANSLATE MAP NOT FOUND! NOT TRANSLATING!"
}


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
    104 = "FASTRIGHT"; #LEFT_RIGHT
    105 = "HAIRPINLEFT"; #LEFT_ACUTE
    106 = "HAIRPINLEFT"; #LEFT_AROUND
    107 = "HAIRPINLEFT"; #LEFT_DONUT
    108 = "FASTLEFT"; #LEFT_SHORT
    109 = "FASTLEFT"; #LEFT_OVER
    110 = "TWISTY"; #CHICANE_LEFT_ENTRY

    112 = "EASYRIGHT"; #RIGHT # TODO: Check if the image fits
    113 = "FLATRIGHT"; #RIGHT_6
    114 = "90_RIGHT"; #RIGHT_SQUARE
    115 = "EASYRIGHT"; #RIGHT_INTO
    116 = "FASTLEFT"; #RIGHT_LEFT
    117 = "HAIRPINRIGHT"; #RIGHT_ACUTE
    118 = "HAIRPINRIGHT"; #RIGHT_AROUND
    119 = "HAIRPINRIGHT"; #RIGHT_DONUT
    120 = "FASTRIGHT"; #RIGHT_SHORT
    121 = "FASTLEFT"; #RIGHT_OVER
    122 = "TWISTY"; #CHICANE_RIGHT_ENTRY

    27 = "BRIDGE"; #BRIDGE
    1038 = "BRIDGE"; #AT_BRIDGE

    #WATER

    85 = "WATER"; #WATER
    1035 = "WATER"; #AT_FORD
    1063 = "WATER"; #AT_WATER

    #NARROWS
    200 = "NARROWS"; #TIGHT
    201 = "NARROWS"; #NARROW

    244 = "NARROWS"; #SECTION_NARROWER

    #WIDENS
    202 = "WIDENS"; #WIDE
    203 = "WIDENS"; #WIDENS

    245 = "WIDENS"; #SECTION_WIDER

    #BUMP
    19 = "BUMP"; #BUMP
    61 = "BUMP"; #BROW
    71 = "BUMP"; #BUMPS

    307 = "BUMP"; #BUMPY
    308 = "CARE"; #ROUGH

    1036 = "BUMP"; #AT_BUMP
    1040 = "BUMP"; #AT_BROW
    1050 = "BUMP"; #AT_BUMPS

    1340 = "BUMP"; #BUMPY_MIDDLE
    1341 = "BUMP"; #BUMPY_INSIDE
    1342 = "BUMP"; #BUMPY_OUTSIDE
    1343 = "BUMP"; #BUMPY_BRAKING
    1344 = "BUMP"; #BUMPY_ENTRY
    1345 = "BUMP"; #BUMPY_EXIT
    1346 = "BUMP"; #BUMPY_MAYBE
    1347 = "BUMP"; #BUMPY_VERY

    #TWISTY
    12 = "TWISTY"; #TWISTY

    #JUMP
    20 = "JUMP"; #JUMP
    1037 = "JUMP"; #AT_JUMP

    #OVER_CREST
    16 = "OVER_CREST"; #OVER_CREST
    60 = "OVER_CREST"; #CREST
    1039 = "OVER_CREST"; #AT_CREST

}

# Mapping of corner names to original ID's
$standard_map = @{
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

    "CAUTION" = 32; # Red triangle
    "CARE" = 18; # Orange triangle
    "WATER" = 17;
    "NARROWS" = 14;
    "WIDENS" = 15;
    "BRIDGE" = 27;
    "BUMP" = 19;
    "JUMP" = 20;
    "TWISTY" = 12;
    "OVER_CREST" = 16;
}

function Create_Pacenote {
    param ($pacenote, $distance, $standard, $flags)

    $pacenoteObject = [ordered]@{
        type = $pacenote
        distance = $distance
        flag = $flags
    }

    if ($null -ne $standard) {
        # Set the flag to Pacenote_id bitwise shifted left + 0b100000000000000 + ignore flag at 8th binary 2^8
        $pacenoteObject.flag = ([int32]([int32]$pacenote -shl 19)) + 0b100000000000000 + ([int32]$flags -band 256)
        $pacenoteObject.type = $standard
    } elseif ($pacenotes_map.ContainsKey([int32]$pacenote)) {
        $standard = $standard_map[ # Get the standard ID from standard_map
            $pacenotes_map[ # Get the og Pacenote name from pacenotes_map
                [int32]$pacenote # Get the pacenote ID
            ]
        ]
        $pacenoteObject.flag = ([int32]([int32]$pacenote -shl 19)) + 0b100000000000000 + ([int32]$flags -band 256)
        $pacenoteObject.type = $standard
    } else {
        $pacenoteObject.type = [int32]$pacenote
        $pacenoteObject.flag = [string]([int32]$flags -band 256) # Only check for the "ignore link" flag
    }

    return $pacenoteObject
}

# Iterate over all stages directories
foreach ($stage in $stages) {
    # Get list of pacenote files for each stage
    $pacenotes = Get-ChildItem -Path $stage.FullName -File

    # Create directory for the files
    if (-not (Test-Path -Path ($outputFilePath + "\" + $stage.Name))) {
        New-Item -Path ($outputFilePath + "\" + $stage.Name) -ItemType Directory
        Write-Output "Directory created: $($outputFilePath + "\" + $stage.Name)"
    }

    # Iterate over individual pacenote files
    foreach ($file in $pacenotes) {
        if (Test-Path ($outputFilePath + "/" + $stage.Name + "/" + $file.Name)) {
            Write-Output "File " + $file.Name + " already exists. Skipping!"
            continue
        }
        if ($file.Extension -eq ".txt") {
            Copy-Item -Path $file.FullName -Destination ($outputFilePath + "\" + $stage.Name + "\" + $file.Name)
            continue
        }
        # Load contents of the original INI file
        $iniData = [ordered] @{}
        $iniData = Import-Ini $file.FullName
        
        # Prepare structures for new INI file
        if ($iniData.Contains("PACENOTES")) {
            $filteredData = [ordered] @{
                _ = [ordered]@{
                    Comment1 = ($file.Name + " pacenotes file generated for CoPilot mods compatible with FilipekMod.")
                    Comment2 = ("For more details, please visit https://amun.pl/blog")
                }
                PACENOTES = $iniData["PACENOTES"]
            }
        } else {
            $filteredData = [ordered] @{
                _ = [ordered]@{
                    Comment1 = ($file.Name + " pacenotes file generated for CoPilot mods compatible with FilipekMod.")
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
            # Remove entries with type > 5000, these are configuration strings encoded by Bee
            if ([int64]$iniData[$section].type -gt 5000) {
                continue
            }
            else {
                $pacenote = 0
                $distance = 0
                $standard = 0 # The 2D Pacenote
                $flags = 0

                # Check if custom flag is stored & use it as our pacenote
                if ([int32]$iniData[$section].flag -band 0b100000000000000) {
                    $pacenote = ([int32]$iniData[$section].flag -shr 19)
                    $distance = $iniData[$section].distance
                    $standard = [int32]$iniData[$section].type
                    $flags = ([int32]$iniData[$section].flag -band 256)
                }
                # If there was no custom flag, use the type as our pacenote
                else {
                    $pacenote = [int32]$iniData[$section].type
                    $distance = $iniData[$section].distance
                    $standard = $null
                    $flags = ([int32]$iniData[$section].flag -band 256)
                }

                # Check if user has indicated desire to execute translation
                if ($translate_flag -and $ids_map.ContainsKey([int32]$pacenote)) {
                    $ids_map[[int32]$pacenote] | ForEach-Object { # For Each value in the array of new pacenotes
                        $filteredData["P$pCounter"] = $iniData[$section]
                        $filteredData["P$pCounter"] = Create_Pacenote -pacenote $_ -distance $distance -standard $standard -flags $flags
                        $distance += 1
                        $pCounter++
                    }
                    # Debug
                    if ( -not $ids_map[[int32]$pacenote].Equals([int32]$pacenote) ) {
                        Write-Debug "Translated: $($pacenote) To: $($ids_map[[int32]$pacenote])"
                    }
                    continue
                }
                $filteredData["P$pCounter"] = $iniData[$section]
                $filteredData["P$pCounter"] = Create_Pacenote -pacenote $pacenote -distance $distance -standard $standard -flags $flags
                $pCounter++
            }
        }
        
        $filteredData["PACENOTES"].count = $pCounter
        Export-Ini -Format "minified" -InputObject $filteredData -Encoding ascii ($outputFilePath + "\" + $stage.Name + "\" + $file.Name) -Append 

        Write-Output "$($file.Name) has been rebuilt successfully."
    }
}
