# Builds the release web app and (optionally) puts it on Firebase Hosting.
#
# Usage (from the nova folder):
#   .\scripts\release_web.ps1 -RecaptchaSiteKey <site key>            # build only
#   .\scripts\release_web.ps1 -RecaptchaSiteKey <site key> -Deploy    # build + publish
#
# The reCAPTCHA SITE key is public by design (every web page that uses it
# shows it), but we still pass it at build time instead of writing it in the
# code. NEVER pass the SECRET key here: that one goes only into the Firebase
# console (App Check).
#
# Release builds use reCAPTCHA for App Check, never the debug provider, so no
# debug token is needed or included.

param(
  [Parameter(Mandatory = $true)] [string] $RecaptchaSiteKey,
  [switch] $Deploy
)

$ErrorActionPreference = 'Stop'
Set-Location (Split-Path $PSScriptRoot -Parent)

if ($RecaptchaSiteKey.Trim().Length -lt 20) {
  throw 'That does not look like a reCAPTCHA site key.'
}

Write-Host 'Running tests first...'
flutter test --timeout 60s
if ($LASTEXITCODE -ne 0) { throw 'Tests failed. Not building.' }

Write-Host 'Building release web app...'
flutter build web --release "--dart-define=RECAPTCHA_SITE_KEY=$RecaptchaSiteKey"
if ($LASTEXITCODE -ne 0) { throw 'Build failed.' }

if ($Deploy) {
  Write-Host 'Publishing rules and web app...'
  firebase deploy --only "firestore:rules,hosting"
  if ($LASTEXITCODE -ne 0) { throw 'Deploy failed.' }
  Write-Host 'Done: https://nova-chat-af63f.web.app'
} else {
  Write-Host 'Built in build\web. Run again with -Deploy to publish.'
}
