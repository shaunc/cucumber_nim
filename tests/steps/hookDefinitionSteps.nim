# package cucumber_nim
# module tests/steps/hookDefinitionSteps

import sets
import tables
import os
import strutils
import sequtils
import nre
import "../../cucumber"
import "../../cucumber/parameter"
import "../../cucumber/feature"
import "../../cucumber/hook"
import "./dynmodule"
import "./contextutil"
import "./ntree"

type
  HR = ref object
    items: seq[string]

  GetDefns = (proc(): HookDefinitions {.nimcall.})
  GetReprs = (proc(): HR {.nimcall.})

  HookTrees = ref object
    items: array[HookType, seq[NTree]]

  HookDefInstrument* = ref object
    module: LibModule
    definitionsP: HookDefinitions
    treesP: HookTrees

proc definitions*(hookDefs: HookDefInstrument) : HookDefinitions
proc `[]`*(
    hooks: HookDefInstrument, hookType: HookType, ihook: int
    ): HookDefinition =
  assert ihook < hooks.definitions[hookType].len
  hooks.definitions[hookType][ihook]

proc newHookType(): HookType = htBeforeAll
DeclareParamType(
  "HookType", HookType, hookTypeFor, newHookType, r"(\w*)" )

proc newStringSet(): StringSet = initSet[string]()
proc parseStringSet(s : string): StringSet =
  (s.split(',').mapIt it.strip).toSet
DeclareParamType(
  "StringSet", StringSet, parseStringSet, newStringSet, r"\{(.*)\}")
DeclareRefParamType(HookDefInstrument)

proc `[]`*(ht: var HookTrees, hookType: HookType): var seq[NTree] = 
  ht.items[hookType]
proc `[]`*(ht: HookTrees, hookType: HookType, istep: int) : NTree =
  ht.items[hookType][istep]

proc newHookTrees(): HookTrees =
  HookTrees(items: [
    newSeq[NTree](), newSeq[NTree](), newSeq[NTree](), newSeq[NTree](),
    newSeq[NTree](), newSeq[NTree](), newSeq[NTree](), newSeq[NTree](),
    ])

proc addToTree*(hookTrees: var HookTrees, treeRepr: string) : void =
  var active: seq[NTree] = @[]
  for line in treeRepr.split("\n"):
    let nindent = ((line.match re"^\s*").get.match.len) div 2
    let node = NTree(content: line.strip, children: newSeq[NTree]())
    if nindent >= active.len:
      active.add(node)
    else:
      active[nindent] = node
      setLen(active, nindent + 1)
    if nindent > 0:
      active[nindent - 1].children.add(node)
  if active.len > 0:
    # retrieve hook type from call to add hook to definitions
    let last = active[0][^1]
    let hkNode = last[1][0][2]
    let stype = hookTypeFor(hkNode.content.split()[1][3..^2])
    hookTrees[stype].add(active[0])

let hookSectionTemplate = """
defHook:
$1

saveHookTree:
$1
"""

let hookStartRE = (
  re"""(?m)^(?=(?:Before|After)(?:All|Feature|Scenario|Step))""" )
proc splitHooks(data: string) : seq[string] =
  data.split(hookStartRE)

proc newHookDefInstrument(
    libMod: var LibModule, data: string): HookDefInstrument =

  var strDefs = data.substr.splitHooks
  var defSects = strDefs.map (proc (s:string) : string = 
    let text = indentCode(s)
    result =  hookSectionTemplate % text)
  let sectionsText = defSects.join("\n")
  addSource(libMod, sectionsText)
  result = HookDefInstrument(module: libMod)


proc loadHookDefinitions(hookDefs: HookDefInstrument) = 
  let getDefns = bindInLib[GetDefns](hookDefs.module, "getHookDefns")
  var hookDefinitions = getDefns()
  let getHookReprs = bindInLib[GetReprs](hookDefs.module, "getHookReprs")
  let hookReprs = getHookReprs()
  var hookTrees = newHookTrees()
  for hrepr in hookReprs.items:
    hookTrees.addToTree(hrepr)
  hookDefs.definitionsP = hookDefinitions
  hookDefs.treesP = hookTrees

proc definitions*(hookDefs: HookDefInstrument) : HookDefinitions =
  if hookDefs.definitionsP == nil:
    loadHookDefinitions(hookdefs)
  return hookDefs.definitionsP

proc trees*(hookDefs: HookDefInstrument) : HookTrees =
  if hookDefs.treesP == nil:
    loadHookDefinitions(hookdefs)
  return hookDefs.treesP

