# cucumber/main


import os
import strutils
import commandeer
import tables
import "./feature"
import "./loader"
import "./runner"
import "./report"

proc main(options: seq[string] = nil): void =
  var appName = getAppFilename()
  commandline:
    arguments paths, string, false

    exitoption "help", "h", 
      "\n" & """Usage: $1 [path [path ...] ]
    where paths may denote ".feature" files or directories. Paths ending in 
    "/**" will be searched recursively for features. By default, "./features"
    directory is searched.
      """ % appName

  if paths.len == 0:
    paths.add("./features")
  var features : seq[Feature] = @[]
  var errors = loader(features, paths)
  for path, exc in errors.pairs:
    echo "Could not load $1: $2" % [path, exc.msg]
    echo exc.getStackTrace()
    echo "\n"
  var results = runner(features)
  basicReporter(results, stdout)

when isMainModule:
  main()