# cucumber/runner.nim

import strutils
import options
import nre
import "./types"
import "./feature"
import "./step"

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

var library* = Library(
  stepDefinitions: stepDefinitions, 
  features: @[])

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
    if isMatch.isSome:
      if defn.expectsBlock and step.blockParam == nil:
        raise newNoDefinitionForStep(
          step, "Step definition expects block parameter.")
      if not defn.expectsBlock and step.blockParam != nil:
        raise newNoDefinitionForStep(
          step, "Step definition does not take block parameter.")
      return defn
  raise newNoDefinitionForStep(
    step, "No definition matching \"" & step.text & "\"", save = false)

proc runner*(library: Library) : ScenarioResults =
  echo "features " & $library.features.len
  result = @[]
  for feature in library.features:
    echo "feature scenarios " & $feature.scenarios.len
    for scenario in feature.scenarios:
      echo "scenario steps " & $scenario.steps.len
      var sresult = StepResult(value: srSuccess)
      var badstep : Step
      try:
        for i, step in scenario.steps:
          badstep = step
          let sd = matchStepDefinition(step, stepDefinitions[step.stepType])
          var args = StepArgs(stepText: step.text)
          if sd.expectsBlock:
            args.blockParam = step.blockParam
          sresult = sd.defn(args)
          if sresult.value != srSuccess:
            break
          else:
            badstep = nil
      except NoDefinitionForStep:
        var exc = getCurrentException()
        sresult = StepResult(value: srNoDefinition, exception: exc)
      result.add(ScenarioResult(
        stepResult: sresult, 
        feature: feature, scenario: scenario, step: badstep))



when isMainModule:

  Given "a simple feature file:", (data: blockParam):
    echo "file len " & $data.len

  loadFeature(library.features, stdin)
  var results = runner(library)
  echo $results.len
