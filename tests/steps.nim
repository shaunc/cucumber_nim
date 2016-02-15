# package: cucumber
# module: tests/steps

import tables
import streams
import strutils
import "../cucumber"
import "../cucumber/parameter"
import "../cucumber/feature"
import macros


declareRefPT(Stream)
declareRefPT(Feature)

Given "a feature file:", (
    data: blockParam, scenario.featureStream: var Stream):
  featureStream = newStringStream(data)

When "I read the feature file", (
    scenario.featureStream: Stream, scenario.feature: var Feature):
  feature = readFeature(featureStream)

Then "reading the feature file causes an error:", (
    scenario.featureStream: Stream, message: blockParam):
  try:
    discard readFeature(featureStream)
  except:
    let exc = getCurrentException()
    let amsg = exc.msg.strip()
    let emsg = message.strip()
    assert amsg == emsg, "$1 != $2" % [amsg, emsg]

Then "the feature description is \"(.*)\"", (
    scenario.feature: Feature, description: string):
  assert feature.description == description

Then r"""the feature explanation is \"([^"]*)\"""", (
    scenario.feature: Feature, explanation: string):
  assert feature.explanation.strip() == explanation.strip()

Then r"the feature contains (\d+) scenarios", (
    scenario.feature: Feature, nscenarios: int):
  assert feature.scenarios.len == nscenarios

Then r"the feature has no background block", (
    scenario.feature: Feature):
  assert feature.background == nil

Then r"scenario (\d+) contains (\d+) steps", (
    scenario.feature: Feature, iscenario: int, nsteps: int):
  let scenario = feature.scenarios[iscenario]
  assert scenario.steps.len == nsteps

proc checkStepType(step: Step, typeName: string): void =
  case typeName
    of "Given": assert step.stepType == stGiven
    of "When": assert step.stepType == stWhen
    of "Then": assert step.stepType == stThen
    else:
      raise newException(AssertionError, "unknown step type " & typeName)

Then r"""step (\d+) of scenario (\d+) is of type \"(\w+)\"""", (
    scenario.feature: Feature, istep: int, iscenario: int, typeName: string):
  let step = feature.scenarios[iscenario].steps[istep]
  checkStepType(step, typeName)

Then r"""step (\d+) of the background is of type \"(\w+)\"""", (
    scenario.feature: Feature, istep: int, typeName: string):
  let step = feature.background.steps[istep]
  checkStepType(step, typeName)

Then r"""step (\d+) of scenario (\d+) has text \"(.*)\"""", (
    scenario.feature: Feature, istep: int, iscenario: int, text: string):
  let step = feature.scenarios[iscenario].steps[istep]
  assert step.text == text

Then r"""step (\d+) of the background has text \"(.*)\"""", (
    scenario.feature: Feature, istep: int, text: string):
  let step = feature.background.steps[istep]
  assert step.text == text

Then r"""step (\d+) of scenario (\d+) has no block parameter""", (
    scenario.feature: Feature, istep: int, iscenario: int):
  let step = feature.scenarios[iscenario].steps[istep]
  assert step.blockParam == nil

Then r"""step (\d+) of the background has no block parameter""", (
    scenario.feature: Feature, istep: int):
  let step = feature.background.steps[istep]
  assert step.blockParam == nil

Then r"step (\d+) of scenario (\d+) has block parameter:", (
    scenario.feature: Feature, istep: int, iscenario: int, 
    blockParam: blockParam):
  let step = feature.scenarios[iscenario].steps[istep]
  assert step.blockParam.strip() == blockParam.strip()

Then r"the feature has a background block", (
    scenario.feature: Feature):
  assert feature.background != nil

Then r"the background contains (\d+) steps", (
    scenario.feature: Feature, nsteps: int):
  let background = feature.background
  assert background.steps.len == nsteps
