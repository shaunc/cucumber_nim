# cucumber/parameter.nim
#
## Defines types of parameters to pass values to steps
## from scenario definitions and context initialized by hooks.
##
## Parameters from scenario definitions start as strings; from
## context, they start as typed values. 
##
## Parameter type objects have names of functions to use for
## parsing and unpacking. These are used at compile time by step
## and hook macros. Because of this, new parameter types must be 
## added before step and hook definitions are processed.
## 
## There are three types of context: global, feature and scenario,
## segregated according to their lifecycle.
## 
## Each parameter type has a sequence for each context type. When
## a context is initialized, all parameters of a given type used
## in steps or hooks are mapped to elements in this sequence.
## 
## When a type is created, it creates its contexts, and registers
## functions to reset a context, and to add elements to that context.
## The former are stored in ``contextResetters``. The latter in
## ``contextAllocators``, which is indexed by parameter type name.
## 

import tables
import macros
from strutils import capitalize, parseInt
import macroutil
import "./types"

type
  Context[T] = Table[string, T]
  ContextList[T] = array[ContextType, Context[T]]
  ResetContext = proc(ctype: ContextType) : void

const ptPrefix = "paramType"
var contextResetters : seq[ResetContext] = @[]
## list of resetters, one for each parameter type. As contexts are
## cleared unilaterally at the start of their lifecycle (global, feature
## or scenario), there is no need to keep track of which parameter type
## corresponds to which resetter.
## 

proc newContext[T]() : Context[T] = initTable[string, T]()

proc resetList[T](contextList: var ContextList[T], clear: ContextType) :void = 
  contextList[clear] = initTable[string, T]()

proc ptName*(name: string, suffix: string) : string {.compiletime.} = 
  ptPrefix & capitalize(name) & capitalize(suffix)
proc cttName(name: string) : string {.compiletime.} =
  capitalize(name) & "Context"

macro declareContextList(name : static[string], ptype: untyped) : untyped =
  newType(cttName(name), newBrkt("ContextList", ptype), true)

macro declareContextInst(name: static[string], ptype: untyped) : untyped =
  let cInit = newBrkt("newContext", ptype)
  let clistInit = quote do:
    [`cInit`(), `cInit`(),`cInit`(), `cInit`(),]
  result = newStmtList(newVar(
    ptName(name, "context"), cttName(name), clistInit, isExport = true))

macro declareContextReset(name: static[string], ptype: untyped) : untyped =
  let listRName = newBrkt("resetList", ptype)
  let ctxName = newIdentNode(ptName(name, "Context"))
  let radd = newDot("contextResetters", "add")
  result = quote do:
    `radd`(proc(ctype: ContextType): void =
      `listRName`(`ctxName`, ctype)
    )

macro declareContextGetter(
    name: static[string], ptype: untyped, newFct: untyped) : untyped =
  let getterName = pubName(nil, ptName(name, "Getter"))
  let ctype = newIdentNode("ctype")
  let contextExpr = newBrkt(ptName(name, "Context"), "ctype")
  let contextAcc = newBrkt("context", "varName")
  let nnot = newIdentNode("not")
  let varName = newIdentNode("varName")
  let context = newIdentNode("context")
  result = quote do:
    proc `getterName`(`ctype`: ContextType, `varName`: string) : `ptype` =
      var `context` = `contextExpr`
      if `nnot` (`varName` in `context`):
        `contextAcc` = `newFct`()
      return `contextAcc`

macro declareContextSetter(name: static[string], ptype: untyped) : untyped =
  let setterName = pubName(nil, ptName(name, "Setter"))
  let ctype = newIdentNode("ctype")
  let varName = newIdentNode("varName")
  let val = newIdentNode("val")
  let contextExpr = newBrkt(
    newBrkt(ptName(name, "Context"), "ctype"), "varName")
  result = quote do:
    proc `setterName`(
        `ctype`: ContextType, `varName`: string, `val` : `ptype`): void =
      `contextExpr` = `val`

template declarePT*(
    name: static[string],
    ptype: untyped,
    parseFct: typed,
    newFct: typed,
    pattern: static[string]
    ) : untyped =
  ##
  ##
  ## ``declarePT("int", int, parseInt, newInt, r"(-?\d+)")`` results in
  ## 
  ## const paramTypeIntName* = "int"
  ## const paramTypeIntTypeName* = "int"
  ## const paramTypeIntParseFct* = parseInt
  ## const paramTypeIntNewFct* = newInt
  ## const paramTypeIntPattern = r"(-?\d+)"
  ## type
  ##   IntContext* = ContextList[int]
  ## var paramTypeIntContext* : IntContext = [
  ##   newContext[int](), newContext[int](), newContext[int](), nil]
  ## 
  ## contextResetters.add proc(ctype: ContextType) : void = 
  ##   resetList[int](paramTypeIntContext, ctype)
  ## 
  ## proc paramTypeIntGetter = proc(ctype: ContextType, varName: string) : int =
  ##   context = paramTypeIntContext[ctype]
  ##   if not varName in context:
  ##     context[varName] = newInt()
  ##   return context[varName]
  ## 
  ## proc paramTypeIntSetter(ctype: ContextType, varName: string, val: int): void =
  ##   paramTypeIntContext[ctype][varName] = val
  ## 
  mNewVarExport(ptName(name, "name"), string, name)
  mNewVarExport(ptName(name, "typeName"), string, nameOfNim(ptype))
  mNewVarExport(ptName(name, "parseFct"), nil, parseFct)
  mNewVarExport(ptName(name, "newFct"), nil, newFct)
  mNewVarExport(ptName(name, "pattern"), string, pattern)
  declareContextList(name, ptype)
  declareContextInst(name, ptype)
  declareContextReset(name, ptype)
  declareContextGetter(name, ptype, newFct)
  declareContextSetter(name, ptype)

export strutils.parseInt
proc newInt() : int = 0
declarePT("int", int, strutils.parseInt, newInt, r"(-?\d+)")

proc parseBool*(s: string) : bool = strutils.parseBool(s)
proc newBool() : bool = false
const boolPattern = r"((?:true)|(?:false)|(:yes)|(:no))";
declarePT("bool", bool, parseBool, newBool, boolPattern)

proc newStringA(): string = ""
proc parseString*(s: string) : string = s
declarePT("string", string, parseString, newStringA, r"(.*)")

## `blockParam` type is special: string filled from step block parameter
declarePT("blockParam", string, parseString, newStringA, nil)

