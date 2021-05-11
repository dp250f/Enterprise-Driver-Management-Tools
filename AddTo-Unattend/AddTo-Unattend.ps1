Param (
  [string]$UnattendFile = $(throw "-UnattendFile is required."),
  [string]$CmdDescription = $(throw "-CmdDescription is required."),
  [string]$CmdPath = $(throw "-CmdPath is required.")
)

# Specify Variables (for script testing)
#$UnattendFile = "F:\Unattend.xml"
#$CmdDescription = 'Test 2'
#$CmdPath = 'test2.exe'

# Load xml into object
[xml]$XML = Get-Content $UnattendFile

# if element(s) exist
If ($XML.unattend.settings.component.RunSynchronous.RunSynchronousCommand) {
  # Create parent and child objects
  $Parent = (($XML.unattend.settings | Where-Object pass -EQ 'specialize').component | Where-Object name -EQ Microsoft-Windows-Deployment).RunSynchronous
  $Child = $Parent.LastChild.Clone()
    
  # Check to see if $CmdPath is already in the xml
  If ($Parent.ChildNodes.Path -eq $CmdPath) {
    # Output cmd already exists
    Write-Output "'$CmdPath' command already exists in '$UnattendFile'"
  } Else {
    # Find the first unused order number
    $OrderNumber = 0
    Do {
      $OrderNumber ++
    } While ($Parent.ChildNodes.Order -eq $OrderNumber)

    # Edit new element
    $Child.Description = $CmdDescription
    $Child.Order = "$OrderNumber"
    $Child.Path = $CmdPath

    # Add element to parent
    $Parent.AppendChild($Child) > $null
        
    # Save xml object to file
    $XML.Save($UnattendFile)

    # Output success
    Write-Output "'$CmdDescription' command added to '$UnattendFile' as number $($Child.Order)"
  }
} Else {
  # Output error
  Write-Output "Error: '$UnattendFile' does not contain 'RunSynchronousCommand'"
  Exit 1
}