# package cucumber
# tests/run.nim

import "../cucumber"

when isMainModule:
  withDir("./tests"):
    main()
