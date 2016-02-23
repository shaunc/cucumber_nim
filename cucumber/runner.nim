# cucumber/runner.nim

import strutils
import options
import nre
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

  ScenarioResults* = seq[ScenarioResult]

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

proc runScenario(scenario: Scenario, exampleLine: TableLine = nil) : ScenarioResult

iterator exampleLines(examples: seq[Examples]): TableLine =
  var columns = newSeq[string]()
  var bounds = newSeq[int]()
  var indexes = newSeq[int]()
  for example in examples:
    columns.add(example.columns)
    bounds.add(example.values.len)
    indexes.add(0)

  proc buildLine(): TableLine = 
    result = TableLine(columns: columns, values: newSeq[string]())
    for iex, icol in indexes:
      result.values.add(examples[iex].values[icol])

  var iex = high(examples)
  while iex >= 0:
    yield buildLine()
    while iex >= 0 and indexes[iex] == bounds[iex]:
      iex -= 1
    if iex == -1:
      break
    indexes[iex] += 1
    while iex < high(examples):
      iex += 1
      indexes[iex] = 0

proc runner*(features: seq[Feature]) : ScenarioResults =
  #echo "features " & $features.len
  result = @[]
  for feature in features:
    #echo "feature scenarios " & $feature.scenarios.len
    resetContext(ctFeature)
    for scenario in feature.scenarios:
      if scenario.examples.len == 0:
        result.add(runScenario(scenario))
      else:
        for tline in exampleLines(scenario.examples):
          result.add(runScenario(scenario, tline))

proc runStep(step: Step, exampleLine: TableLine) : StepResult
proc runScenario(
    scenario: Scenario, exampleLine: TableLine = nil) : ScenarioResult =
  resetContext(ctScenario)
  var sresult = StepResult(value: srSuccess)
  var badstep : Step
  try:
    for i, step in scenario.steps:
      sresult = runStep(step, exampleLine)
      if sresult.value != srSuccess:
        badstep = step
        break
      else:
        badstep = nil
  except NoDefinitionForStep:
    var exc = getCurrentException()
    sresult = StepResult(value: srNoDefinition, exception: exc)
  result = ScenarioResult(
    stepResult: sresult, 
    feature: Feature(scenario.parent), scenario: scenario, step: badstep)

proc fillExamples(sd: StepDefinition, exampleLine: TableLine): void
proc fillTable(sd: StepDefinition, stepTable: Examples): void
proc runStep(step: Step, exampleLine: TableLine) : StepResult =
  #echo "step ", step.text
  let sd = matchStepDefinition(step, stepDefinitions[step.stepType])
  fillExamples(sd, exampleLine)
  fillTable(sd, step.table)
  var args = StepArgs(stepText: step.text)
  if sd.blockParamName != nil:
    paramTypeStringSetter(ctQuote, sd.blockParamName, step.blockParam)
  result = sd.defn(args)

#TODO
proc fillExamples(sd: StepDefinition, exampleLine: TableLine): void = 
  discard
proc fillTable(sd: StepDefinition, stepTable: Examples): void =
  discard


when isMainModule:

  Given "a simple feature file:", (quote.data: string):
    echo "file len " & $data.len

  var features : seq[Feature] = @[]
  loadFeature(features, stdin)
  var results = runner(features)
  echo $results.len
