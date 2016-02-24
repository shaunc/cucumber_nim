# cucumber/runner.nim

import strutils
import options
import nre
import sequtils
import "./types"
import "./feature"
import "./step"
import "./parameter"

export Scenario, Feature

type
  Library* = ref object
    features*: seq[Feature]
    stepDefinitions*: StepDefinitions

  NoDefinitionForStep* = object of IndexError
    step: Step
    save*: bool

  ScenarioResult* = object
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
    step : Step, stepDefinitions : seq[StepDefinition]) : StepDefinition =
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

proc runScenario(scenario: Scenario) : ScenarioResult
proc runner*(features: Features) : ResultsIter =
  #echo "features " & $features.len
  iterator iresults() : OrdResult {.closure.} =
    var i = 0;
    for feature in features:
      #echo "feature scenarios " & $feature.scenarios.len
      resetContext(ctFeature)
      for scenario in feature.scenarios:
        if scenario.examples.len == 0:
          yield (i, runScenario(scenario))
          i += 1
        else:
          for escenario in exampleScenarios(scenario):
            yield (i, runScenario(escenario))
            i += 1
  return iresults

proc runStep(step: Step) : StepResult
proc runScenario(scenario: Scenario) : ScenarioResult =
  resetContext(ctScenario)
  var sresult = StepResult(value: srSuccess)
  var badstep : Step
  try:
    for i, step in scenario.steps:
      badstep = step
      sresult = runStep(step)
      if sresult.value != srSuccess:
        break
      else:
        badstep = nil
  except NoDefinitionForStep:
    var exc = getCurrentException()
    sresult = StepResult(value: srNoDefinition, exception: exc)
  result = ScenarioResult(
    stepResult: sresult, 
    feature: Feature(scenario.parent), scenario: scenario, step: badstep)

proc fillTable(sd: StepDefinition, stepTable: Examples): void
proc runStep(step: Step) : StepResult =
  #echo "step ", step.text
  let sd = matchStepDefinition(step, stepDefinitions[step.stepType])
  fillTable(sd, step.table)
  var args = StepArgs(stepText: step.text)
  if sd.blockParamName != nil:
    paramTypeStringSetter(ctQuote, sd.blockParamName, step.blockParam)
  result = sd.defn(args)

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
