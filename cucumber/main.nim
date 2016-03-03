
# cucumber/main


import future
import os
import strutils
import sequtils
import commandeer 
import sets
import tables
import nre
import options

import "./types"
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

#[
proc `$$`[T](s : T) : string =
  if s == nil: 
    return "(nil)"
  else:
    return $s
]#

let tagRE = re"(?:\s*(~)?(?:(@[\w_]+)|([~*+])\[(.*)\]))"
proc buildTagFilter(tagStr: string, op: string = "+"): TagFilter =
  if tagStr == nil or tagStr.len == 0:
    return (tags: StringSet)=> not ("@skip" in tags)

  let tagStr = tagStr.strip
  let match = (tagStr.match tagRE).get
  let c = toSeq(match.captures.items)
  let (neg, tag, nextOp, inner) = (c[0], c[1], c[2], c[3])
  result = proc (tags: StringSet): bool =
    if tag != nil:
      result = if neg == nil: tag in tags else: not(tag in tags)
    if nextOp != nil:
      result = buildTagFilter(inner, nextOp)(tags)
      if neg != nil:
        result = not result
    var remaining = tagStr[match.match.len..^1].strip(chars = {',', ' '})
    if remaining.len > 0:
      if op == "+":
        result = result or buildTagFilter(remaining, op)(tags)
      elif op == "*":
        result = result and buildTagFilter(remaining, op)(tags)
      else:
        raise newException(ValueError, "Unknown operator for tag expr: " & op)

{.push hint[XDeclaredButNotUsed]:off .}

proc main*(options: varargs[string]): int =
  var appName = getAppFilename()
  {.push warning[Deprecated]:off.}
  commandline:
    arguments paths, string, false
    option verbosity, int, "verbosity", "v", 0
    option bail, bool, "bail", "b", false
    option tags, string, "tags", "t", nil
    option defineTags, string, "define", "d", nil

    exitoption "help", "h", 
      "\n" & """Usage: $1 [path [path ...] ]
    where paths may denote ".feature" files or directories. Paths ending in 
    "/**" will be searched recursively for features. By default, "./features"
    directory is searched.
      """ % appName
  {.pop.}

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

  var defineTagsSet = initSet[string]()
  if defineTags != nil:
    for s in defineTags.split(","):
      defineTagsSet.incl(s)
  let options = CucumberOptions(
    verbosity: verbosity, bail: bail, tagFilter: buildTagFilter(tags),
    defineTags: defineTagsSet )

  var results = runner(features, options)
  result = basicReporter(results, stdout, options)

{.pop.}

when isMainModule:
  main()

