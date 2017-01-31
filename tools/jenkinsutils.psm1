<#
.Synopsis
   'Install-DockerBits' cmdlet that prepares machines to build Docker containers.
.DESCRIPTION
   'Install-DockerBits' cmdlet that prepares machines to build Docker containers.
   Ensures presence of NuGet, Docker bits and Docker Cmdlets  
.EXAMPLE
   Install-DockerBits
   Installs Docker and dependencies such as NuGet, Chocolatey, Github, Docker, etc.
#> 
Function Install-DockerBits()
{ 
  $Script:ErrorActionPreference='Stop';
  
  If ($IsWindows) {
    #Run WindowsUpdate
    Ipmo PSWindowsUpdate;
    Install-WindowsUpdate -MicrosoftUpdate -AcceptAll�-IgnoreUserInput -Verbose
    
    #Enable Container Support
    Enable-WindowsOptionalFeature -Online -FeatureName containers -All -NoRestart|Out-Null;
    Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V -All -NoRestart|Out-Null;
    
    #Get Docker Dependencies
    Get-DockerDeps
    
    #Install docker bits
    Import-Module -Name DockerMsftProvider -Force
    Import-Packageprovider -Name DockerMsftProvider -Force
    Get-PackageSource -ProviderName DockerMsftProvider
    Install-Package -Name docker -ProviderName DockerMsftProvider -Update -Verbose
    If ($(Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V -All).RestartNeeded) {
      Write-Host  'This computer requires a reboot...' 
      Restart-Computer -Force -Verbose 
    } else {Write-Host  'This computer is ready to run Containers!'  -F Green -B Black}
    
    #Install Base Images
    Update-MatchingBaseImage -image 'microsoft/nanoserver','microsoft/windowsservercore','brycem/win10build';
  } else {
    if (-not(Get-Command docker)) {Throw "Install-DockerBits function currently only-supported if $IsWindows=$true"}
  }
}

<#
.Synopsis
   'Get-MatchingBaseImage' cmdlet creates local docker build
