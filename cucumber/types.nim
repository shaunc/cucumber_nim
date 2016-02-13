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

  StepResult* = ref object
    value*: StepResultValue
    exception*: ref Exception

  ContextType* = enum
    ctGlobal,
    ctFeature,
    ctScenario
