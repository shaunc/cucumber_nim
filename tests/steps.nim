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
  echo "data", data
  featureStream = newStringStream(data)

When "I read the feature file", (
    scenario.featureStream: Stream, scenario.feature: var Feature):
  feature = readFeature(featureStream)

Then "the feature description is \"(.*)\"", (
    scenario.feature: Feature, description: string):
  assert feature.description == description

Then r"""the feature explanation is \"([^"]*)\"""", (
    scenario.feature: Feature, explanation: string):
  assert feature.explanation.strip() == explanation.strip()

Then r"the feature contains (\d+) scenarios", (
    scenario.feature: Feature, nscenarios: int):
  assert feature.scenarios.len == nscenarios

Then r"the feature contains (\d+) background blocks", (
    scenario.feature: Feature, nbackground: int):
  assert feature.background.len == nbackground  