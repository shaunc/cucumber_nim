# tests/steps/stepDefinitionSteps
#
# Steps for testing step definition

import future
import macros
import tables
import sets
import strutils
import os
import nre
import sequtils
import "../../cucumber"
import "../../cucumber/step"
import "../../cucumber/hook"
import "../../cucumber/parameter"
import "../../cucumber/macroutil"
import "./dynmodule"
import "./ntree"
import "./contextutil"

type
  SR = ref object
    items: seq[string]

  GetDefns = (proc(): StepDefinitions {.nimcall.})
  GetReprs = (proc(): SR {.nimcall.})

  StepTrees = ref object
    items: array[StepType, seq[NTree]]

  StepDefInstrument* = ref object
    module: LibModule
    definitionsP: StepDefinitions
    treesP: StepTrees

proc `[]`*(st: StepTrees, stepType: StepType): var seq[NTree] = 
  st.items[stepType]

proc `[]`*(st: StepTrees, stepType: StepType, istep: int): NTree = 
  st.items[stepType][istep]

proc newStepTrees(): StepTrees =
  StepTrees(items: [newSeq[NTree](), newSeq[NTree](), newSeq[NTree]()])

proc addToTree*(stepTrees: var StepTrees, treeRepr: string) : void =
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
    let last = active[0][^1]
    let stNode = last[1][0][2]
    let stype = stepTypeFor(stNode.content.split()[1][3..^2])
    stepTrees[stype].add(active[0])

proc loadStepDefinitions(stepDefs: StepDefInstrument) =
  let getDefns = bindInLib[GetDefns](stepDefs.module, "getStepDefns")
  var stepDefinitions = getDefns()
  let getStepReprs = bindInLib[GetReprs](stepDefs.module, "getStepReprs")
  let stepReprs = getStepReprs()
  var stepTrees = newStepTrees()
  for srepr in stepReprs.items:
    stepTrees.addToTree(srepr)
  stepDefs.definitionsP = stepDefinitions
  stepDefs.treesP = stepTrees

proc definitions*(stepDefs: StepDefInstrument): StepDefinitions =
  if stepDefs.definitionsP == nil:
    loadStepDefinitions(stepDefs)
  return stepDefs.definitionsP

proc trees*(stepDefs: StepDefInstrument): var StepTrees =
  if stepDefs.treesP == nil:
    loadStepDefinitions(stepDefs)
  return stepDefs.treesP  

DeclareRefParamType(StepDefInstrument)
proc newStepType(): StepType = stGiven
DeclareParamType(
  "StepType", StepType, stepTypeFor, newStepType, r"(\w*)" )


proc `[]`*(
    steps: StepDefInstrument, stepType: StepType, istep: int
    ): StepDefinition =
  assert istep < steps.definitions[stepType].len
  steps.definitions[stepType][istep]

let stepStart = re"""(?m)^(?=Given|When|Then)"""
proc splitSteps(data: string) : seq[string] =
  data.split(stepStart)

let stepSectionTemplate = """
defStep:
$1

saveTree:
$1
"""
## Template for nim module which defines steps


proc newStepDefInstrument(
    libMod: var LibModule, data: string) : StepDefInstrument =

  var strDefs = data.substr.splitSteps
  var defSects = strDefs.map (proc (s:string) : string = 
    let codeText = indentCode(s)
    result = stepSectionTemplate % codeText
  )
  let sectionsText = defSects.join("\n")
  addSource(libMod, sectionsText)
  result = StepDefInstrument(module: libMod)

# ---------------------------------------------------------------------

Given "(?:a )?step definitions?:", (
    quote.data: string,
    scenario.steps: var StepDefInstrument,
    scenario.defMod: var LibModule
    ):
  steps = newStepDefInstrument(defMod, data)

Given "a <stepType> step definition:", (
    quote.data: string,
    stepType: StepType,
    scenario.steps: var StepDefInstrument,
    scenario.defMod: var LibModule
    ):
  discard stepType  
  steps = newStepDefInstrument(defMod, data)

Then r"""I have <nsteps> <stepType> step definitions?""", (
    scenario.steps: StepDefInstrument, 
    nsteps: int, stepType: StepType):
  assert steps.definitions[stepType].len == nsteps

