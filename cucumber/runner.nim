# cucumber/runner.nim

import future
import sets
import strutils
import options
import nre
import sequtils
import "./types"
import "./feature"
import "./parameter"
import "./step"
import "./hook"

export Scenario, Feature

type
  Library* = ref object
    features*: seq[Feature]
    stepDefinitions*: StepDefinitions

  NoDefinitionForStep* = object of IndexError
    step: Step
    save*: bool

  ScenarioResult* = ref object
    stepResult*: StepResult
    feature*: Feature
    scenario*: Scenario
    step*: Step

  OrdResult* = tuple[iscenario: int, sresult: ScenarioResult]
  ResultsIter* = iterator(): OrdResult {.closure.}

proc newNoDefinitionForStep(
    step: Step, msg: string, save: bool = true) : ref NoDefinitionForStep =
  let msg = "line: $1: $2" % [$step.lineNumber, msg]
  result = newException(NoDefinitionForStep, msg)
  result.step = step
  result.save = save

proc matchStepDefinition(
    step : Step, stepDefinitions : seq[StepDefinition],
    options: CucumberOptions) : StepDefinition =
  for defn in stepDefinitions:
    var isMatch = step.text.match(defn.stepRE)
    #echo step.text, defn.stepRE.pattern, isMatch.isSome
    if isMatch.isSome:
      if defn.blockParamName != nil and step.blockParam == nil:
        raise newNoDefinitionForStep(
          step, "Step definition expects block parameter.")
      if defn.blockParamName == nil and step.blockParam != nil:
        raise newNoDefinitionForStep(
          step, "Step definition does not take block parameter.")
      return defn

  if options.verbosity > 0:
    echo "No definition matching \"" & step.text & "\""
  raise newNoDefinitionForStep(
    step, "No definition matching \"" & step.text & "\"", save = false)

iterator exampleLines(examples: seq[Examples]): TableLine =
  var columns = newSeq[string]()
  var bounds = newSeq[int]()
  var indexes = newSeq[int]()
  for example in examples:
    columns.add(example.columns)
    bounds.add(example.values.len)
    indexes.add(0)

  var iex = high(examples)
  while iex >= 0:
    let line = TableLine(columns: columns, values: newSeq[string]())
    for iex, icol in indexes:
      line.values.add(examples[iex].values[icol])
    yield line
    while iex >= 0 and indexes[iex] + 1 == bounds[iex]:
      iex -= 1
    if iex == -1:
      break
    indexes[iex] += 1
    while iex < high(examples):
      iex += 1
      indexes[iex] = 0

proc subsTableLine(text: string, line: TableLine): string =
  if text != nil:
    result = text.substr
    for i, column in line.columns:
      result = result.replace("<$1>" % column, line.values[i])

iterator exampleScenarios(
    scenario: Scenario) : Scenario =
  for row in exampleLines(scenario.examples):
    let description = subsTableLine(scenario.description, row)
    let steps = scenario.steps.mapIt Step(
      description: subsTableLine(it.description, row),
      parent: scenario.parent,
      tags: scenario.tags,
      comments: scenario.comments,
      stepType: it.stepType, 
      text: subsTableLine(it.text, row),
      blockParam: subsTableLine(it.blockParam, row),
      lineNumber: it.lineNumber,
      table: it.table)
    yield Scenario(
      description: description,
      tags: scenario.tags,
      comments: scenario.comments,
      parent: scenario.parent,
      steps: steps,
      examples: newSeq[Examples]()
      )

proc runHooks(
    hookType: HookType, tags: StringSet, testNode: TestNode): HookResult
proc runScenario(scenario: Scenario, options: CucumberOptions) : ScenarioResult
iterator runFeature(
    feature: Feature, options: CucumberOptions): OrdResult =

  if options.verbosity > 0:
    echo "feature \"$1\" scenarios $2" % [
      feature.description, $feature.scenarios.len ]
  resetContext(ctFeature)
  let hookResult = runHooks(htBeforeFeature, feature.tags, feature)
  if hookResult.value != hrSuccess:
    let sresult = ScenarioResult(
      stepResult: StepResult(value: srFail, hookResult: hookResult))
    yield (0, sresult)
  else:
    var i = 0
    for scenario in feature.scenarios:
      if scenario.examples.len == 0:
        yield (i, runScenario(scenario, options))
        i += 1
      else:
        for escenario in exampleScenarios(scenario):
          yield (i, runScenario(escenario, options))
          i += 1
    let afterHookResult = runHooks(htAfterFeature, feature.tags, feature)
    if afterHookResult.value != hrSuccess:
      let sresult = ScenarioResult(
        stepResult: StepResult(value: srFail, hookResult: afterHookResult))
      yield (i, sresult)

