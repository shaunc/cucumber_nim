# package cucumber_nim
# module tests/steps/dynmodHooks

import sets
import "../../cucumber/types"
import "../../cucumber/parameter"
import "../../cucumber/step"
import "../../cucumber/hook"
import "./dynmodule"

##[ 
    Tag @defMod for scenarios that define steps or hooks themselves.
    Tag @featureDefMod for features in which background defines
    all steps and features.
]##

BeforeScenario @defMod, (
    scenario.defMod: var LibModule
    ):
  defMod = LibModule(lib: nil, fn: nil)

AfterScenario @defMod, (scenario.defMod: LibModule):
  cleanupModule(defMod)
