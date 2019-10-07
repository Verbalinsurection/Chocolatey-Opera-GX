$ErrorActionPreference = 'Stop';
$toolsDir   = "$(Split-Path -parent $MyInvocation.MyCommand.Definition)"


$version = '63.0.3368.56078'

$checksumUrl = 'https://get.geo.opera.com/pub/opera_gx/' + $version + '/win/Opera_GX_' + $version + '_Setup.exe.sha256sum'
$checksum64Url = 'https://get.geo.opera.com/pub/opera_gx/' + $version + '/win/Opera_GX_' + $version + '_Setup_x64.exe.sha256sum'

$WebRespone = Invoke-WebRequest $checksumUrl

$checksum   = $WebRespone.ToString()

$WebRespone = Invoke-WebRequest $checksum64Url 

$checksum64 = $WebRespone.ToString()

Write-Output "Checksums for Version $version"
Write-Output "$checksum"
Write-Output "$checksum64"

$url        = 'https://get.geo.opera.com/pub/opera_gx/' + $version + '/win/Opera_GX_' + $version + '_Setup.exe'
$url64      = 'https://get.geo.opera.com/pub/opera_gx/' + $version + '/win/Opera_GX_' + $version + '_Setup_x64.exe'

$pp = Get-PackageParameters
 
$parameters += if ($pp.NoDesktopShortcut)     { " /desktopshortcut=0"; Write-Host "Desktop shortcut won't be created" }
$parameters += if ($pp.NoTaskbarShortcut)     { " /pintotaskbar=0"; Write-Host "Opera won't be pinned to taskbar" }

$packageArgs = @{
  packageName   = $env:ChocolateyPackageName
  unzipLocation = $toolsDir
  fileType      = 'EXE'
  url           = $url
  url64bit      = $url64

  silentArgs     = '/install /silent /launchopera=0 /setdefaultbrowser=0 /allusers=1' + $parameters

  softwareName  = 'operagx*'

  checksum      = $checksum
  checksumType  = 'sha256'
  checksum64    = $checksum64
  checksumType64= 'sha256'

  validExitCodes= @(0, 3010, 1641)
}

Install-ChocolateyPackage @packageArgs
