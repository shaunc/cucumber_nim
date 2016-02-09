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
from typeinfo import nil
from strutils import capitalize


const ptPrefix = "paramType"

# system builtins need wrappers to store as fct pointers
proc getInt(a : typeinfo.Any) : int = result = typeinfo.getInt(a)
proc getBool(a : typeinfo.Any) : bool = result = typeinfo.getBool(a)
proc getString(a: typeinfo.Any) : string = result = typeinfo.getString(a)

proc parseBool(s: string) : bool = result = strutils.parseBool(s)
proc parseString(s: string) : string = result = s

template ptID*(name: string, suffix: string) : untyped = 
  newIdentNode(ptPrefix & capitalize(name) & capitalize(suffix))

template ptIDPub(name: string, suffix: string) : untyped = 
  postfix(ptID(name, suffix), "*")


macro makeParameterType*(
    name : static[string], 
    ptype: typed,
    parseFct: typed,
    getFct: typed,
    pattern: string,
    ) : typed =
  ## create declarations for a parameter type
  ## `name`: name of the parameter type
  ## `ptype`: actual type of parameter
  ## `parseFct`: function that parses a string and returns `ptype` instance
  ## `getFct`: function that takes `Any` and returns `ptype` instance (
  ##   used for lookup of context parameter).
  ##
  ## for call ``makeParameterType("int", int, parseInt, getInt, r"(-?\d+)")``,
  ## this will generate:
  ## ``nim
  ##   const paramTypeIntName = "int"
  ##   const paramTypeIntType = int
  ##   const paramTypeIntParseFct = parseInt
  ##   const paramTypeIntGetFct = getInt
  ##   const paramTypeIntPattern = r"(-?\d+)"
  ## ```
  
  let iptName = ptIDPub(name, "name")
  let iptType = ptIDPub(name, "type")
  let iptParseFct = ptIDPub(name, "parseFct")
  let iptGetFct = ptIDPub(name, "getFct")
  let iptPattern = ptIDPub(name, "pattern")
  result = newStmtList(
    newConstStmt(iptName, newLit(name)),
    newConstStmt(iptType, ptype),
    newConstStmt(iptParseFct, parseFct),
    newConstStmt(iptGetFct, getFct),
    newConstStmt(iptPattern, pattern)
    )

makeParameterType("int", int, strutils.parseInt, getInt, r"(-?\d+)")
makeParameterType(
  "bool", bool, parseBool, getBool, 
  r"((?:true)|(?:false)|(:yes)|(:no))")
makeParameterType("str", string, parseString, getString, r"(.*)")

## `blockParam` type is special: string filled from step block parameter
makeParameterType("blockParam", string, parseString, getString, nil)
