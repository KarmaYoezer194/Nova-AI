# Runs the Firestore rules tests on the local emulator.
# Usage (from the nova folder):   .\rules_test\run.ps1
#
# The emulator needs Java. This uses the Java that comes with Android Studio,
# so nothing else has to be installed.
#
# Note: on Windows the Firebase CLI may print "An unexpected error has
# occurred" AFTER the tests, while shutting the emulator down. Look for
# "fail 0" and "Script exited successfully (code 0)": that means all passed.

$ErrorActionPreference = 'Stop'
$jbr = 'C:\Program Files\Android\Android Studio\jbr'
if (-not (Test-Path "$jbr\bin\java.exe")) {
  throw "Java not found at $jbr. Install Android Studio or a JDK 21."
}
$env:JAVA_HOME = $jbr
$env:Path = "$jbr\bin;$env:Path"

Push-Location $PSScriptRoot
try {
  if (-not (Test-Path node_modules)) { npm install --no-fund --no-audit }
  npm test
} finally {
  Pop-Location
}
