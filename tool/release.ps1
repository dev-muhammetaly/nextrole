param([Parameter(Mandatory=$true)][string]$SiteUrl)
$ErrorActionPreference = 'Stop'
Push-Location (Join-Path $PSScriptRoot '..')
try {
  $origin = [Uri]$SiteUrl
  if ($origin.Scheme -ne 'https' -or $origin.AbsolutePath -ne '/' -or $origin.Host -in @('localhost','127.0.0.1') -or $origin.Query -or $origin.Fragment) {
    throw 'Provide your actual deployed HTTPS origin, such as https://your-portfolio.netlify.app'
  }
  flutter analyze
  if ($LASTEXITCODE -ne 0) { throw 'Analyzer failed.' }
  flutter test
  if ($LASTEXITCODE -ne 0) { throw 'Tests failed.' }
  node tool/build_site.mjs $SiteUrl
  if ($LASTEXITCODE -ne 0) { throw 'Public page generation failed.' }
  node tool/check_site.mjs
  if ($LASTEXITCODE -ne 0) { throw 'Public page validation failed.' }
  flutter build web "--dart-define=SITE_URL=$SiteUrl"
  if ($LASTEXITCODE -ne 0) { throw 'Web build failed.' }
  New-Item -ItemType Directory -Force dist | Out-Null
  Compress-Archive -Path build/web/* -DestinationPath dist/nextrole-web.zip -Force
  Write-Output 'Release ready: deploy build/web, or extract dist/nextrole-web.zip before uploading.'
} finally { Pop-Location }
