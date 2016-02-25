# package cucumber
# tests/run.nim

import "../cucumber"
import "./steps/featureSteps"
import "./steps/stepDefinitionSteps"
import "./steps/hookDefinitionSteps"
import "./steps/runnerSteps"

when isMainModule:
  let nfail = main()
  if nfail > 0:
    quit(nfail)
