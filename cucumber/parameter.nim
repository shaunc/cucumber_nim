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
  Context[T] = seq[T]
  ContextList[T] = array[ContextType, Context[T]]
  ResetContext = proc(ctype: ContextType) : void
  AllocateContext = proc(ctype: ContextType) : int

const ptPrefix = "paramType"
var contextResetters : seq[ResetContext] = @[]
## list of resetters, one for each parameter type. As contexts are
## cleared unilaterally at the start of their lifecycle (global, feature
## or scenario), there is no need to keep track of which parameter type
## corresponds to which resetter.
## 
var contextAllocators: Table[string, AllocateContext] = 
  initTable[string, AllocateContext]()
## map parameter type name -> allocator, which allocates an instance
## for a parameter type, and returns its index.

proc ptName(name: string, suffix: string) : string {.compiletime.} = 
  ptPrefix & capitalize(name) & capitalize(suffix)
proc cttName(name: string) : string {.compiletime.} =
  capitalize(name) & "Context"

proc newContext[T]() : Context[T] = @[]

proc newContextElt[T](context: var Context[T], initialValue: T) : int =
  result = context.len
  context.add initialValue

proc resetList[T](contextList: var ContextList[T], clear: ContextType) :void = 
  var context = contextList[clear]
  context.setLen(0)

macro declareContextList(name : static[string], ptype: untyped) : untyped =
  newType(cttName(name), newBrkt("ContextList", ptype), true)

macro declareContextInst(name: static[string], ptype: untyped) : untyped =
  let cInit = newBrkt("newContext", ptype)
  let clistInit = quote do:
    [`cInit`(), `cInit`(), `cInit`()]
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

macro declareContextAllocate(
    name: static[string], ptype: untyped, newFct: untyped) : untyped =
  let ctxAlc = newBrkt("contextAllocators", newLit(name))
  let ctx = newBrkt(ptName(name, "Context"), "ctype")
  let ncxtElt = newBrkt("newContextElt", ptype)
  let ctype = newIdentNode("ctype")
  result = quote do:
    `ctxAlc` = proc(`ctype`: ContextType) : int =
      `ncxtElt`(`ctx`, `newFct`())

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
  ## const paramTypeIntType* = int
  ## const paramTypeIntParseFct* = parseInt
  ## const paramTypeIntNewFct* = newInt
  ## const paramTypeIntPattern = r"(-?\d+)"
  ## type
  ##   IntContext* = ContextList[int]
  ## var
  ##   paramTypeIntContext* : IntContext = [
  ##     newContext[int](), newContext[int](), newContext[int]()]
  ## contextResetters.add proc(ctype: ContextType) : void = 
  ##   resetList[int](paramTypeIntContext, ctype)
  ## contextAllocators["int"] = proc(ctype: ContextType) : int =
  ##   newContextElt[int](paramTypeIntContext[ctype], newInt())
  ## 
  mNewVarExport(ptName(name, "name"), string, name)
  #mNewVarExport(ptName(name, "type"), nil, ptype)
  mNewVarExport(ptName(name, "parseFct"), nil, parseFct)
  mNewVarExport(ptName(name, "newFct"), nil, newFct)
  mNewVarExport(ptName(name, "pattern"), string, pattern)
  declareContextList(name, ptype)
  declareContextInst(name, ptype)
  declareContextReset(name, ptype)
  declareContextAllocate(name, ptype, newFct)

proc newInt() : int = 0
declarePT("int", int, strutils.parseInt, newInt, r"(-?\d+)")

proc parseBool(s: string) : bool = strutils.parseBool(s)
proc newBool() : bool = false
const boolPattern = r"((?:true)|(?:false)|(:yes)|(:no))";
declarePT("bool", bool, parseBool, newBool, boolPattern)

proc newStringA(): string = ""
proc parseStringA(s: string) : string = s
declarePT("string", string, parseStringA, newStringA, r"(.*)")

## `blockParam` type is special: string filled from step block parameter
declarePT("blockParam", string, parseStringA, newStringA, nil)

