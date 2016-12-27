# cucumber/macroutil

import macros
import strutils
import sequtils

proc pubName*(prefix: string, aname: string) : NimNode {.compiletime.} =
  let name : string = if prefix == nil: aname else: prefix & capitalizeAscii(aname)
  result = postfix(newIdentNode(name), "*")
proc toTypeNode(atype: NimNode, isVar: bool = false): NimNode {.compiletime.} =
  result = atype
  if isVar:
    result = newTree(nnkVarTy, result)
proc toTypeNode(atype: string, isVar: bool = false): NimNode {.compiletime.} =
  result = toTypeNode(newIdentNode(atype), isVar)
proc newDef*(
    name: string, dtype: string, isVar: bool = false) : NimNode {.compiletime.} =
  var nType = toTypeNode(dtype, isVar)
  result = newIdentDefs(newIdentNode(name), nType)
  
proc newBrkt*(name: string, idx: string) : NimNode {.compiletime.} = 
  result = newTree(nnkBracketExpr, newIdentNode(name), newIdentNode(idx))
proc newBrkt*(name: string, idx: NimNode) : NimNode {.compiletime.} = 
  result = newTree(nnkBracketExpr, newIdentNode(name), idx)
proc newBrkt*(name: NimNode, idx: string) : NimNode {.compiletime.} = 
  result = newTree(nnkBracketExpr, name, newIdentNode(idx))
proc newBrkt*(name: NimNode, idx: NimNode) : NimNode {.compiletime.} = 
  result = newTree(nnkBracketExpr, name, idx)

proc newDot*(a, b: string): NimNode {.compiletime.} =
  result = newDotExpr(newIdentNode(a), newIdentNode(b))
proc newDot*(a: NimNode, b: string): NimNode {.compiletime.} =
  result = newDotExpr(a, newIdentNode(b))

proc newColon*(a, b: string): NimNode {.compiletime.} =
  newColonExpr(newIdentNode(a), newIdentNode(b))

proc newCast*(node: NimNode, toType: string, isVar: bool = false) : NimNode {.compiletime.} =
  var nType = toTypeNode(toType, isVar)
  result = newTree(nnkCast, nType, node)  
proc newCast*(node: NimNode, toType: NimNode, isVar: bool = false) : NimNode {.compiletime.} =
  var nType = toTypeNode(toType, isVar)
  result = newTree(nnkCast, nType, node)  
proc newCast*(name: string, toType: string, isVar: bool = false) : NimNode {.compiletime.} =
  result = newCast(newIdentNode(name), toType, isVar)
proc newCast*(name: string, toType: NimNode, isVar: bool = false) : NimNode {.compiletime.} =
  result = newCast(newIdentNode(name), toType, isVar)

proc maybeExport(name: string, isExport : bool = false) : NimNode {.compiletime.}=
  result = newIdentNode(name)
  if isExport:
    result = postfix(result, "*")

proc newVar*[T](name: string, t: T) : NimNode {.compiletime.} =
  result = newVarStmt(newIdentNode(name), newLit(t))

proc newDef(
    kind: NimNodeKind, name: string, vtype: string, val: NimNode = newEmptyNode(),
    isExport: bool = false
    ) : NimNode {.compiletime.} =
  var nname = maybeExport(name, isExport)
  var ntype = if vtype == nil: newEmptyNode() else: newIdentNode(vtype)
  newTree(
    kind, newIdentDefs(nname, ntype, val))

proc newDef(
    kind: NimNodeKind, name: string, vtype: NimNode, val: NimNode = newEmptyNode(), 
    isExport : bool = false 
    ) : NimNode {.compiletime.} =
  let vtypeName = if vtype.kind == nnkNilLit: nil else: $vtype
  result = newDef(kind, name, vtypeName, val, isExport)
  
proc newDef(
    kind: NimNodeKind, name: string, vtype: string, val: string,
    isExport : bool = false
    ) : NimNode {.compiletime.} =
  newDef(kind, name, vtype, newIdentNode(val), isExport)

proc newVar*(
    name: string, vtype: string, val: NimNode = newEmptyNode(), 
    isExport : bool = false
    ) : NimNode {.compiletime.} =
  newDef(nnkVarSection, name, vtype, val, isExport)
proc newVar*(
    name: string, vtype: NimNode, val: NimNode = newEmptyNode(), 
    isExport : bool = false 
    ) : NimNode {.compiletime.} =
  newDef(nnkVarSection, name, vtype, val, isExport)
proc newVar*(
    name: string, vtype: string, val: string,
    isExport : bool = false
    ) : NimNode {.compiletime.} =
  newDef(nnkVarSection, name, vtype, val, isExport)

proc newLet*(
    name: string, vtype: string, val: NimNode = newEmptyNode(), 
    isExport : bool = false
    ) : NimNode {.compiletime.} =
  newDef(nnkLetSection, name, vtype, val, isExport)
proc newLet*(
    name: string, vtype: NimNode, val: NimNode = newEmptyNode(), 
    isExport : bool = false 
    ) : NimNode {.compiletime.} =
  newDef(nnkLetSection, name, vtype, val, isExport)
proc newLet*(
    name: string, vtype: string, val: string,
    isExport : bool = false
    ) : NimNode {.compiletime.} =
  newDef(nnkLetSection, name, vtype, val, isExport)

proc newConst*(
    name: string, vtype: string, val: NimNode = newEmptyNode(), 
    isExport : bool = false
    ) : NimNode {.compiletime.} =
  newDef(nnkConstSection, name, vtype, val, isExport)
proc newConst*(
    name: string, vtype: NimNode, val: NimNode = newEmptyNode(), 
    isExport : bool = false 
    ) : NimNode {.compiletime.} =
  newDef(nnkConstSection, name, vtype, val, isExport)
proc newConst*(
    name: string, vtype: string, val: string,
    isExport : bool = false
    ) : NimNode {.compiletime.} =
  newDef(nnkConstSection, name, vtype, val, isExport)


proc mShow*(n : NimNode) : void =
  echo n.toStrLit.strVal

macro mNewVar*(
    name: static[string], vtype: untyped, val: untyped
    ) : untyped =
  result = newVar(name, vtype, val, false)
macro mNewVarExport*(
    name: static[string], vtype: untyped, val: untyped
    ) : untyped =
  result = newVar(name, vtype, val, true)

macro mNewLet*(
    name: static[string], vtype: untyped, val: untyped
    ) : untyped =
  result = newLet(name, vtype, val, false)
macro mNewLetExport*(
    name: static[string], vtype: untyped, val: untyped
    ) : untyped =
  result = newLet(name, vtype, val, true)

macro mNewConst*(
    name: static[string], vtype: untyped, val: untyped
    ) : untyped =
  result = newConst(name, vtype, val, false)
macro mNewConstExport*(
    name: static[string], vtype: untyped, val: untyped
    ) : untyped =
  result = newConst(name, vtype, val, true)


proc newType*(
    name: string, ttype: NimNode, isExport: bool = false
    ): NimNode {.compiletime.} =
  var nname = maybeExport(name, isExport)
  result = newTree(nnkTypeSection, newTree(
    nnkTypeDef, nname, newEmptyNode(), ttype))

macro mNewTypeExport*(
    name: static[string], ttype: untyped) : untyped = 
  newType(name, ttype, true)

macro toCode*(n: NimNode) : untyped = n

macro nameOfNim*(n: untyped) : untyped = 
  newLit($n)


