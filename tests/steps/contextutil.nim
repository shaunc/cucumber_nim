# package: cucumber_nim
# module tests/steps/contextutil

##[

  Some utilities for manipulating step contexts in dynamically loaded modules.

  Used to check step and hook definitions.

]##

import tables
import dynlib
import "../../cucumber/types"
import "../../cucumber/parameter"
import "../../cucumber/step"
import "./dynmodule"


type
  SetIntContext* = (proc(context: string, param: string, value: int): void {.nimcall.})
  GetIntContext* = (proc(context: string, param: string): int {.nimcall.})
  SetStringContext* = (proc(context: string, param: string, value: string): void {.nimcall.})

  QualName* = tuple
    context: string
    name: string
  ContextValues* = TableRef[QualName, int]

DeclareRefParamType(ContextValues)

proc fillContext*(
    lib: LibModule, contextValues: ContextValues
    ): void =

  if contextValues != nil:
    let setIntContext = bindInLib[SetIntContext](
      lib, "setIntContext")
    for qname, value in contextValues:
      setIntContext(qname.context, qname.name, value)

When "<context> context parameter <param> is <value>$", (
    context: string, param: string, value: int,
    scenario.contextValues: var ContextValues):

  let qname : QualName = (context, param)
  if contextValues == nil:
    contextValues = newTable[QualName, int]()
  contextValues[qname] = value

Then r"""<context> context parameter <param> is <value>""", (
    scenario.defMod: LibModule,
    context: string, param: string, value: int):
  let getIntContext = bindInLib[GetIntContext](
    defMod, "getIntContext")
  let actualValue = getIntContext(context, param)
  assert actualValue == value

