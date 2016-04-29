# package: cucumber
# module: tests/steps

import tables
import sets
import streams
import strutils
import "../../cucumber"
import "../../cucumber/parameter"
import "../../cucumber/feature"
import macros


DeclareRefParamType(Stream)
DeclareRefParamType(Feature)



Given "a feature file:", (
    quote.data: string, scenario.featureStream: var Stream):
  featureStream = newStringStream(data)

When "I read the feature file:", (
    quote.data: string, scenario.feature: var Feature):

  var featureStream = newStringStream(data)
  feature = readFeature(featureStream)

Then "reading the feature file causes an error:", (
    scenario.featureStream: Stream, quote.message: string):
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

Then r"""the feature has tags? \"<tags>\"""", (
    scenario.feature: Feature, tags: string):
  let taglist = tags.split.toSet
  assert feature.tags == taglist

Then r"scenario <iscenario> contains <nsteps> steps", (
    scenario.feature: Feature, iscenario: int, nsteps: int):
  let scenario = feature.scenarios[iscenario]
  assert scenario.steps.len == nsteps

Then r"""scenario <iscenario> has tags? \"<tags>\"""", (
    scenario.feature: Feature, iscenario: int, tags: string):
  let scenario = feature.scenarios[iscenario]
  let taglist = tags.split.toSet
  assert scenario.tags == taglist

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
    quote.blockParam: string):
  let step = feature.scenarios[iscenario].steps[istep]
  assert step.blockParam.strip() == blockParam.strip()

Then r"the feature has a background block", (
    scenario.feature: Feature):
  assert feature.background != nil

Then r"the background contains (\d+) steps", (
    scenario.feature: Feature, nsteps: int):
  let background = feature.background
  assert background.steps.len == nsteps

Then r"scenario (\d+) contains (\d+) examples?", (
    scenario.feature: Feature, iscenario: int, nexamples: int):
  let scenario = feature.scenarios[iscenario]
  assert scenario.examples.len == nexamples

Then r"example (\d+) of scenario (\d+) has (\d+) column", (
    scenario.feature: Feature, iexample: int, iscenario: int, ncolumns int):
  let example = feature.scenarios[iscenario].examples[iexample]
  assert example.columns.len == ncolumns
  
Then r"""column (\d+) of example (\d+), scenario (\d+) is named \"([^\"]*)\"""", (
    scenario.feature: Feature, icolumn: int, iexample: int, iscenario: int, columnName: string):
  let example = feature.scenarios[iscenario].examples[iexample]
  let column = example.columns[icolumn]
  assert column == columnName

Then r"step <istep> of scenario <iscenario> has table with <irows> rows and columns:", (
    scenario.feature: Feature, 
    istep: int, iscenario: int, irows: int, column.name: seq[string]):
  let step = feature.scenarios[iscenario].steps[istep]
  let table = step.table
  assert table != nil
  assert name.len == table.columns.len
  assert irows == table.values.len
  for i, n in table.columns:
    assert n == name[i]
