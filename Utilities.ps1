$chocolatey=$env:systemdrive\chocolatey\chocolateyinstall\chocolatey.cmd

function Download-File([string] $url, [string] $path) {
    Write-Host "Downloading $url to $path"
    $downloader = new-object System.Net.WebClient
    $downloader.DownloadFile($url, $path) 
}
function Install-VS11-Beta {
    Download-File http://go.microsoft.com/fwlink/?linkid=237587 vs.exe
    vs /Passive /NoRestart /Full
}
function Disable-UAC {
    Set-ItemProperty -Path HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System -Name EnableLUA  -Value 0
}
function Add-ExplorerMenuItem([string]$label, [string]$command){
    if( -not (Test-Path -path HKCR:) ) {
        New-PSDrive -Name HKCR -PSProvider registry -Root Hkey_Classes_Root
    }
    new-item -Path "HKCR:\*\shell\$label"
    new-item -Path "HKCR:\*\shell\$label\command"
    New-ItemProperty -Path "HKCR:\*\shell\$label\command" -Name "(Default)"  -Value "$command `"%1`""
}
function Choc([string] $package, [string]$source) {
    .$chocolatey install $package $source
}
function Enable-IIS-Win7 {
    .$env:systemdrive\chocolatey\chocolateyinstall\chocolatey.cmd install iis7 -source webpi
    DISM /Online /Enable-Feature /FeatureName:IIS-HttpCompressionDynamic 
    DISM /Online /Enable-Feature /FeatureName:IIS-ManagementScriptingTools 
    DISM /Online /Enable-Feature /FeatureName:IIS-WindowsAuthentication
}
function Enable-Telnet-Win7 {
    DISM /Online /Enable-Feature /FeatureName:TelnetClient 
}
function Enable-Net35-Win7 {
    DISM /Online /Enable-Feature /FeatureName:NetFx3 
}
function Force-Windows-Update {
    if( Test-Path "$env:appdata\Microsoft\Windows\Start Menu\Programs\Startup\bootstrap-post-restart.bat") {
        remove-item "$env:appdata\Microsoft\Windows\Start Menu\Programs\Startup\bootstrap-post-restart.bat"
    }
    $updateSession =new-object -comobject "Microsoft.Update.Session"
    $updatesToDownload =new-Object -com "Microsoft.Update.UpdateColl"
    $updatesToInstall =new-object -com "Microsoft.Update.UpdateColl"
    $Downloader =$updateSession.CreateUpdateDownloader()
    $Installer =$updateSession.CreateUpdateInstaller()
    $Searcher =$updatesession.CreateUpdateSearcher()
    $Result = $Searcher.Search("IsInstalled=0 and Type='Software'")

    If ($Result.updates.count -ne 0)
    {
        foreach($update in $result.updates) {
            write-host "Downloading Update:" $update.title
            if ($update.isDownloaded -ne "true") {
                $updatesToDownload.add($update)
            }
        }

        If ($updatesToDownload.Count -gt 0) {
            $Downloader.Updates =$updatesToDownload
            $Downloader.Download()
        }

        foreach($update in $result.updates) {
            write-host "Installing Updates:" $update.title
            $updatesToinstall.add($update)
        }

        $Installer.updates =$UpdatesToInstall
        $result = $Installer.Install()

        if($result.rebootRequired) {
            $myLocation = (Split-Path -parent $MyInvocation.MyCommand.path)
            New-Item "$env:appdata\Microsoft\Windows\Start Menu\Programs\Startup\bootstrap-post-restart.bat" -type file -force -value "powershell -NonInteractive -NoProfile -ExecutionPolicy bypass -Command `"& '%~dp0bootstrap.ps1' -JustFinishedUpdates`""
            Restart-Computer -force
        }
    }
    else{write-host "There is no update applicable to this machine"}    
}
function Set-FileAssociation([string]$extOrType, [string]$command) {
    if(-not($extOrType.StartsWith("."))) {$fileType=$extOrType}
    if($fileType -eq $null) {
        $testType = (cmd /c assoc $extOrType)
        if($testType -ne $null) {$fileType=$testType.Split("=")[1]}
    }
    if($fileType -eq $null) {
        write-host "Unable to Find File Type for $extOrType"
    }
    else {
        cmd /c ftype $fileType=$command %1
    }
}