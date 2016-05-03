# cucumber/parameter.nim
#
##[ 

  Defines types of parameters to pass values to steps
  from scenario definitions and context initialized by hooks.

  Parameters from scenario definitions start as strings; from
  context, they start as typed values. 

  Parameter type objects have names of functions to use for
  parsing and unpacking. These are used at compile time by step
  and hook macros. Because of this, new parameter types must be 
  added before step and hook definitions are processed.

  There are three types of context: global, feature and scenario,
  segregated according to their lifecycle.

  Each parameter type has a sequence for each context type. When
  a context is initialized, all parameters of a given type used
  in steps or hooks are mapped to elements in this sequence.

  When a type is created, it creates its contexts, and registers
  functions to reset a context, and to add elements to that context.
  The former are stored in ``contextResetters``. The latter in
  ``contextAllocators``, which is indexed by parameter type name.

]## 

import tables
import macros
from strutils import capitalize, parseInt, toLower
import macroutil
import "./types"

type
  Context*[T] = Table[string, T]
  ContextList*[T] = array[ContextType, Context[T]]
  ResetContext* = proc(ctype: ContextType) : void

proc contextTypeFor*(cname: string) : ContextType =
  case cname.substr().toLower
  of "global": result = ctGlobal
  of "feature": result = ctFeature
  of "scenario": result = ctScenario
  of "quote": result = ctQuote
  of "column": result = ctTable
  else:
    raise newException(Exception, "unknown context " & cname)

const ptPrefix = "paramType"
var contextResetters* : seq[ResetContext] = @[]
## list of resetters, one for each parameter type. As contexts are
## cleared unilaterally at the start of their lifecycle (global, feature
## or scenario), there is no need to keep track of which parameter type
## corresponds to which resetter.
## 
proc resetContext*(ctype: ContextType) : void =
  for rst in contextResetters: rst(ctype)

proc newContext*[T]() : Context[T] = initTable[string, T]()

proc resetList*[T](contextList: var ContextList[T], clear: ContextType) :void = 
  contextList[clear] = initTable[string, T]()

proc ptName*(name: string, suffix: string) : string {.compiletime.} = 
  var name = name
  if name[0..3] == "seq[" and name[^1] == ']':
    name = name[0..2] & capitalize(name[4..^2])
  ptPrefix & capitalize(name) & capitalize(suffix)
proc cttName(name: string) : string {.compiletime.} =
  capitalize(name) & "Context"

macro declareTypeName(name: static[string], ptype: untyped) : untyped =
  result = newVar(
    ptName(name, "typeName"), cast[string](nil), ptype.toStrLit, true)

macro declareParseFct(
    name: static[string], ptype: untyped, parseFct: untyped) : untyped =
  let pname = pubName(nil, ptName(name, "parseFct"))
  result = quote do:
    let `pname` : (proc(s: string) : `ptype`) = `parseFct`

macro declareNewFct(
    name: static[string], ptype: untyped, newFct: untyped) : untyped =
  let pname = pubName(nil, ptName(name, "newFct"))
  result = quote do:
    let `pname` : (proc() : `ptype`) = `newFct`

macro declareContextList(name : static[string], ptype: untyped) : untyped =
  result = newType(cttName(name), newBrkt("ContextList", ptype), true)

macro declareContextInst(name: static[string], ptype: untyped) : untyped =
  let cInit = newBrkt("newContext", ptype)
  let clistInit = quote do:
    [ `cInit`(), `cInit`(), `cInit`(), `cInit`(), 
      `cInit`(), `cInit`(), ]
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
  let contextAcc = newBrkt(contextExpr, "varName")
  let nnot = newIdentNode("not")
  let varName = newIdentNode("varName")
  var callNewFct: NimNode
  if newFct.kind == nnkNilLit:
    callNewFct = newFct
  else:
    callNewFct = newCall(newFct)
  result = quote do:
    proc `getterName`(`ctype`: ContextType, `varName`: string) : var `ptype` =
      if `nnot` (`varName` in `contextExpr`):
        `contextAcc` = `callNewFct`
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

macro declareContextColumnSetter( 
    name: static[string], ptype: untyped ) : untyped =

  let isSeqType = name[0..3] == "seq[" and name[^1] == ']'
  if not isSeqType:
    return newStmtList()

  let subt = name[4..^2]
  let setterName = pubName(nil, ptName(name, "ColumnSetter"))
  let varName = newIdentNode("varName")
  let strVal = newIdentNode("strVal")
  let contextExpr = newCall(
    ptName(name, "Getter"), newIdentNode("ctTable"), varName)
  let parseFctName = ptName(subt, "parseFct")
  let callParse = newCall(parseFctName, strVal)
  let addStmt = newCall(newDot(contextExpr, "add"), callParse)
  result = quote do:
    proc `setterName`(
        `varName`: string, `strVal`: string): void =
      `addStmt`
  #echo result.toStrLit.strVal