# ---------------------------------------------------------------------


Given "a <hookType> hook definition:", (
    quote.data: string, hookType: HookType, 
    scenario.hooks: var HookDefInstrument,
    scenario.defMod: var LibModule
    ):
  discard hookType
  hooks = newHookDefInstrument(defMod, data)
  
Given "(?:a )?hook definitions?:", (
    quote.data: string, 
    scenario.hooks: var HookDefInstrument,
    scenario.defMod: var LibModule
    ):
  hooks = newHookDefInstrument(defMod, data)

Then r"""I have <nhooks> <hookType> hook definitions?""", (
    scenario.hooks: HookDefInstrument, 
    nhooks: int, hookType: HookType):
  assert hooks.definitions[hookType].len == nhooks

Then r"""hook <hookType> <ihook> takes <nargs> arguments from context.""", (
    scenario.hooks: HookDefInstrument, 
    hookType: HookType, ihook: int, 
    nargs: int):
  let hookTree = hooks.trees[hookType, ihook]
  let args = getArgsFromNTree(hookTree)
  let cargs = args.filterIt(it.atype in {ctGlobal, ctFeature, ctScenario})
  assert cargs.len == nargs

Then r"""hook <hookType> <ihook> has no tags""", (
    scenario.hooks: HookDefInstrument, 
    hookType: HookType, ihook: int, 
    ):
  let hookTree = hooks.trees[hookType, ihook]
  let tagExpr = hookTree[0][^2][1]
  assert tagExpr.content.split()[1] == "1"

proc fillHookArgs(hookType: HookType) : (Feature, Scenario, Step) =
  var feature = Feature()
  var scenario = Scenario(parent: feature)
  var step = Step(parent: scenario)
  case hookType
    of htBeforeAll, htAfterAll: 
      feature = nil
      scenario = nil
      step = nil
    of htBeforeFeature, htAfterFeature:
      scenario = nil
      step = nil
    of htBeforeScenario, htAfterScenario:
      step = nil
    else:
      discard  

proc checkRun(
    hook: HookDefinition, 
    feature: Feature, scenario: Scenario, step: Step,
    excMessage: string = nil
    ): void =
  var exc: ref Exception
  try:
    hook.defn(feature, scenario, step)
  except:
    if excMessage == "*":
      return
    exc = getCurrentException()
    echo "EXC " & exc.msg
    if excMessage == nil or excMessage.strip != exc.msg.strip:
      echo "UNEXPECTED EXCEPTION RUNNING SAMPLE HOOK: " & exc.msg
      echo exc.getStackTrace
      assert exc.msg == nil
  if excMessage != nil and exc == nil:
    raise newException(AssertionError, "expecting exception: " & excMessage)

Then "running hook <hookType> <ihook> succeeds.", (
    scenario.hooks: HookDefInstrument, 
    scenario.defMod: LibModule,
    hookType: HookType, ihook: int, 
    scenario.contextValues: ContextValues
    ):
  let hook = hooks[hookType, ihook]
  let (feature, scenario, step) = fillHookArgs(hookType)
  fillContext(defMod, contextValues)
  checkRun(hook, feature, scenario, step)

Then "running hook <hookType> <ihook> fails.", (
    scenario.hooks: HookDefInstrument, 
    scenario.defMod: LibModule,
    hookType: HookType, ihook: int, 
    scenario.contextValues: ContextValues
    ):
  let hook = hooks[hookType, ihook]
  let (feature, scenario, step) = fillHookArgs(hookType)
  fillContext(defMod, contextValues)
  checkRun(hook, feature, scenario, step, "*")

Then "running hook <hookType> <ihook> fails with message:", (
    quote.message: string,
    scenario.defMod: LibModule,
    scenario.hooks: HookDefInstrument, 
    hookType: HookType, ihook: int, 
    scenario.contextValues: ContextValues
    ):
  let hook = hooks[hookType, ihook]
  let (feature, scenario, step) = fillHookArgs(hookType)
  fillContext(defMod, contextValues)
  checkRun(hook, feature, scenario, step, message)

Then "hook <hookType> <ihook> tag filter (matches|doesn't match) <tagSet>", (
    scenario.hooks: HookDefInstrument, 
    hookType: HookType, ihook: int, 
    matches: string, tagSet: StringSet):

  let matches = matches == "matches"
  let hook = hooks[hookType, ihook]
  assert hook.tagFilter(tagSet) == matches
