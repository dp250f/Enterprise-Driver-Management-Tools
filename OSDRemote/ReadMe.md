# OSDRemote

Before [OneVinn's TSBackground](https://onevinn.schrewelius.it/Apps01.html) had remote viewing (and before I even knew about it), I needed a way to remotely monitor OS Deployments and Upgrade task sequences. I played around with using MS DaRT and RDP but it was not a very streamlined process from a usability perspective. Not satisfied with that, I came up with this solution which uses [Ultra VNC](https://www.uvnc.com/) and is very easy to use once setup.

## Prerequisites
* File Share (and optional subfolder) for your OSDRemote shortcuts and vncviewer.exe to live (Access should be limited to your technicians and OSDRemote service account)
* Service account which only has modify permissions to this share/folder
* UltraVNC executables and dlls
* Configuration Manager

## Installation
### SMS10000 folder and OSDRemote Share
* Download this repository and copy the **OSDRemote** folder into your **SMS10000** source folder
* Download [UltraVNC (64-bit and 32-bit)](https://www.uvnc.com/downloads/ultravnc.html), install them on a couple computers, and copy these files into **OSDRemote\UltraVNC_\<Arch\>** folders:
  * **winvnc.exe**
  * **ddengine64.dll**
  * **schook64.dll**
  * **vnchooks.dll**
* Run WinVNC (it should run after install) on one of the computers.
* Right-click the WinVNC system notification icon and select '**Admin Properties**'. Set the following properties:
  * VNC Password (You will need this later)
  * Disable JavaViewer
* Edit C:\Program Files\uvnc bvba\UltraVNC\UltraVNC.ini in a text editor:
  * Remove 'path=C:\Program Files\uvnc bvba\UltraVNC'
  * Change 'MaxCpu2' to 50
  * Change 'MaxFPS' to 30
* Copy '**C:\Program Files\uvnc bvba\UltraVNC\UltraVNC.ini**' into 'OSDRemote\UltraVNC_\<Arch\>' folders
* Copy '**C:\Program Files\uvnc bvba\UltraVNC\vncviewer.exe**' into your OSDRemote share\folder on your server (It needs to be in the same folder as the shortcuts which will use it)
* Move '**options.vnc**' from OSDRemote into your OSDRemote share\folder on your server (It needs to be in the same folder vncviewer.exe)
* Edit '**Start-VNC.ps1**' and '**Stop-VNC.ps1**' to set script variables for your environment

When you're done, here's what your **SMS10000\OSDRemote** folder should look like:

![Screenshot01](https://github.com/dp250f/Documentation/blob/main/OSDRemote/Screenshot02.png?raw=true)
![Screenshot02](https://github.com/dp250f/Documentation/blob/main/OSDRemote/Screenshot01.png?raw=true)

Here's what your OSDRemote file share/folder should look like (minus the active OSD shortcuts):

![Screenshot03](https://github.com/dp250f/Documentation/blob/main/OSDRemote/Screenshot03.png?raw=true)

### Add OSDRemote to Boot Media
* Edit your **winpeshl.ini** file to run **Start-VNC.ps1** on startup. It is located in these 2 locations:
  ```
  \\SITE-SERVER\SMS_<SITE-CODE>\OSD\bin\i386\winpeshl.ini
  \\SITE-SERVER\SMS_<SITE-CODE>\OSD\bin\x64\winpeshl.ini
  ``` 
  Here's an example of a default ConfigMgr winpeshl.ini with Start-VNC.ps1 added:
  ```cmd
  [LaunchApps]
  wpeinit.exe
  %SYSTEMDRIVE%\Windows\System32\WindowsPowerShell\v1.0\powershell.exe, -ExecutionPolicy Bypass -WindowStyle Minimized -File %SYSTEMDRIVE%\sms\PKG\SMS10000\OSDRemote\Start-VNC.ps1
  %SYSTEMDRIVE%\sms\bin\x64\TsBootShell.exe
  ```

* Add your SMS10000 folder to your boot media (which contains OSDRemote folder)
  
  ![Screenshot04](https://github.com/dp250f/Documentation/blob/main/OSDRemote/Screenshot04.png?raw=true)

* Update boot media when it asks

### Add OSDRemote to OSD Task Sequence

* The boot media will start WinVNC every time it boots, so the task sequence just needs to start WinVNC after windows starts for the first time. There are 2 task sequence steps necessary for that to work:
  * Copy SMS10000 from WinPE to your OSDisk (after partitioning disks)
  ![Screenshot05](https://github.com/dp250f/Documentation/blob/main/OSDRemote/Screenshot05.png?raw=true)
  * Start WinVNC (after 'Setup Windows and Configuration Manager' step)
  ![Screenshot06](https://github.com/dp250f/Documentation/blob/main/OSDRemote/Screenshot06.png?raw=true)
* At the end of your task sequence, run Stop-VNC.ps1 to uninstall WinVNC and cleanup OSDRemote shortcut(s)
  ![Screenshot07](https://github.com/dp250f/Documentation/blob/main/OSDRemote/Screenshot07.png?raw=true)

### Add OSDRemote to Upgrade Task Sequence
* This process is pretty much the same as for OSD task sequence, but you'll need to download and extract your zipped SMS10000 package before starting WinVNC
  ![Screenshot08](https://github.com/dp250f/Documentation/blob/main/OSDRemote/Screenshot08.png?raw=true)

## Usage

This is the fun part!
* Boot a computer using your new boot media
* Browse to your OSDRemote file share/folder and double-click the new WinVNC shortcut (use details view and sort by date to make it easier to identify which one to use):

  ![Screenshot03](https://github.com/dp250f/Documentation/blob/main/OSDRemote/Screenshot03.png?raw=true)
* Enjoy OSDRemote

  ![Screenshot09](https://github.com/dp250f/Documentation/blob/main/OSDRemote/Screenshot09.png?raw=true)

## Disclaimer
This script works for me in my environment. I cannot guarantee it will work in other environments. Always test other people's code thoroughly before using it in yours.

## Contributing
Pull requests are welcome. For major changes, please open an issue first to discuss what you would like to change.

## License
[GNU GPLv3](https://choosealicense.com/licenses/gpl-3.0/)