# package: cucumber_nim
# tests/steps/dynmodule.nim
##[
  Creates module containing step and hook definitions written
  by steps.
  
  SECURITY WARNING: unsafe execution of code in /tmp. An attacker
  with right permissions could overwrite.

  A single module is created so that hooks and steps share
  the same globals. As tests are clearer when definitions are
  specified in separate steps, the source of the module is created
  incrementally. The first attempt to access the module causes it
  to be written, compiled into a dynamic library and loaded.

]##

import os
import tables
import osproc
import dynlib
import strutils
import sequtils
import tempfile
import "../../cucumber/parameter"

export LibHandle

type
  InitProc* = (proc() {.nimcall.})
  LibModule* = ref object
    source*: string
    fn*: string
    lib*: LibHandle

DeclareRefParamType(LibModule)

proc buildModule(libMod: LibModule)

proc indentCode*(text: string): string =
  var lines = text.split("\n")
  lines = lines.mapIt "  " & it
  result = lines.join("\n")

proc built(libMod: LibModule): bool = libMod.fn != nil

proc bindInLib*[T](libMod: LibModule, name: string, alt: string = nil) : T =
  if not libMod.built:
    libMod.buildModule
  result = cast[T](checkedSymAddr(libMod.lib, name))
  if result == nil and alt != nil:
    result = cast[T](checkedSymAddr(libMod.lib, alt))
  if result == nil:
    raise newException(
      ValueError, "Couldn't find $1 in $2" % [name, libFN(libMod.fn)])

proc libFN*(sourceFN: string) : string =
  let (dir, base, ext) = splitFile(sourceFN)
  discard ext
  result = joinPath(dir, (DynlibFormat % base))

proc getFN*(libMod: LibModule) : string =
  if libMod == nil or libMod.source == nil:
    return ""
  if libMod.fn == nil:
    buildModule(libMod)
  return libMod.fn

let wrapper = """
import macros
import strutils
import sets
import nre
import "$1/cucumber/types"
import "$1/cucumber/parameter"
import "$1/cucumber/step"
import "$1/cucumber/hook"
import "$1/cucumber/macroutil"

macro defStep(step: typed) : untyped =
  result = step

type SR = ref object
  items: seq[string]

var stepReprs : SR = SR(items: newSeq[string]())

macro saveTree(step: typed) : untyped =
  result = newCall(
    newDot(newDot("stepReprs", "items"), "add"), step.treeRepr.newLit)

macro defHook(hook: typed) : untyped =
  result = hook

type HR = ref object
  items: seq[string]

var hookReprs : HR = HR(items: newSeq[string]())

macro saveHookTree(hook: typed) : untyped =
  result = newCall(
    newDot(newDot("hookReprs", "items"), "add"), hook.treeRepr.newLit)


{.push exportc.}

proc getStepDefns() : StepDefinitions = 
  return step.stepDefinitions

proc getStepReprs() : SR =
  stepReprs

proc getHookDefns() : HookDefinitions = 
  return hook.hookDefinitions

proc getHookReprs() : HR =
  hookReprs

proc setIntContext(context: string, param: string, value: int): void =
  let ctype = contextTypeFor(context)
  paramTypeIntSetter(ctype, param, value)

proc setStringContext(context: string, param: string, value: string): void =
  let ctype = contextTypeFor(context)
  paramTypeStringSetter(ctype, param, value)

proc getIntContext(context: string, param: string) : int =
  let ctype = contextTypeFor(context)
  return paramTypeIntGetter(ctype, param)  

{.pop.}
"""

proc loadSource*(source: string): LibModule =
  let module = LibModule(source: source)
  return module

proc addSource*(
    libMod: var LibModule, source: string) =
  if libMod.source == nil:
    let baseDir = getCurrentDir()
    let source = wrapper % baseDir & "\n" & source
    libMod.source = source
  else:
    if libMod.fn != nil:
      raise newException(Exception, "Module already built: $1" % libMod.fn)
    libMod.source &= "\n" & source

proc buildModule(libMod: LibModule) = 

  let (file, stepFN) = mkstemp(mode = fmWrite, suffix = ".nim")
  file.write(libMod.source)
  file.close()

  let libFN = libFN(stepFN)
  let output = execProcess(
    "nim c --verbosity:0 --app:lib $1" % stepFN,
    options = {poStdErrToStdOut, poUsePath, poEvalCommand})
  if not fileExists(libFN):
    echo "COULDNT GENERATE STEP WRAPPER:"
    echo output
    raise newException(
      ValueError, "Couldn't generate step wrapper (source in $1)." % stepFN)

  libMod.fn = stepFN
  libMod.lib = loadLib(libFN)
  let init = bindInLib[InitProc](libMod, "NimMain")
  init()

proc cleanupModule*(libMod: LibModule) : void =
  assert libMod != nil
  # TODO: unload causes hang. Pehaps memory from library left dangling?
  # unloadLib(libMod.lib)
  if fileExists(libMod.fn):
    removeFile(libMod.fn)
  let (dir, name, ext) = libMod.fn.splitFile
  discard ext
  let libFN = joinPath(dir, (DynLibFormat % name))
  if fileExists(libFN):
    removeFile(libFN)



