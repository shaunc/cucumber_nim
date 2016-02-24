# package cucumber
# tests/run.nim

import "../cucumber"
import "./steps/featureSteps"
import "./steps/stepDefinitionSteps"
import "./steps/runnerSteps"

when isMainModule:
  withDir("./tests"):
    let nfail = main()
    if nfail > 0:
      quit(nfail)
