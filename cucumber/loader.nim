# cucumber/loader
#
# loaders to search for feature files

import os
import strutils
import tables
import "./feature"

type
  LoadingErrors = Table[string, ref Exception]

proc checkLoadFile(
  features: var seq[Feature], spath: string, errors: var LoadingErrors): void

proc loader*(
    features: var seq[Feature], toSearch: varargs[string],
    recFilter = {pcFile, pcDir}) : LoadingErrors =
  ## load features found in `toSearch into `features`.
  ## 
  ## `toSearch`: array of file or directory names in which
  ##   to search for features. If a directory ends in "/**", it
  ##   will be searched recursively.
  ## 
  ## `recFilter` controls treatment symlinks during recursive walk.
  ##   Default is to ignore. See `os.walkDirRec` for all options.
  ## 
  var errors = initTable[string, ref Exception]()
  for spath in toSearch:
    var path = spath.strip
    if dirExists(path):
      for kind, dpath in os.walkDir(path):
        if kind != pcDir:
          checkLoadFile(features, dpath, errors)
    elif fileExists(path):
      checkLoadFile(features, path, errors)
    elif path.endsWith( "/" / "**"):
      for dpath in os.walkDirRec(path, recFilter):
          checkLoadFile(features, dpath, errors)
    result = errors

proc checkLoadFile(
    features: var seq[Feature], spath: string, errors: var LoadingErrors
    ): void =
  var path = spath.strip()
  if not path.endsWith(".feature"):
    path &= ".feature"
  if dirExists(path):
    return
  if not fileExists(path):
    return
  try:
    loadFeature(features, path)
  except:
    var exc = getCurrentException()
    errors[path] = exc

when isMainModule:
  var features : seq[Feature] = @[]
  discard loader(features, "examples")
  echo features.len