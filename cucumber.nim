# cucumber.nim
#
# cucumber BDD testing framework library

import typeinfo
import tables
import cucumber/types
import cucumber/step
import cucumber/main
import cucumber/parameter

export main.main, main.withDir
export types.StepType, types.StepResult, types.StepResultValue
export types.ContextType
export step.Given, step.When, step.Then
export step.StepDefinition, step.StepArgs, step.stepDefinitions
export step.resetContext
export step.re, step.Regex, step.RegexMatch, step.match
export step.Option, step.get, step.captures, step.Captures, step.`[]`
export typeinfo.Any, toAny
export tables.`[]`, tables.`[]=`
#export parameter.declarePT
#export parameter.parseInt, parameter.parseBool, parameter.parseString
