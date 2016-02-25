# cucumber/types


type
  StepType* = enum
    stGiven,
    stWhen,
    stThen

  StepResultValue* = enum
    srSuccess
    srFail
    srSkip
    srNoDefinition

  StepArgs* = ref object of RootObj
    stepText*: string
    blockParam*: string

  StepResult* = ref object
    args*: StepArgs
    value*: StepResultValue
    exception*: ref Exception

  ContextType* = enum
    ctGlobal,
    ctFeature,
    ctScenario,
    ctTable,
    ctQuote,
    ctNotContext
    
  HookType* = enum
    htBeforeAll
    htAfterAll
    htBeforeFeature
    htAfterFeature
    htBeforeScenario
    htAfterScenario
    htBeforeStep
    htAfterStep

  SyntaxError* = object of ValueError

  ## feature file contains bad syntax
  FeatureSyntaxError* = object of SyntaxError

  ## step definition malformed
  StepDefinitionError* = object of SyntaxError

  ## hook definition malformed
  HookDefinitionError* = object of SyntaxError

  CucumberOptions* = ref object
    verbosity*: int
    bail*: bool
