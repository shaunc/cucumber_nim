# package: cucumber_nim
# module ntree.nim
#
##[
 NTrees are simplified stand-ins for NimNodes, derived
 from "dumpTree". They owe their existence to the fact that I
 could not get ahold of the actual NimNodes from a dynamically
 loaded module, but could get a hold of the string from "treeRepr".
]##

import sequtils
import strutils
import nre
import options
import "../../cucumber/types"

type
  NTree* = ref NTreeObj
  NTreeObj* = object
    content*: string
    children*: seq[NTree]

proc `[]`*(nt: NTree, i: int) : NTree = nt.children[i]

proc len*(nt: NTree) : int = nt.children.len

proc `$`*(nt: NTree, indent: int = 0) : string =
  result = repeat(" ", indent) & nt.content & "\n"
  for child in nt.children:
    result = result & `$`(child, indent + 2)

let symRE = re"""\"(.*)\""""
proc getSym*(nt: NTree): string =
  try:
    return nt.content.find(symRE).get.captures[0]
  except Exception:
    raise newException(ValueError, "Couldn't get symbol from " & nt.content)

type
  ArgDesc* = tuple
    name: string
    atype: ContextType

proc getArgsFromNTree*(nt : NTree) : seq[ArgDesc] =
  var procStart: NTree
  if nt[1][^2].content != "Empty":
    procStart = nt[1][^2][1][1]
  else:
    procStart = nt[1][^1]
  let children = procStart[0].children
  result = @[]
  for child in children:
    let name = child[0].getSym
    var ncall = child[2]
    if ncall.content == "HiddenDeref":
      ncall = ncall[0]
    let fct = ncall[0].getSym
    var ctype: ContextType
    if fct == "paramTypeIntGetter":
      ctype = ctGlobal
    else:
      ctype = ctNotContext
    result.add((name, ctype))
