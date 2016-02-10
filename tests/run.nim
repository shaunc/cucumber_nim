# package cucumber
# tests/run.nim

import "../cucumber"
import steps

when isMainModule:
  cucumber.main()