proc runner*(features: Features, options: CucumberOptions) : ResultsIter =
  if options.verbosity > 0:
    echo "features: " & $features.len
  iterator iresults() : OrdResult {.closure.} =
    var i = 0;
    let hookResult = runHooks(htBeforeAll, initSet[string](), nil)
    if hookResult.value != hrSuccess:
      let sresult = ScenarioResult(
        stepResult: StepResult(value: srFail, hookResult: hookResult))
      yield (0, sresult)
      return
    for feature in features:
      for j, sresult in runFeature(feature, options):
        yield (i, sresult)
        i += 1
    let afterHookResult = runHooks(htAfterAll, initSet[string](), nil)
    if afterHookResult.value != hrSuccess:
      let sresult = ScenarioResult(
        stepResult: StepResult(value: srFail, hookResult: afterHookResult))
      yield (i, sresult)

  return iresults

proc runStep(
    tags: StringSet, step: Step, options: CucumberOptions) : StepResult
proc runScenario(
    scenario: Scenario, options: CucumberOptions) : ScenarioResult =

  let feature = Feature(scenario.parent)
  var sresult = StepResult(value: srSuccess)
  result = ScenarioResult(
    stepResult: sresult, feature: feature, scenario: scenario)
  let tags = scenario.tags + scenario.parent.tags
  if options.verbosity > 1:
    echo "  scenario \"$1\": $2" % [scenario.description, $tags]
  if not options.tagFilter(tags):
    if not ("@skip" in tags):
      return nil
    sresult.value = srSkip
    return
  resetContext(ctScenario)
  var badstep : Step
  let hookResult = runHooks(htBeforeScenario, tags, scenario)
  if hookResult.value != hrSuccess:
    sresult.hookResult = hookResult
    sresult.value = srFail
    return result
  try:
    for i, step in scenario.steps:
      badstep = step
      sresult = runStep(tags, step, options)
      if sresult.value != srSuccess:
        break
      else:
        badstep = nil
  except:
    var exc = getCurrentException()
    let value = if exc of NoDefinitionForStep: srNoDefinition else: srFail
    sresult = StepResult(value: value, exception: exc)
    result.stepResult = sresult
  finally:
    sresult.hookResult = runHooks(htAfterScenario, tags, scenario)
    if sresult.hookResult.value == hrFail:
      sresult.value = srFail
  result.step = badstep

proc fillTable(sd: StepDefinition, stepTable: Examples): void
proc runStep(
    tags: StringSet, step: Step, options: CucumberOptions) : StepResult =

  if options.verbosity > 2:
    echo "    step ", step.text
  let sd = matchStepDefinition(step, stepDefinitions[step.stepType], options)
  fillTable(sd, step.table)
  let hookResult = runHooks(htBeforeStep, tags, step)
  if hookResult.value != hrSuccess:
    return StepResult(value: srFail, hookResult: hookResult)
  result = StepResult(value: srSuccess)
  var args = StepArgs(stepText: step.text)
  if sd.blockParamName != nil:
    paramTypeStringSetter(ctQuote, sd.blockParamName, step.blockParam)
  try:
    result = sd.defn(args)
  finally:
    result.hookResult = runHooks(htAfterStep, tags, step)
    if result.hookResult.value == hrFail:
      result.value = srFail

iterator count(a, b: int) : int =
  if a >= 0 and b >= 0:
    if a < b:
      for i in countUp(a, b):
        yield i
    else:
      for i in countDown(a, b):
        yield i

proc runHooks(
    hookType: HookType, tags: StringSet, testNode: TestNode): HookResult =
  result = HookResult(value: hrSuccess)
  let definitions = hookDefinitions[hookType]
  var dfrom, dto: int
  if hookType in {htAfterAll, htAfterFeature, htAfterScenario, htAfterStep}:
    (dfrom, dto) = (definitions.high, definitions.low)
  else:
    (dfrom, dto) = (definitions.low, definitions.high)
  for ihookDef in count(dfrom, dto):
    let hookDef = definitions[ihookDef]
    if not hookDef.tagFilter(tags):
      continue
    try:
      case hookType
      of htBeforeAll, htAfterAll:
        hookDef.defn(nil, nil, nil)
      of htBeforeFeature, htAfterFeature:
        hookDef.defn(Feature(testNode), nil, nil)
      of htBeforeScenario, htAfterScenario:
        hookDef.defn(Feature(testNode.parent), Scenario(testNode), nil)
      of htBeforeStep, htAfterStep:
        hookDef.defn(
          Feature(testNode.parent.parent), Scenario(testNode.parent), 
          Step(testNode))
    except:
      let exc = getCurrentException()
      result.value = hrFail
      result.exception = exc
      break

#TODO
proc fillTable(sd: StepDefinition, stepTable: Examples): void =
  discard

when isMainModule:

  Given "a simple feature file:", (quote.data: string):
    echo "file len " & $data.len

  var features : seq[Feature] = @[]
  loadFeature(features, stdin)
  var results = runner(features)
  echo $results.len
