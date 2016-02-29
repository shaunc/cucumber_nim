# cucumber/report.nim

import streams
import tables
import terminal
import strutils
import "./types"
import "./runner"
import "./feature"
when isMainModule:
  import "./step"

type
  ReporterProc* = proc(results: ResultsIter, file: File, options: CucumberOptions): int
  Reporter* = object
    name: string
    rpt: ReporterProc
  ResultSummary = array[StepResultValue, int]

var reporters* : Table[string, Reporter] = initTable[string, Reporter]()

proc registerReporter*(name : string, rpt: ReporterProc) : void =
  reporters[name] = Reporter(name: name, rpt: rpt)

{.push warning[ProveInit]: off.}
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
  (srNoDefinition, fgMagenta)].toTable
{.pop.}

proc setColor(file: File, color: ForegroundColor) : void =
  if isatty(file):
    setForegroundColor(file, color)


proc setResultColor(file: File, resultValue: StepResultValue) : void =
  setColor(file, resultColor[resultValue])

template resetColor(file: File, body: untyped) : untyped =
  try:
    body
  finally:
    if isatty(file):
      setForegroundColor(file, fgBlack)

proc newResultSummary(): ResultSummary = [0, 0, 0, 0]

proc writeResultSummary*(
    file: File, sresult: ScenarioResult, options: CucumberOptions): void =
  let resultValue = sresult.stepResult.value
  if resultValue != srSuccess or options.verbosity >= 0:
    setResultColor(file, resultValue)
    file.writeLine("  $1 $2" % [
      resultChar[resultValue], sresult.scenario.description])
  setColor(file, fgBlack)

proc writeExceptionResult*(file: File, sresult: ScenarioResult) :void =
  let resultValue = sresult.stepResult.value
  setResultColor(file, resultValue)
  file.writeLine(
    "$1: $2" % [sresult.scenario.description, resultDesc[resultValue]])
  file.writeLine("    Step: $1" % sresult.step.description)
  if sresult.stepResult.exception != nil:
    if isatty(file):
      setForegroundColor(file, fgRed)
    let exc = sresult.stepResult.exception
    if not (exc of NoDefinitionForStep) or ((ref NoDefinitionForStep)exc).save:
      file.writeLine("\nDetail: " & sresult.stepResult.exception.msg)
      file.writeLine(sresult.stepResult.exception.getStackTrace())
  file.writeLine("")

proc basicReporter*(results: ResultsIter, file: File, options: CucumberOptions): int =
  var summary = newResultSummary()  
  if isatty(file):
    system.addQuitProc(resetAttributes)
  var lastFeature : string = nil
  var withExceptions = newSeq[ScenarioResult]()
  resetColor file:
    for i, sresult in results():
      if lastFeature != sresult.feature.description:
        lastFeature = sresult.feature.description
        if i > 0:
          file.writeLine("\n")
        file.writeLine("$1:\n" % lastFeature)
      let resultValue = sresult.stepResult.value
      summary[resultValue] += 1;
      file.writeResultSummary(sresult, options)
      if sresult.stepResult.exception != nil:
        withExceptions.add(sresult)
      if options.bail and resultValue != srSuccess and resultValue != srSkip:
        break

  if options.verbosity >= -1:
    resetColor file:
      file.writeLine("")
      for i, sresult in withExceptions:
        file.writeExceptionResult(sresult)

  if options.verbosity >= -2:
    for sresult in [srSuccess, srFail, srNoDefinition, srSkip]:
      let rname = ($sresult)[2..^1]
      file.write("$1: $2 " % [rname, $summary[sresult]])
    file.writeLine("")

  result = summary[srFail] + summary[srNoDefinition]

registerReporter("basic", basicReporter)

when isMainModule:

  Given "a simple feature file:", (data: blockParam):
    echo "file len " & $data.len

  loadFeature(library.features, stdin)
  var results = runner(library)
  basicReporter(results, stdout)
