param (
    [Parameter(Mandatory = $false, HelpMessage = "Do you want to execute translation based on the provided map? DEFAULT: FALSE")]
    [bool]$translate_flag = $false,

    # Path to the input & output directories
    [Parameter(Mandatory = $false, HelpMessage = "Source directory with foldered pacenotes DEFAULT: '.\Pacenotes'")]
    [string]$pacenotesDirectory = ".\MyPacenotes",

    [Parameter(Mandatory = $false, HelpMessage = "Target directory for the converted pacenotes DEFAULT: '.\Pacenotes_Fixed'")]
    [string]$outputFilePath = ".\MyPacenotes_Fixed"
)

# Ensure the ini module is installed
try {
    #Import-Module PsIni
    Import-Module -Name 'E:\Git\Personal\PsIni\PSIni\PsIni.psd1' -Force
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
        $ids_map[[int32]$row.id_old] = [int32]$row.id_new;
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
# 104 = ; #LEFT_RIGHT # TODO: Make it twisty
105 = "HAIRPINLEFT"; #LEFT_ACUTE
106 = "HAIRPINLEFT"; #LEFT_AROUND
107 = "HAIRPINLEFT"; #LEFT_DONUT
108 = "FASTLEFT"; #LEFT_SHORT
109 = "FASTLEFT"; #LEFT_OVER
110 = "90_RIGHT"; #CHICANE_LEFT_ENTRY # TODO: Make it twisty

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
122 = "90_LEFT"; #CHICANE_RIGHT_ENTRY # TODO: Make it twisty

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
    "TWISTY" = 12;
    "OVER_CREST" = 16;
}

# Iterate over all stages directories
foreach ($stage in $stages) {
    # Get list of pacenote files for each stage
    $pacenotes = Get-ChildItem -Path $stage.FullName -File

    # Iterate over individual pacenote files
    foreach ($file in $pacenotes) {
        if (Test-Path ($outputFilePath + "/" + $stage.Name + "/" + $file.Name)) {
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
            # Remove entries with type > 5000
            if ([int64]$iniData[$section].type -gt 5000) {
                continue
            }
            else {
                $pacenote = 0
                $distance = 0
                $standard = 0 # The 2D Pacenote
                $flags = 0

                if ([int32]$iniData[$section].flag -band 0b100000000000000) {
                    $pacenote = ([int32]$iniData[$section].flag -shr 19)
                    $distance = [int32]$iniData[$section].distance
                    $standard = [int32]$iniData[$section].type
                    $flags = ([int32]$iniData[$section].flag -band 256)
                } else {
                    $pacenote = [int32]$iniData[$section].type
                    $distance = [int32]$iniData[$section].distance
                    $standard = $null
                    $flags = ([int32]$iniData[$section].flag -band 256)
                }

                $filteredData["P$pCounter"] = $iniData[$section]
                if ($translate_flag) { # Check if user has indicated desire to execute translation
                    if($ids_map.ContainsKey([int32]$pacenote)) {
                        # Debug
                        #if(-not $ids_map[[int32]$pacenote].Equals([int32]$pacenote)) {
                        #    Write-Output "Translating: $($pacenote) To: $($ids_map[[int32]$pacenote])"
                        #}
                        [int32]$pacenote = $ids_map[[int32]$pacenote] # Translate the pacenotes
                    }
                }
                if ($null -ne $standard) {
                    # Set the flag to Pacenote_id bitwise shifted left + 0b100000000000000 + ignore flag at 8th binary 2^8
                    $filteredData["P$pCounter"].flag = ([int32]([int32]$pacenote -shl 19)) + 0b100000000000000 + ([int32]$flags -band 256)
                    $filteredData["P$pCounter"].type = $standard
                    # Only make sure the flag is either 0 or 256
                    #$filteredData["P$pCounter"].flag = ([int32]$filteredData["P$pCounter"].flag -band 256)
                } elseif ($pacenotes_map.ContainsKey([int32]$pacenote)) {
                    $standard = $standard_map[ # Get the standard ID from standard_map
                        $pacenotes_map[ # Get the og Pacenote name from pacenotes_map
                            [int32]$pacenote # Get the pacenote ID
                        ]
                    ]
                    $filteredData["P$pCounter"].flag = ([int32]([int32]$pacenote -shl 19)) + 0b100000000000000 + ([int32]$flags -band 256)
                    $filteredData["P$pCounter"].type = $standard
                } else {
                    $filteredData["P$pCounter"].flag = [string]([int32]$filteredData["P$pCounter"].flag -band 256) # Only check for the "ignore link" flag
                }
                # TODO: Add flag creation script in here. $filteredData["P$pCounter"].something = 
                $pCounter++
            }
        }

        if (-not (Test-Path -Path ($outputFilePath + "\" + $stage.Name))) {
            New-Item -Path ($outputFilePath + "\" + $stage.Name) -ItemType Directory
            Write-Output "Directory created: $($outputFilePath + "\" + $stage.Name)"
        }

        $filteredData["PACENOTES"].count = $pCounter
        Export-Ini -Format "pretty" -InputObject $filteredData -Encoding ASCII ($outputFilePath + "\" + $stage.Name + "\" + $file.Name)

        Write-Output "INI file has been rebuilt successfully."
    }
}