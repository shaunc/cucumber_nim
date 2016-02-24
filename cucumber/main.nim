# cucumber/main


import os
import strutils
import commandeer 

import tables
import "./feature"
import "./loader"
import "./runner"
import "./report"


template withDir*(newDir: string, body: typed) : typed =
  var currentDir = os.getCurrentDir()
  try:
    os.setCurrentDir(newDir)
    body
  finally:
    os.setCurrentDir(currentDir)

{.push hint[XDeclaredButNotUsed]: off.}

proc main*(options: varargs[string]): int =
  var appName = getAppFilename()
  commandline:
    arguments paths, string, false
    option verbosity, int, "verbosity", "v", 0

    exitoption "help", "h", 
      "\n" & """Usage: $1 [path [path ...] ]
    where paths may denote ".feature" files or directories. Paths ending in 
    "/**" will be searched recursively for features. By default, "./features"
    directory is searched.
      """ % appName

  for opt in options:
    if opt.startsWith("-"):
      raise newException(Exception, "unknown option: " & opt)
    else:
      paths.add(opt)
  if paths.len == 0:
    paths.add("./features")
    paths.add("./tests/features")
  var features : seq[Feature] = @[]
  var errors = loader(features, paths)
  for path, exc in errors.pairs:
    echo "Could not load $1: $2" % [path, exc.msg]
    echo "Detail: ", exc.msg
    echo exc.getStackTrace()
    echo "\n"

  var results = runner(features, verbosity)
  result = basicReporter(results, stdout, verbosity)

{.pop.}

when isMainModule:
  main()

