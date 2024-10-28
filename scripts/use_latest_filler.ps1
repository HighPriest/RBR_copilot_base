## -- This script lets you quickly fill all the directories with a "mypacenote_latest.txt"
## -- It is a maintenance script to make sure we don't use some random pacenotes

# Define the source file and the target directory
$targetDirectory = "C:\Games\RBR\Plugins\NGPCarMenu\MyPacenotes"  # Adjust the path to your target directory

# Get all subdirectories in the target directory
$subdirectories = Get-ChildItem -Path $targetDirectory -Directory -Recurse

# Copy the file to each subdirectory
foreach ($subdir in $subdirectories) {
    Remove-Item (Join-Path -Path $subdir.FullName -ChildPath "*.txt")
    New-Item (Join-Path -Path $subdir.FullName -ChildPath "mypacenote_latest.txt") -ItemType File
}

Write-Output "File copied to all subdirectories."
