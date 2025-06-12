## Moves all pacenotes by set $offset (find the variable in this script & edit it to your needs

# Ensure the ini module is installed
try {
    #Import-Module PsIni
    Import-Module -Name 'E:\Git\Personal\PsIni\PSIni\PsIni.psd1' -Force
}
catch {
    Install-Module -Scope CurrentUser PsIni
    Import-Module PsIni
}

$stage = Get-Item -Path "E:\Documents\RBR-Masterclass\Roadbook-Database\stages\Odry snow II\notes\REC_20241122_213003.ini"
$offset = [int32]-176

$iniData = [ordered] @{}
$iniData = Import-Ini $stage.FullName

foreach ($section in $iniData.Keys) {
    $iniData[$section].distance = [int32]$iniData[$section].distance + $offset
}

Export-Ini -Format "pretty" -InputObject $iniData -Encoding ASCII ($stage.DirectoryName + "\" + $stage.BaseName + "_offset.ini")