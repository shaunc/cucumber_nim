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
    ctNotContext