template DeclareParamType*(
    name: static[string],
    ptype: untyped,
    parseFct: typed,
    newFct: typed,
    pattern: static[string]
    ) : untyped =
    
  ##[
    Declare a parameter type.

    ``DeclareParamType("int", int, parseInt, newInt, r"(-?\d+)")`` results in
    
    ```
    const paramTypeIntName* = "int"
    const paramTypeIntTypeName* = "int"
    const paramTypeIntParseFct* = parseInt
    const paramTypeIntNewFct* = newInt
    const paramTypeIntPattern = r"(-?\d+)"
    type
      IntContext* = ContextList[int]
    var paramTypeIntContext* : IntContext = [
      newContext[int](), newContext[int](), newContext[int](), 
      newContext[int](), newContext[int](), nil]
    
    contextResetters.add proc(ctype: ContextType) : void = 
      resetList[int](paramTypeIntContext, ctype)
    
    proc paramTypeIntGetter = proc(ctype: ContextType, varName: string) : var int =
      if not varName in paramTypeIntContext[ctype]:
        paramTypeIntContext[ctype][varName] = newInt()
      return paramTypeIntContext[ctype][varName]
    
    proc paramTypeIntSetter(ctype: ContextType, varName: string, val: int): void =
      paramTypeIntContext[ctype][varName] = val
    ```

    If a sequence type such as `seq[int]` is then defined, it will be
    defined as above (mutatis mutandis), but with the addition of:

    ```nim
    proc paramTypeSeqIntColumnSetter(varName: string, strVal: string): void = 
      paramTypeSeqIntContext(ctTable, varName).add(parseInt(strVal))
    ```
  ]##

  mNewVarExport(ptName(name, "name"), string, name)
  declareTypeName(name, ptype)
  declareParseFct(name, ptype, parseFct)
  declareNewFct(name, ptype, newFct)
  mNewVarExport(ptName(name, "pattern"), string, pattern)
  declareContextList(name, ptype)
  declareContextInst(name, ptype)
  declareContextReset(name, ptype)
  declareContextGetter(name, ptype, newFct)
  declareContextSetter(name, ptype)
  declareContextColumnSetter(name, ptype)

macro DeclareRefParamType*(ptype: untyped) : untyped =
  ##[
    Declare reference type.

    Shortcut, used for object on context (only). No parser or pattern,
    and "new" is nil.
  ]##
  let name = $ptype
  quote do:
    DeclareParamType(`name`, `ptype`, nil, nil, nil)

export strutils.parseInt
proc newInt() : int = 0
DeclareParamType("int", int, strutils.parseInt, newInt, r"(-?\d+)")

proc parseBool*(s: string) : bool = 
  case s
    of "a", "an", "t": true
    of "f": false
    else: strutils.parseBool(s)

proc newBool() : bool = false
const boolPattern = r"((?:t(?:rue)?)|(?:f(?:alse)?)|(?:y(?:es)?)|(?:no?)|(?:an?))";
DeclareParamType("bool", bool, parseBool, newBool, boolPattern)

proc newStringA(): string = ""
proc parseString*(s: string) : string = s
DeclareParamType("string", string, parseString, newStringA, r"(.*)")

proc newFloat(): float = 0
const floatPattern = r"((?:[-+]?[0-9]*\.?[0-9]+(?:[eE][-+]?[0-9]+)?)|(?:[Nn][Aa][Nn])|(?:[Ii][Nn][Ff])|(?:-[Ii][Nn][Ff]))"
proc parseFloat*(s: string) : float =
  strutils.parseFloat(strutils.toUpper s)
DeclareParamType("float", float, parseFloat, newFloat, floatPattern)

proc newSeqPT*[T]() : seq[T] = newSeq[T]()

DeclareParamType("seq[int]", seq[int], nil, newSeqPT[int], nil)
DeclareParamType("seq[string]", seq[string], nil, newSeqPT[string], nil)
DeclareParamType("seq[bool]", seq[bool], nil, newSeqPT[bool], nil)
DeclareParamType("seq[float]", seq[float], nil, newSeqPT[float], nil)


