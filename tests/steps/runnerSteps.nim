# tests/steps/runnerSteps.nim

import future
import os
import tables
import sets
import sequtils
import strutils
import "../../cucumber"
import "../../cucumber/step"
import "../../cucumber/hook"
import "../../cucumber/runner"
import "../../cucumber/parameter"
import "../../cucumber/report"
import "./featureSteps"
import "./stepDefinitionSteps"
import "./hookDefinitionSteps"
import "./dynmodule"

type
  ScenarioResults* = ref object
    items: seq[ScenarioResult]
  RunFeaturesProc* = (
    proc(data: string, options: CucumberOptions): ScenarioResults {.nimcall.})

DeclareRefParamType(ScenarioResults)

let runnerModuleTemplate = """

import streams
import "$1/cucumber/types"
import "$1/cucumber/feature"
import "$1/cucumber/runner"
import "$1/cucumber/hook"

const defModulePresent = $2
when defModulePresent:
  import "$3"

type
  ScenarioResults* = ref object
    items: seq[ScenarioResult]


{.push exportc.}

# NB -- when defined in "runFeatures" have problem with garbage collection
# "grow". OK like this for the moment just if "runFeatures" is called once
var features: seq[Feature] = @[]
var sresults: seq[ScenarioResult] = newSeq[ScenarioResult]()

proc runFeatures(data: string, options: CucumberOptions): ScenarioResults =
  var featureStream = newStringStream(data)
  let feature = readFeature(featureStream)
  features.add(feature)
  let itr = runner(features, options)
  for i, sresult in itr():
    sresults.add(sresult)

  result = ScenarioResults(items: sresults)

{.pop.}
"""

proc len(a: ScenarioResults) : int = a.items.len


# ---------------------------------------------------------------------

AfterScenario @runnerMod, (scenario.runnerMod: var LibModule):
  cleanupModule(runnerMod)

proc runFeature(
    data: string, results: var ScenarioResults, defMod: LibModule, 
    runnerMod: var LibModule, defineTags: StringSet = initSet[string]()
    ) =

  let baseDir = getCurrentDir()
  let defModulePresent = defMod.getFN != ""
  let runnerSource = runnerModuleTemplate % [
    baseDir, $defModulePresent, defMod.getFN
  ]
  runnerMod = loadSource(runnerSource)
  let runFeatures = bindInLib[RunFeaturesProc](runnerMod, "runFeatures")
  let options = CucumberOptions(
    verbosity: -2, bail: false,
    tagFilter: (s: StringSet)=> not("@skip" in s),
    defineTags: defineTags )
  results = runFeatures(data, options)

When "I run the feature:", (
    quote.data: string,
    scenario.results: var ScenarioResults,
    scenario.defMod: LibModule,
    scenario.runnerMod: var LibModule
    ):
  runFeature(data, results, defMod, runnerMod)

When "I run the feature with \"<tagsToDefine>\" defined:", (
    quote.data: string,
    scenario.results: var ScenarioResults,
    scenario.defMod: LibModule,
    scenario.runnerMod: var LibModule,
    tagsToDefine: string):

  var defineTags = initSet[string]()
  if tagsToDefine.len > 0:
    for s in tagsToDefine.split(","):
      defineTags.incl(s)
  runFeature(data, results, defMod, runnerMod, defineTags)
  
Then "there are <nresults> scenario results", (
    nresults: int, 
    scenario.results: ScenarioResults):
  assert results.len == nresults

type
  ResultsSummary = array[StepResultValue, int]

proc summary(results: ScenarioResults) : ResultsSummary =
  var sum : ResultsSummary = [0, 0, 0, 0]
  for sresult in results.items:
    inc sum[sresult.stepResult.value]
  result = sum

Then r"there (?:(?:is)|(?:are)) <nsucc> successful scenarios?", (
    nsucc: int,
    scenario.results: ScenarioResults):
  let summary = summary(results)
  assert summary[srSuccess] == nsucc


Then r"""scenario results are distributed: \[<expected>\].""", (
    scenario.results: ScenarioResults, expected: string):
  let expected = expected.split(',').mapIt parseInt(it.strip)
  let summary = summary(results)
  var isErr = false
  for i in countUp(0, 3):
    if summary[StepResultValue(i)] != expected[i]:
      isErr = true
  if isErr:      
    var msg = """
    results: $1 != $2
    """ % [
      (summary.mapIt($it)).join(", "),
      (expected.mapIt($it)).join(", ")]
    if summary[srFail] > expected[1]:
      msg &= "\nFailures detail: ---------------\n\n"
      for sresult in results.items:
        let resultValue = sresult.stepResult.value
        if resultValue != srSuccess:
          msg &= "$1: $2\n" % [
              sresult.scenario.description, resultDesc[resultValue]]
          msg &= "    Step: $1\n" % sresult.step.description
          let exc = sresult.stepResult.exception
          if exc == nil or (exc of NoDefinitionForStep):
            continue
          msg &= "\nDetail: \n" & sresult.stepResult.exception.msg
          msg &= sresult.stepResult.exception.getStackTrace()
      msg &= "------------------- (end detail) ----\n"

    raise newException(ValueError, msg)
  