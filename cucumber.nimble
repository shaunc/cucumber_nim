# Package

version       = "0.0.11"
author        = "Shaun Cutts"
description   = "Implements Cucumber BDD system in nim."
license       = "MIT"

skipDirs = @["tests"]

# Dependencies

requires "nim >= 0.15.0"
requires "nre >= 1.0.0"
requires "commandeer >= 0.10.5"
requires "tempfile >= 0.1.4"

task test, "test cucumber_nim features":
  exec "nim c -r --verbosity:0 ./tests/run"
