param (
	[Alias('f')]
    [switch]$force = $false
)

function ReplaceInFile {
  param (
    [string[]]$FilePath,
    [string[]]$SrcText,
    [string[]]$TargetText
  )

  $utf8 = New-Object System.Text.UTF8Encoding $false
  $RawData = Get-Content $FilePath -Raw
  for ($index = 0; $index -lt $SrcText.count; $index++) {
      $RawData = $RawData.replace($SrcText[$index], $TargetText[$index])
  }
  Set-Content -Value $utf8.GetBytes($RawData) -Encoding Byte -Path $FilePath
}

function GetLatest {
  $download_page = Invoke-WebRequest -Uri $releasesURL -UseBasicParsing

  $versionSort   = { [version]$_.href.TrimEnd('/') }
  $download_page = $download_page.links | Where-Object href -match '^[\d]+[\d\.]+\/$' | Sort-Object $versionSort -Descending | ForEach-Object {
    [version] $version = $_.href -replace '/', ''
    $url               = $releasesURL + "$version/win/"
    try {
      $result = Invoke-WebRequest -Uri $url -UseBasicParsing
      return $result
    }
    catch { }
  } | Select-Object -First 1

  $url32 = $download_page.Links | Where-Object href -NotMatch 'x64' | Where-Object href -Match 'Setup\.exe$' | Select-Object -First 1 -expand href | ForEach-Object { $url + $_ }
  $url64 = $download_page.Links | Where-Object href -Match "(x64.*Setup|Setup_x64)\.exe$" | Select-Object -First 1 -expand href | ForEach-Object { $url + $_ }
  $urlSha32 = $download_page.Links | Where-Object href -NotMatch 'x64' | Where-Object href -Match 'Setup\.exe.sha256sum$' | Select-Object -First 1 -expand href | ForEach-Object { $url + $_ }
  $urlSha64 = $download_page.Links | Where-Object href -Match "(x64.*Setup|Setup_x64)\.exe.sha256sum$" | Select-Object -First 1 -expand href | ForEach-Object { $url + $_ }
  $WebRespone = Invoke-WebRequest $urlSha32
  $sha32   = $WebRespone.ToString()
  $WebRespone = Invoke-WebRequest $urlSha64 
  $sha64 = $WebRespone.ToString()

  if (!$url32 -or !$url64) {
    throw "32bit or 64bit url was not found, investigate or ignore."
  }
  return @{
    Version      = $version
    URL32        = $url32
    SHA32        = $sha32
    URL64        = $url64
    SHA64        = $sha64
  }
}

function GetActual {
  $chocoVersion = choco search $packageId --by-id-only --exact --limit-output
  if(!$chocoVersion) {
    Write-Error "Unable to find package on Chocolatey"
    exit
  }
  return $chocoVersion.split('|')[1]
}

###########
## Start ##
###########
Write-Output "--------------------------------------------------"
Write-Output "Packaging Opera GX"
Write-Output "--------------------------------------------------"

$packageId          = 'opera-gx'
$releasesURL        = 'https://ftp.opera.com/ftp/pub/opera_gx/'
$nuspecPath         = 'operagx.nuspec'
$installScriptPath  = 'tools/chocolateyinstall.ps1'

## Get package and web version ##
$latestRelease = GetLatest
$actualVersion = GetActual
Write-Output "Chocolatey version  : $actualVersion"
Write-Output "Opera repo version  : $($latestRelease.Version)"

## Check if packaging is needed ##
if($latestRelease.Version -like $actualVersion -And !$force) {
  Write-Warning "No new version available"
  exit
}
Write-Warning "Update available !"

## Display release informations ##
Write-Output "--------------------------------------------------"
Write-Output "Url32 : $($latestRelease.URL32)"
Write-Output "Sha32 : $($latestRelease.SHA32)"
Write-Output "Url64 : $($latestRelease.URL64)"
Write-Output "Sha64 : $($latestRelease.SHA64)"
Write-Output "--------------------------------------------------"

## Replace informations in files ##
ReplaceInFile -FilePath $nuspecPath `
              -SrcText '#REPLACE_VERSION#' `
              -TargetText $latestRelease.Version

ReplaceInFile -FilePath $installScriptPath `
              -SrcText '#REPLACE_CHECKSUM#', '#REPLACE_CHECKSUM_64#', '#REPLACE_URL#', '#REPLACE_URL_64#' `
              -TargetText $latestRelease.SHA32, $latestRelease.SHA64, $latestRelease.URL32, $latestRelease.URL64

## Pack choco package ##
$confirmation = Read-Host "Start packing [Y/n]?"
$confirmation = ('y',$confirmation)[[bool]$confirmation]
if($confirmation -eq 'n') {exit}
choco pack

## Reverse files modifications ##
ReplaceInFile -FilePath $nuspecPath `
              -SrcText $latestRelease.Version `
              -TargetText '#REPLACE_VERSION#'

ReplaceInFile -FilePath $installScriptPath `
              -SrcText $latestRelease.SHA32, $latestRelease.SHA64, $latestRelease.URL32, $latestRelease.URL64 `
              -TargetText '#REPLACE_CHECKSUM#', '#REPLACE_CHECKSUM_64#', '#REPLACE_URL#', '#REPLACE_URL_64#'

## Push choco package ##
$confirmation = Read-Host "Push package [Y/n]?"
$confirmation = ('y',$confirmation)[[bool]$confirmation]
if($confirmation -eq 'n') {exit}
$packFileName = $packageId + '.' + $latestRelease.Version + '.nupkg'
choco push $($packFileName) --source https://push.chocolatey.org/

Read-Host "Finished"

