# Set share location and credentials
$Server = 'SERVER-NAME' # Server where OSDRemote shortcuts go
$domain = 'domain.name'
$shortcutShare = "\\$Server.$domain\ShareName\OptionalPath" # Folder where OSDRemote shortcuts go - Can be at the root of the share or in a folder
$NaUsername = "$domain\OSDRemote_NA" # Your OSDRemote domain user (only has permissions to this share\path)
$NaPassword = [Text.Encoding]::Utf8.GetString([Convert]::FromBase64String('U29tZVJhbmRvbVBhc3N3b3JkMQ=='))
$vncSource = "$PSScriptRoot\UltraVNC_$env:PROCESSOR_ARCHITECTURE"
$vncPath = "$Env:ProgramFiles\OSDRemote"
$vncPassword = [Text.Encoding]::Utf8.GetString([Convert]::FromBase64String('U29tZVJhbmRvbVBhc3N3b3JkMg=='))

# Use this to generate encoded passwords used above (never save your clear text password in a file - these are only here to make it easier to understand)
# [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes('SomeRandomPassword1'))
# [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes('SomeRandomPassword2'))

function Add-FirewallRule {
  param( 
    $name,
    $tcpPorts,
    $appName = $null,
    $serviceName = $null
  )
  $fw = New-Object -ComObject hnetcfg.fwpolicy2 
  $rule = New-Object -ComObject HNetCfg.FWRule
    
  $rule.Name = $name
  if ($appName -ne $null) { $rule.ApplicationName = $appName }
  if ($serviceName -ne $null) { $rule.serviceName = $serviceName }
  $rule.Protocol = 6 #NET_FW_IP_PROTOCOL_TCP
  $rule.LocalPorts = $tcpPorts
  $rule.Enabled = $true
  $rule.Grouping = "@firewallapi.dll,-23255"
  $rule.Profiles = 7 # all
  $rule.Action = 1 # NET_FW_ACTION_ALLOW
  $rule.EdgeTraversal = $false
    
  $fw.Rules.Add($rule)
}

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
  # Use V1 console if in WinPE (VNC doesn't seem to be able to handle V2)
  New-ItemProperty -Path 'HKCU:\Console' -Name 'ForceV2' -PropertyType 'DWORD' -Value 0 -Force > $null
  # Use SMS10000 package path in WinPE
  $vncPath = $vncSource
} else {
  # Copy WinVNC to ProgramFiles when in Windows
  Write-Output "$(Get-Date) -- Copying OSDRemote to '$vncPath'"
  New-Item -Path $vncPath -ItemType Directory -Force > $null
  Copy-Item -Path "$vncSource\*" -Destination $vncPath -Force > $null
}

# Create firewall rule for VNC
Write-Output "$(Get-Date) -- Creating firewall rule for WinVNC"
Add-FirewallRule -name "WinVNC" -tcpPorts "5900" -appName "$vncPath\winvnc.exe" -serviceName $null

# Start WinVNC
Write-Output "$(Get-Date) -- Starting WinVNC"
Start-Process "$vncPath\winvnc.exe" -WorkingDirectory "$vncPath" -ArgumentList "-install"

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

# Create shortcut
Write-Output "$(Get-Date) -- Creating VNC shortcut ""$idName.lnk"""
$shell = New-Object -ComObject WScript.Shell
# WinVNC shortcut
$shortcut = $shell.CreateShortcut("$shortcutShare\$idName.lnk")
$shortcut.TargetPath = "$shortcutShare\vncviewer.exe"
$shortcut.Arguments = "$ip /password $vncPassword"
$shortcut.Save()

# Close service account network connection
Write-Output "$(Get-Date) -- Disconnecting OSDRemote network share"
net use $shortcutShare /delete