# cucumber/macroutil

import macros
import strutils

proc pname*(prefix: string, aname: string) : NimNode {.compiletime.} =
  result = postfix(newIdentNode(prefix & capitalize(aname)), "*")
proc newDef*(name: string, dtype: string) : NimNode {.compiletime.} =
  result = newIdentDefs(newIdentNode(name), newIdentNode(dtype))
proc newBrkt*(name: string, idx: string) : NimNode {.compiletime.} = 
  result = newTree(nnkBracketExpr, newIdentNode(name), newIdentNode(idx))
proc newBrkt*(name: string, idx: NimNode) : NimNode {.compiletime.} = 
  result = newTree(nnkBracketExpr, newIdentNode(name), idx)

proc newDot*(a: NimNode, b: string): NimNode {.compiletime.} =
  result = newDotExpr(a, newIdentNode(b))