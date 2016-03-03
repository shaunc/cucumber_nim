# cucumber/types

import sets
import future
import options

export HashSet

type
  StepType* = enum
    stGiven,
    stWhen,
    stThen

  HookType* = enum
    htBeforeAll
    htAfterAll
    htBeforeFeature
    htAfterFeature
    htBeforeScenario
    htAfterScenario
    htBeforeStep
    htAfterStep

  StepResultValue* = enum
    srSuccess
    srFail
    srSkip
    srNoDefinition

  StepArgs* = ref object of RootObj
    stepText*: string
    blockParam*: string

  HookResultValue* = enum
    hrSuccess
    hrFail
  HookResult* = ref object
    value*: HookResultValue
    hookType*: HookType
    exception*: ref Exception

  StepResult* = ref object
    args*: StepArgs
    value*: StepResultValue
    exception*: ref Exception
    hookResult*: HookResult

  ContextType* = enum
    ctGlobal,
    ctFeature,
    ctScenario,
    ctTable,
    ctQuote,
    ctNotContext

  SyntaxError* = object of ValueError

  ## feature file contains bad syntax
  FeatureSyntaxError* = object of SyntaxError

  ## step definition malformed
  StepDefinitionError* = object of SyntaxError

  ## hook definition malformed
  HookDefinitionError* = object of SyntaxError

  StringSet* = HashSet[string]
  TagFilter* = (StringSet)->bool
  CucumberOptions* = ref object
    verbosity*: int
    bail*: bool
    tagFilter*: TagFilter
    defineTags*: StringSet
