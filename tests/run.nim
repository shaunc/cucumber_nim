# package cucumber
# tests/run.nim

import "../cucumber"
import "./steps/featureSteps"
import "./steps/stepDefinitionSteps"

when isMainModule:
  withDir("./tests"):
    main()
