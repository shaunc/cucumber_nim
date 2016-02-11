# cucumber/parameter.nim
#
## Defines types of parameters to pass values to steps
## from scenario definitions and context initialized by hooks.
##
## Parameters form scenario definitions start as strings; from
## context, they start as typed values. Step definition wrappers
## take an sequences of "Any" and unpack the values int the wrapper.
##
## Parameter type objects have names of functions to use for
## parsing and unpacking. These are used at compile time by step
## and hook macros. Because of this, new parameter types must be 
## added before step and hook definitions are processed.

import tables
import macros
from typeinfo import Any, toAny, assign
from strutils import capitalize
import macroutil

type
  Context* = Table[string, Any]


const ptPrefix = "paramType"

# system builtins need wrappers to store as fct pointers
proc getInt(a : Any) : int = result = typeinfo.getInt(a)
proc getBool(a : Any) : bool = result = typeinfo.getBool(a)
proc getString(a: Any) : string = result = typeinfo.getString(a)

proc setInt(a : Any, v: int) : void = 
  var v = v;
  assign(a, toAny[int](v))
proc setBool(a : Any, v: bool) : void = 
  var v = v;
  assign(a, toAny[bool](v))
proc setString(a: Any, v: string) : void = 
  typeinfo.setString(a, v)

proc parseBool(s: string) : bool = result = strutils.parseBool(s)
proc parseString(s: string) : string = result = s

template ptID*(name: string, suffix: string) : untyped = 
  newIdentNode(ptPrefix & capitalize(name) & capitalize(suffix))

template ptIDPub(name: string, suffix: string) : untyped = 
  postfix(ptID(name, suffix), "*")

macro declarePT*(
    name : static[string], 
    ptype: typed,
    parseFct: typed,
    getFct: typed,
    setFct: typed,
    pattern: string,
    default: untyped
    ) : typed =
  ## create declarations for a parameter type
  ## `name`: name of the parameter type
  ## `ptype`: actual type of parameter
  ## `parseFct`: function that parses a string and returns `ptype` instance
  ## `getFct`: function that takes `Any` and returns `ptype` instance (
  ##   used for lookup of context parameter).
  ##
  ## for call ``declarePT("int", int, parseInt, getInt, setInt, r"(-?\d+)", -99)``,
  ## this will generate:
  ## ```nim
  ##   const paramTypeIntName* = "int"
  ##   const paramTypeIntType* = int
  ##   const paramTypeIntParseFct* = parseInt
  ##   const paramTypeIntGetFct* = getInt
  ##   const paramTypeIntPattern* = r"(-?\d+)"
  ##   const paramTypeIntDefault* = -99
  ##   proc getInt*(context: Context, key: string) : int =
  ##     result = if hasKey(context, key): getInt(context[key]) else: -99
  ##   proc setInt*(context: Context, key: string, val: int) : void = 
  ##     setInt(context[key], val)
  ##   proc resetInt*(context: Context, key: string) : void = 
  ##     setInt(context[key], -99)
  ## ```
  if name == nil:
    echo callsite().toStrLit.strVal
    raise newException(Exception, "AHH")
  let iptName = ptIDPub(name, "name")
  let iptType = ptIDPub(name, "type")
  let iptParseFct = ptIDPub(name, "parseFct")
  let iptGetFct = ptIDPub(name, "getFct")
  let iptSetFct = ptIDPub(name, "setFct")
  let iptPattern = ptIDPub(name, "pattern")
  let iptDefault = ptIDPub(name, "default")
  let nVoid = newIdentNode("void")
  result = newStmtList(
    newConstStmt(iptName, newLit(name)),
    newConstStmt(iptType, ptype),
    newConstStmt(iptParseFct, parseFct),
    newConstStmt(iptGetFct, getFct),
    newConstStmt(iptSetFct, setFct),
    newConstStmt(iptPattern, pattern),
    newConstStmt(iptDefault, default),
    newProc(
      pname("get", name),
      [ ptype, newDef("context", "Context"), newDef("key", "string")],
      newStmtList(
        newAssignment(
          newIdentNode("result"), 
          newTree(nnkIfExpr, 
            newTree(
              nnkElifExpr,
              newCall(
                newIdentNode("hasKey"), newIdentNode("context"), newIdentNode("key")),
              newCall(getFct, newTree(
                nnkBracketExpr, newIdentNode("context"), newIdentNode("key")))),
            newTree(nnkElseExpr, default.copy))))),
    newProc(
      pname("set", name),
      [ nVoid.copy, newDef("context", "Context"), newDef("key", "string"),
        newDef("val", $ptype)],
      newStmtList(
        newCall(setFct, newBrkt("context", "key"), newIdentNode("val")))),
    newProc(
      pname("reset", name),
      [ nVoid.copy, newDef("context", "Context"), newDef("key", "string")],
      newStmtList(
        newCall(setFct, newBrkt("context", "key"), default.copy)))
    )

declarePT("int", int, strutils.parseInt, getInt, setInt, r"(-?\d+)", 0)

declarePT(
  "bool", bool, parseBool, getBool, setBool,
  r"((?:true)|(?:false)|(:yes)|(:no))", false)
declarePT("str", string, parseString, getString, setString, r"(.*)", nil)

## `blockParam` type is special: string filled from step block parameter
declarePT("blockParam", string, parseString, getString, setString, nil, nil)
