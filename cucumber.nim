# cucumber.nim
#
# cucumber BDD testing framework library

import typeinfo
import tables
import cucumber/types
import cucumber/step
import cucumber/hook
import cucumber/main
import cucumber/parameter

export main.main, main.withDir
export types.StepType, types.StepResult, types.StepResultValue
export types.HookType
export types.ContextType
export types.StringSet, types.TagFilter, types.CucumberOptions
export step.Given, step.When, step.Then
export step.StepDefinition, step.StepArgs, step.stepDefinitions
export step.resetContext
export step.re, step.Regex, step.RegexMatch, step.match
export step.Option, step.get, step.captures, step.Captures, step.`[]`
export hook.BeforeAll, hook.AfterAll
export hook.BeforeFeature, hook.AfterFeature
export hook.BeforeScenario, hook.AfterScenario
export hook.BeforeStep, hook.AfterStep
export typeinfo.Any, toAny
export tables.`[]`, tables.`[]=`
#export parameter.DeclareRefParamType, parameter.DeclareParamType
#export parameter.parseInt, parameter.parseBool, parameter.parseString
