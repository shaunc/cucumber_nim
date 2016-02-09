# cucumber/report.nim

import streams
import tables
import terminal
import strutils
import "./types"
import "./runner"
when isMainModule:
  import "./feature"
  import "./step"

type
  ReporterProc* = proc(results: ScenarioResults, file: File): void
  Reporter* = object
    name: string
    rpt: ReporterProc

#static:
var reporters* : Table[string, Reporter] = initTable[string, Reporter]()

proc registerReporter(name : string, rpt: ReporterProc) : void =
  reporters[name] = Reporter(name: name, rpt: rpt)
  
let resultChar : Table[StepResultValue, string] = [
  (srSuccess, "✔"),
  (srFail, "✗"),
  (srSkip, "✻"),
  (srNoDefinition, "✤")].toTable
let resultDesc : Table[StepResultValue, string] = [
  (srSuccess, "success"),
  (srFail, "fail"),
  (srSkip, "skip"),
  (srNoDefinition, "no definition")].toTable
let resultColor: Table[StepResultValue, ForegroundColor] = [
  (srSuccess, fgGreen),
  (srFail, fgRed),
  (srSkip, fgBlue),
  (srNoDefinition, fgCyan)].toTable

proc setResultColor(file: File, resultValue: StepResultValue) : void =
  if isatty(file):
    setForegroundColor(file, resultColor[resultValue])

template resetColor(file: File, body: untyped) : untyped =
  try:
    body
  finally:
    if isatty(file):
      setForegroundColor(file, fgBlack)

proc basicReporter*(results: ScenarioResults, file: File): void =
  if isatty(file):
    system.addQuitProc(resetAttributes)
  var lastFeature : string = nil
  var withExceptions : ScenarioResults = @[]
  resetColor file:
    for i, sresult in results:
      if lastFeature != sresult.feature.description:
        lastFeature = sresult.feature.description
        if i > 0:
          file.writeLine("\n")
        file.writeLine("$1:\n" % lastFeature)
      let resultValue = sresult.stepResult.value
      setResultColor(file, resultValue)
      file.writeLine("  $1 $2" % [
        resultChar[resultValue], sresult.scenario.description])
      if sresult.stepResult.exception != nil:
        withExceptions.add(sresult)

  resetColor file:
    file.writeLine("")
    for sresult in withExceptions:
      let resultValue = sresult.stepResult.value
      setResultColor(file, resultValue)
      file.writeLine(
        "$1: $2" % [sresult.scenario.description, resultDesc[resultValue]])
      file.writeLine("    Step: $1" % sresult.step.description)
      if sresult.stepResult.exception != nil:
        let exc = sresult.stepResult.exception
        if not (exc of NoDefinitionForStep) or ((ref NoDefinitionForStep)exc).save:
          file.writeLine(sresult.stepResult.exception.getStackTrace())
      file.writeLine("")


when isMainModule:

  Given "a simple feature file:", (data: blockParam):
    echo "file len " & $data.len

  loadFeature(library.features, stdin)
  var results = runner(library)
  basicReporter(results, stdout)