Then r"""step <stepType> (\d+) has pattern \"([^\"]*)\"""", (
    scenario.steps: StepDefInstrument, 
    stepType: StepType, istep: int, 
    pattern: string):
  let step = steps[stepType, istep]
  assert step.stepRE.pattern == pattern

Then r"""step <stepType> (\d+) takes (\d+) arguments from step text.""", (
    scenario.steps: StepDefInstrument, 
    stepType: StepType, istep: int, 
    nargs: int):
  let trees = steps.trees
  let stepTree = trees[stepType, istep]
  let args = getArgsFromNTree(stepTree)
  let targs = args.filterIt(it.atype == ctNotContext)
  assert targs.len == nargs

Then r"""step <stepType> (\d+) takes (\d+) arguments from context.""", (
    scenario.steps: StepDefInstrument, 
    stepType: StepType, istep: int, 
    nargs: int):
  let stepTree = steps.trees[stepType][istep]
  let args = getArgsFromNTree(stepTree)
  let cargs = args.filterIt(it.atype in {ctGlobal, ctFeature, ctScenario})
  assert cargs.len == nargs

Then r"""step <stepType> (\d+) expects <expectsBlock> block.""", (
    scenario.steps: StepDefInstrument, 
    stepType: StepType, istep: int,
    expectsBlock: bool):
  let step = steps[stepType, istep]
  assert bool(step.blockParamName != nil) == expectsBlock
  let stepTree = steps.trees[stepType][istep]
  let args = getArgsFromNTree(stepTree)
  let qargs = args.filterIt(it.name == step.blockParamName)
  assert qargs.len == int(expectsBlock)


proc checkSucceedsOrFails(value: StepResultValue, succeedsOrFails: string) =
  case succeedsOrFails.strip(chars = {'.'})
  of "succeeds":
    assert value == srSuccess
  of "fails":
    assert value == srFail
  else:
    raise newException(
      Exception, "unexpected result type: " & succeedsOrFails)

proc checkRun(step: StepDefinition, args: StepArgs): StepResult =
  try:
    return step.defn(args)
  except:
    let exc = getCurrentException()
    echo "UNEXPECTED EXCEPTION RUNNING SAMPLE STEP: " & exc.msg
    echo exc.getStackTrace
    assert exc.msg == nil

Then r"""running step <stepType> <istep> <succeedsOrFails>\.$""", (
    scenario.steps: StepDefInstrument, 
    scenario.defMod: var LibModule,
    stepType: StepType, istep: int,
    succeedsOrFails: string,
    scenario.contextValues: ContextValues
    ):
  let step = steps[stepType, istep]
  let args = StepArgs(stepText: "a step definition:")
  fillContext(defMod, contextValues)
  let value = checkRun(step, args).value #step.defn(args).value
  checkSucceedsOrFails(value, succeedsOrFails)

Then r"""running step <stepType> <istep> <succeedsOrFails> with text \"([^\"]*)\"""", (
    scenario.steps: StepDefInstrument, 
    scenario.defMod: var LibModule,
    stepType: StepType, istep: int, 
    succeedsOrFails: string,
    stepText: string,
    scenario.contextValues: ContextValues):

  let step = steps[stepType, istep]
  let args = StepArgs(stepText: stepText)
  fillContext(defMod, contextValues)
  let value = checkRun(step, args).value 
  checkSucceedsOrFails(value, succeedsOrFails)

Then r"""step <stepType> <istep> <succeedsOrFails> with block <param>.""", (
    scenario.steps: StepDefInstrument, 
    scenario.defMod: var LibModule,
    stepType: StepType, istep: int,
    succeedsOrFails: string, param: string
    ):
  let step = steps[stepType, istep]
  let formal = getArgsFromNTree(steps.trees[stepType][istep])
  let name = formal[0].name
  let args = StepArgs(stepText: "a step definition:", blockParam: param)
  let setStringContext = bindInLib[SetStringContext](
    defMod, "setStringContext")
  setStringContext("quote", name, param)
  let value = checkRun(step, args).value 
  checkSucceedsOrFails(value, succeedsOrFails)

Then r"""running step <stepType> <istep> fails with error:""", (
    scenario.steps: StepDefInstrument, 
    stepType: StepType, istep: int,
    quote.excText: string):
  let step = steps[stepType, istep]
  let args = StepArgs(stepText: "a failing step definition")
  let stepResult = step.defn(args)
  assert stepResult.value == srFail
  assert stepResult.exception.msg.strip == excText.strip

