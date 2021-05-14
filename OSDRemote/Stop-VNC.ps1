# Set share location and credentials
$Server = 'SERVER-NAME' # Server where OSDRemote shortcuts go
$domain = 'domain.name'
$shortcutShare = "\\$Server.$domain\ShareName\OptionalPath" # Folder where OSDRemote shortcuts go - Can be at the root of the share or in a folder
$shortcutCleanupAge = 7 # maximum shortcut age in days
$NaUsername = "$domain\OSDRemote_NA" # Your OSDRemote domain user (only has permissions to this share\path)
$NaPassword = [Text.Encoding]::Utf8.GetString([Convert]::FromBase64String('U29tZVJhbmRvbVBhc3N3b3JkMQ=='))
$vncSource = "$PSScriptRoot\UltraVNC_$env:PROCESSOR_ARCHITECTURE"
$vncPath = "$Env:ProgramFiles\OSDRemote"

# Use this to generate encoded password used above (never save your clear text password in a file - this is only here to make it easier to understand)
# [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes('SomeRandomPassword1'))

# Wait until the network is up
Write-Output "$(Get-Date) -- Waiting for network to be ready..."
While (!(Test-Connection -Quiet -Count 1 -computer "$Server.$domain")) {
  Start-Sleep -Seconds 1
}

# Get first wired ethernet IPv4 address
$ip = @(Test-Connection 127.0.0.1 -Count 1 | Select-Object Ipv4Address)[0].IPV4Address.IPAddressToString

# Bail out if network not connected
If ($ip -eq 127.0.0.1) { exit 1 }

# Handle things specific to WinPE / Windows
if ($env:SystemRoot -eq 'X:\Windows') {
  # Use SMS10000 package path in WinPE
  $vncPath = $vncSource
}

# Stop any running WinVNC processes
Get-Process -Name 'winvnc' -ErrorAction SilentlyContinue | Stop-Process -Force

# Uninstall WinVNC
Write-Output "$(Get-Date) -- Uninstalling WinVNC"
Start-Process "$vncPath\winvnc.exe" -WorkingDirectory "$vncPath" -ArgumentList "-uninstall" -Wait

# Wait for VNC to exit
Write-Output "$(Get-Date) -- Waiting for VNC to exit"
Wait-Process -Name "WinVNC" -ErrorAction SilentlyContinue

# Delete firewall rule for VNC (Not using Remove-NetFirewallRule cmdlet for Win7 compatibility)
Write-Output "$(Get-Date) -- Deleting firewall rule for WinVNC"
Start-Process "netsh.exe" -ArgumentList "advfirewall firewall delete rule name=WinVNC"

# Delete OSDRemote folder
Write-Output "$(Get-Date) -- Removing OSDRemote folder '$vncPath'"
If (Test-Path $vncPath) { Remove-Item $vncPath -Recurse -Force }

# Delete scheduled task (Not using Unregister-ScheduledTask cmdlet for Win7 compatibility)
Write-Output "$(Get-Date) -- Deleting OSDRemote Scheduled Task"
Start-Process "schtasks.exe" -ArgumentList "/Delete", "/TN OSDRemote", "/F"

# Create network connection using service account
Write-Output "$(Get-Date) -- Connecting to OSDRemote network share"
net use $shortcutShare $NaPassword /USER:$NaUsername

#If we have a valid computer name, use it for idName
If ($env:ComputerName -match 'MINWINPC|MININT-') {
  # use IP address for idName
  $idName = $ip
  Write-Output "$(Get-Date) -- Valid computer name not found"
} Else {
  $idName = $env:ComputerName
  Write-Output "$(Get-Date) -- Found valid computer name ""$idName"""
  # Delete IP address shortcut
  Write-Output "$(Get-Date) -- Deleting old shortcut ""$ip.lnk"""
  Remove-Item -Path "$shortcutShare\$ip.lnk" -Force -ErrorAction SilentlyContinue
}

# Delete shortcut
Write-Output "$(Get-Date) -- Deleting VNC shortcut ""$idName.lnk"""
Remove-Item -Path "$shortcutShare\$idName.lnk" -Force -ErrorAction SilentlyContinue

# Cleanup orphaned shortcut files older than specified age
Write-Output "$(Get-Date) -- Deleting orphaned VNC Shortcuts more than $shortcutCleanupAge days old"
Get-ChildItem $shortcutShare | Where-Object { ((Get-Date) - $_.LastWriteTime).days -gt $shortcutCleanupAge -and $_.Name -match ".lnk" } | Remove-Item -Force -ErrorAction SilentlyContinue

# Close service account network connection
Write-Output "$(Get-Date) -- Disconnecting OSDRemote network share"
net use $shortcutShare /delete