#> 
#Install or Update your base container images�
function  Get-MatchingBaseImage  ($image)
{
	[String]$Global:BuildVer='';
	$WinVer = Get-ItemProperty -Path 'HKLM:\\SOFTWARE\\Microsoft\\Windows NT\\CurrentVersion';
	$WinVer.CurrentMajorVersionNumber,$WinVer.CurrentMinorVersionNumber,$WinVer.CurrentBuildNumber,$WinVer.UBR|`
		ForEach-Object {$Global:BuildVer+=[String]$_+'.'};
	$Global:BuildVer=$BuildVer.TrimEnd('.');Write-Output 'Docker host OS version:',$BuildVer;
	$image|ForEach-Object `
	{
		$matchtag=$_+':'+$BuildVer;
		$latestag=$_+':latest'; 
		If ($(docker image ls -q $matchtag).Length -eq 12) 
		{
			Write-Host ('Found:   '+$matchtag)
		} else {
			Write-Host ('Pulling :'+$matchtag);
			docker pull $matchtag
		}
		docker tag $matchtag $latestag;
		If ($(docker image ls -q $latestag) -eq $(docker image ls -q $matchtag))
		{
			Write-Host ('Up2date: '+$latestag)
		} else {
			Throw ($matchtag+' does not match '+$latestag)
		}
		If (($(docker image ls $latestag -q).Length -ne 12) `
			-and ($(docker image ls $latestag -q) -ne $(docker image ls $matchtag -q)))
		{
			Throw 'docker images were not updated'
		}
	}
}

<#
.Synopsis
   'New-PsDockerImage' cmdlet creates local docker build
#> 
Function New-PsDockerImage (
  [String]$BaseImage='microsoft/dotnet:1.0.1-nanoserver-core',
  [Bool]$Clean=$true,
  [String]$PsRepPath='D:\GitHub\PowerShell'
){   
  if ($Clean) {Remove-Item -Path .\WorkSpace -Recurse -Force -ErrorAction Ignore}
  New-Item -Path .\WorkSpace -ItemType Directory -Force
  Copy-Item -Path $PsRepPath\test -Destination .\WorkSpace\test -Recurse -Force
  Copy-Item -Path .\jenkinsutils.psm1 -Destination .\WorkSpace\jenkinsutils.psm1 -Force
  Copy-Item -Path $PsRepPath\build.psm1 -Destination .\WorkSpace\build.psm1 -Force
  Copy-Item -Path .\Dockerfile -Destination .\WorkSpace\Dockerfile -Force
  (Get-Content -path .\WorkSpace\Dockerfile).Replace('@BASE_IMAGE@',($BaseImage)) | Out-File .\WorkSpace\Dockerfile -Encoding utf8 -Force
  New-Item -Path .\WorkSpace\PowerShell -ItemType Directory -Force
  Get-LatestPS -Tag 'latest' -FilePrefix 'powershell-' -FileSuffix '-win10-x64.zip' -TargetPath (convert-Path '.\WorkSpace\PowerShell')
  Build-ContainerImage -Path .\WorkSpace -Verbose
}


<#
.Synopsis
   Downloads and extracts PowerShell release.zip on Nano or ServerCore.
.DESCRIPTION
   Downloads and extracts PowerShell release.zip on Nano or ServerCore.
   Usefull for installing latest release of PowerShell in Docker Containers
.EXAMPLE
   Get-LatestPS
   Downloads the latest powershell-win10-x64.zip and extracts it to C:\PowerShell by default
   Will no-op if existing build matches the latest already exists there.
.EXAMPLE
   Get-LatestPS -FileSuffix '-win10-x64.msi' -ReturnPathOnly
   Returns the path to the latest PowerShell MSI for Win10
.EXAMPLE
   Get-LatestPS -Tag v6.0.0-alpha.9 -FileSuffix '-1.el7.centos.x86_64.rpm' -TargetPath ./PowerShell
   Copies specific label 'powershell-6.0.0_alpha.9-1.el7.centos.x86_64.rpm' to ./PowerShell
   Will no-op if existing build matches the latest already exists there.
#>
Function Get-LatestPs (
  [String]$Tag = 'latest',
  [String]$FilePrefix = 'powershell-',
  [String]$FileSuffix = '-win10-x64.zip',
  [String]$TargetPath = $Env:SystemDrive+'\PowerShell',
  [Switch]$GetPathOnly
)
{
  if ($Tag -eq 'latest') {
    $GetUri = 'https://github.com/PowerShell/PowerShell/releases/latest/'
    $response=Invoke-WebRequest -UseBasicParsing -Uri $GetUri -ErrorAction Stop
    $gitTag = ($response.BaseResponse.ResponseUri.AbsoluteUri.TrimEnd('/').split('/'))[-1].TrimStart('v')
    $downloadFile = $FilePrefix + $gitTag + $FileSuffix
    $downloadUri = ($response.BaseResponse.ResponseUri.AbsoluteUri.Replace('tag','download')) + '/' + $downloadFile
  } else {
    $downloadFile = $FilePrefix + ($Tag.TrimStart('v')) + $FileSuffix
    $downloadUri = ('https://github.com/PowerShell/PowerShell/releases/download/'+$Tag+'/' + $downloadFile)
  }
  if ($GetPathOnly) {return $downloadUri} else { Write-Host ($Tag+" release is '"+$downloadFile+"'") }
  if ([String]$(Get-Content -Path $TargetPath\.dlsource.txt -ErrorAction Ignore)  -eq $downloadUri){
    Write-Host ($Tag+" release is already present in '"+$TargetPath+"'.  Exiting...")
    return "no new build to test" #no-op and exit
  } else {
    [System.IO.FileInfo]$tempFile = [System.IO.Path]::GetTempFileName()
    Invoke-WebRequest -UseBasicParsing -Uri $downloadUri -OutFile $tempFile -ErrorAction Stop
    if ($FileSuffix.EndsWith('.zip')) {
      Remove-Item -Path $TargetPath -Recurse -Force -ea Ignore
      Expand-ZipFile -SourceFile $tempFile -TargetPath $TargetPath -ErrorAction Stop
      Remove-Item -Path $tempFile -Force -ea Ignore
    }
    Write-Host ("Logging download source URL to '"+($TargetPath.FullName + '\.dlsource.txt')+"'.")
    $downloadUri | out-file -FilePath ($TargetPath + '\.dlsource.txt') -Force
    return ("Requestpackage successfully downloaded to '"+$TargetPath+"'.")
  }
}

<#
.Synopsis
   'Expand-ZipFile' cmdlet that can run on Nano or ServerCore.
.DESCRIPTION
   Light implementation of a Expand-ZipFile cmdlet, with support for CoreCLR or FullCLR
   for automating file unzipping operations.  
.EXAMPLE
   $file=Expand-ZipFile -SourceFile '.\myzip.zip' -TargetPath 'C:\Program Files\MyDir'
   Expands '.\myzip.zip' to 'C:\Program Files\MyDir'
#> 
Function Expand-ZipFile ([System.IO.FileInfo]$SourceFile,[System.IO.DirectoryInfo]$TargetPath){   
    Write-Host ("Extracting new files to '"+$TargetPath.FullName+"'...")
    try {
        Add-Type -AssemblyName System.IO.Compression.FileSystem
    } catch  {
        Add-Type -AssemblyName System.IO.Compression.ZipFile
    } finally {
       [System.IO.Compression.ZipFile]::ExtractToDirectory($SourceFile,$TargetPath)
    }
    if ($?) {return $TargetPath} else {Throw ($error|select -first 1)}
}

<#
.Synopsis
   'Get-DockerDeps' cmdlet that installs Docker dependencies.
.DESCRIPTION
   'Get-DockerDeps' cmdlet that installs Docker dependencies.
   Ensures presence of NuGet, Git, Docker bits and Docker Cmdlets  
.EXAMPLE
   Get-DockerDeps
   Installs NuGet, Chocolatey, Github, Docker, etc.
#>
Function Get-DockerDeps (){
  If ($IsWindows) {
    #List of Powershell Package Providers to ensure are present
    [Array]$Providers=@{'Name'='NuGet';'MinimumVersion'='2.8.5.207'},
                      @{'Name'='Chocolatey';'MinimumVersion'='2.8.5.130'},
                      @{'Name'='GitHubProvider';'PackageName'='GitHub';'MinimumVersion'='0.5.0.0';'WarningAction'='Ignore'},
                      @{'Name'='DockerMsftProvider';'PackageName'='DockerMsftProvider';'MinimumVersion'='1.0.0.1';'WarningAction'='Ignore'}
                  
    #List of Chocolatey Packages to ensure are present
   [Array]$Packages=@{'Name'='jdk8';'ProviderName'='chocolatey';'InstallUpdate'=$true;'IncludeWindowsInstaller'=$true},
                    @{'Name'='Git';'MinimumVersion'='2.10.0';'ProviderName'='chocolatey';'InstallUpdate'=$true;'IncludeWindowsInstaller'=$true},
                    @{'Name'='microsoft-build-tools';'ProviderName'='chocolatey';'InstallUpdate'=$true;'IncludeWindowsInstaller'=$true},
                    @{'Name'='cmake';'ProviderName'='chocolatey';'InstallUpdate'=$true;'IncludeWindowsInstaller'=$true},
                    @{'Name'='vscode-powershell';'ProviderName'='chocolatey';'IncludeWindowsInstaller'=$true},
                    @{'Name'='notepad2';'ProviderName'='chocolatey';'IncludeWindowsInstaller'=$true}
                    
   #List of Powershell Repositores to ensure are present
   [Array]$PsRepos=  @{'Name'='PSGallery';'InstallationPolicy'='Trusted';'SourceLocation'='https://www.powershellgallery.com/api/v2/';'Confirm:$false'=''}

   #List of Powershell Modules to ensure are present and up to date
   [Array]$PsModules=@{'Name'='Pester';'Repository'='PSGallery';'InstallUpdate'=$true},
                     @{'Name'='PSWindowsUpdate';'Repository'='PSGallery';'InstallUpdate'=$true},
                     @{'Name'='DockerMsftProvider';'Repository'='PSGallery';'InstallUpdate'=$true}

      $Script:ConfirmPreference='None'
      #Install Requested PS Repos
      $PsRepos|ForEach-Object -Process `
      {
        #Find out if the desired Repo is registered
        $params=@{}  #Trimming nonexistant parameters
        $_.GetEnumerator()|? Value -ne 'ErrorAction'|foreach `
        {
          If ((gcm Register-PSRepository | select Parameters -ExpandProp Parameters).Keys.Contains(($_.Name -split ':')[0]))
          {
            $params+=@{$_.Name=$_.Value}
          }
        }
        If (-not(Get-PSRepository -Name $_.Name -EA Ignore))
        {
          Register-PSRepository @params -ErrorAction Stop
        }
        If (-not(Get-PSRepository -Name $_.Name -EA Stop )) {
          Throw "Unable to install "+$_.Name
        } else {Set-PSRepository @params -EA Ignore}
      }

      #Install Requested PS Package Providers
      $Providers|ForEach-Object -Process `
      {
        #construct parameters for command
        $GetParams=@{};$_.GetEnumerator()|? Value -ne 'ErrorAction'|foreach `
        {
          If ((gcm Get-PackageProvider | select Parameters -ExpandProp Parameters).Keys.Contains(($_.Name -split ':')[0]))
          { 
            $GetParams+=@{$_.Name=$_.Value}
          }
        }
        If (-not(Get-PackageProvider @GetParams -ErrorAction Ignore))
        {
          $InstallParams=@{}
          $_.GetEnumerator()|? Value -ne 'ErrorAction'|foreach `
          {
            If ((gcm Install-PackageProvider | select Parameters -ExpandProp Parameters).Keys.Contains(($_.Name -split ':')[0]))
            {
              $InstallParams+=@{$_.Name=$_.Value}
            }
          }
          Install-PackageProvider @InstallParams -ErrorAction Stop -Force
          If ($_.PackageName) #GitHubHack for mismatch of PackageName and ProviderName
          {
            $GetParams.Name=$_.PackageName
            $InstallParams.Name=$_.PackageName  
            $ImportParams=@{}
            $InstallParams.GetEnumerator()|? Value -ne 'WarningAction'|foreach `
            {
              If ((gcm Import-PackageProvider | select Parameters -ExpandProp Parameters).Keys.Contains(($_.Name -split ':')[0]))
              {
                $ImportParams+=@{$_.Name=$_.Value}
              }
            }
            Import-PackageProvider @ImportParams -ErrorAction Stop
          }
        }
        If ($_.Name -eq 'Chocolatey') {choco feature enable -n=allowGlobalConfirmation}
        If (-not(Get-PackageProvider @GetParams -ErrorAction Stop)) {Throw "Unable to install "+$_.Name}
      }
      
      #Install Requested PS Modules
      $PsModules|ForEach-Object -Process `
      {
        $params=@{}
        $_.GetEnumerator()|? Value -ne 'ErrorAction'|foreach `
        {
          If ((gcm Get-InstalledModule | select Parameters -ExpandProp Parameters).Keys.Contains(($_.Name -split ':')[0]))
          {
            $params+=@{$_.Name=$_.Value}
          }
        }
        If (-not(Get-InstalledModule @params -ErrorAction Ignore)) 
        {
          $FindParams=@{}
          $_.GetEnumerator()|? Value -ne 'ErrorAction'|foreach `
          {
            If ((gcm Find-Package | select Parameters -ExpandProp Parameters).Keys.Contains(($_.Name -split ':')[0]))
            {
              $FindParams+=@{$_.Name=$_.Value}
            }
          }
          Find-Module @FindParams -ErrorAction Stop|Install-Module -ErrorAction Stop -Force -SkipPublisherCheck 
        }
        If (-not(Get-InstalledModule @params -ErrorAction Stop)) {Throw "Unable to install "+$_.Name}
      }

      #Install Requested PS Packages
      $Packages|ForEach-Object -Process `
      {
        #construct parameters for command
        $GetParams=@{};$_.GetEnumerator()|? Value -ne 'ErrorAction'|foreach `
        {
          If ((gcm Get-Package | select Parameters -ExpandProp Parameters).Keys.Contains(($_.Name -split ':')[0]))
          {
            $GetParams+=@{$_.Name=$_.Value}
            write-output $GetParams
          }
        }
        If (-not(Get-Package @GetParams -ErrorAction Ignore))
        {
          $FindParams=@{}
          $_.GetEnumerator()|? Value -ne 'ErrorAction'|foreach `
          {
            If ((gcm Find-Package | select Parameters -ExpandProp Parameters).Keys.Contains(($_.Name -split ':')[0]))
            {
              $FindParams+=@{$_.Name=$_.Value}
              write-output $FindParams
            }
          }
          Find-Package @FindParams -ErrorAction Stop | Install-Package -ErrorAction Stop -Force
        }
        If (-not(Get-Package @GetParams -ErrorAction Stop)) {Throw "Unable to install "+$_.Name}
      }
  } else {write-warning "Get-DockerDeps support for non-Windows platform is NYI"}
}
