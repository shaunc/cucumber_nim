# cucumber/feature
#
## Defines a Feature described in a ".feature" file, written
## in gherkin (see https://github.com/cucumber/cucumber/wiki/Gherkin).
## See also http://docs.behat.org/en/v2.5/guides/1.gherkin.html
## for syntax.

import sets
from streams import newFileStream, Stream, readLine
from sequtils import mapIt, apply
from sets import toSet, contains
from strutils import split, strip, repeat, `%`, join, capitalizeAscii
from nre import re, match, captures, `[]`, replace
import options
import "./types"

type
  TestNode* = ref TestNodeObj
  TestNodeObj* {.shallow.} = object of RootObj
    description*: string
    tags*: StringSet
    comments*: seq[string]
    parent*: TestNode

  Scenario* = ref ScenarioObj
  Step* = ref StepObj
  Examples* = ref ExamplesObj

  FindFeatureSpec* = tuple[path: string, scenarioNumbers: seq[int]]

  Feature* {.shallow.} = ref object of TestNodeObj
    ## Contents of a gherkin (`.feature`) file.

    name*: string
    explanation*: string
    background*: Scenario
    scenarios*: seq[Scenario]

  Features* = seq[Feature]

  ScenarioObj* {.shallow.} = object of TestNode
    ## a senario or scenario outline of a feature

    steps*: seq[Step]
    examples*: seq[Examples]

  StepObj* {.shallow.} = object of TestNode
    stepType*: StepType
    text*: string
    blockParam*: string
    lineNumber*: int
    table*: Examples

  ExamplesObj* {.shallow.} = object of TestNode
    columns*: seq[string]
    values*: seq[seq[string]]

  TableLine* {.shallow.} = ref object
    columns*: seq[string]
    values*: seq[string]

  # Internals for reading features

  LineType = enum
    ltComment, ltTags, ltHead, ltBody, ltEOF

  Line = ref object
    number: int
    indent: int
    ltype: LineType
    content: string

  LineStream = object
    stream: Stream
    lineNumber: int
    last: string

const keywords = [
  "Feature", "Scenario", "Scenario Outline", "Background", "Examples"]
let headRE = re("(?i)($1): ?" % (keywords.mapIt "(?:$1)" % it).join("|"))

proc newSyntaxError(line : Line, message : string, adjustLineNumber = 0) : ref FeatureSyntaxError = 
  let fullMessage = "Line $1: $2\n\n>  $3" % [
    $(line.number + adjustLineNumber), message, line.content]
  return newException(FeatureSyntaxError, fullMessage)

proc readFeature*(find: FindFeatureSpec): Feature
proc readFeature*(
    fstream: Stream, find: FindFeatureSpec = ("?", nil)): Feature
proc readFeature*(
    file: File, find: FindFeatureSpec = ("?", nil)) : Feature

proc loadFeature*(features: var seq[Feature], find: FindFeatureSpec): void = 
 features.add readFeature(find)
proc loadFeature*(
    features: var seq[Feature], fstream: Stream, 
    find: FindFeatureSpec = ("?", nil)
    ): void = 
 features.add readFeature(fstream, find)
proc loadFeature*(
    features: var seq[Feature], file: File, 
    find: FindFeatureSpec = ("?", nil)
    ): void =
 features.add readFeature(file, find)

proc readFeature(
  feature: Feature, fstream: Stream, find: FindFeatureSpec): void

proc newFeature(name: string): Feature = 
  result = Feature(
    name: name,
    comments: @[],
    tags: initSet[string](),
    background: nil,
    scenarios: @[]
  )
proc newScenario(feature: Feature, text: string) : Scenario =
  let description = text.replace(headRE, "").capitalizeAscii
  result = Scenario(
    description: description,
    parent: feature,
    tags: initSet[string](),
    steps: @[],
    comments: @[],
    examples: @[])

proc readFeature*(find: FindFeatureSpec) : Feature = 
  let file = open(find.path)
  defer: file.close
  return readFeature(file, find)

proc readFeature*(
    file: File, find: FindFeatureSpec = ("?", nil)) : Feature =

  result = newFeature(find.path)  
  result.readFeature(newFileStream(file), find)

proc readFeature*(
    fstream: Stream, find: FindFeatureSpec = ("?", nil)): Feature = 

  result = newFeature(find.path)
  result.readFeature(fstream, find)

proc newLineStream(stream: Stream) : LineStream =
  return LineStream(stream: stream, lineNumber: 0)

proc readPreamble(feature: Feature, stream: var LineStream): void
proc readHead(feature: Feature, stream: var LineStream): void
proc readBody(
    feature: Feature, stream: var LineStream,
    scenarioNumbers: seq[int]
    ): void
proc readScenario(
    feature: Feature, stream: var LineStream, head: Line
    ) : Scenario
proc readExamples(
    scenario: Scenario, stream: var LineStream, indent: int, step: Step = nil
    ) : void
proc readBlock(step: Step, stream: var LineStream, indent: int): void

proc readFeature(
    feature: Feature, fstream: Stream, find: FindFeatureSpec): void =
  var stream = newLineStream(fstream)
  feature.readPreamble(stream)
  feature.readHead(stream)
  feature.readBody(stream, find.scenarioNumbers)

proc newLine(line: string, ltype: LineType, number: int): Line =
  let sline = line.strip(trailing = false)
  return Line(
      number: number,
      ltype: ltype,
      indent: line.len - sline.len,
      content: sline.strip)

proc headKey(line: Line) : string =
  return capitalizeAscii((line.content.match headRE).get.captures[0])

proc nextLine(stream: var LineStream, skipBlankLines : bool = true) : Line = 
  var text = ""
  var line = ""
  while true:
    if stream.last != nil:
      text = stream.last
      stream.last = nil
    elif not stream.stream.readLine(text):
      return newLine(text, ltEOF, stream.lineNumber)
    stream.lineNumber += 1
    line = text.strip()
    if line.len > 0 or not skipBlankLines:
      break

  if line[0] == '#':
    return newLine(text, ltComment, stream.lineNumber)
  if line[0] == '@':
    return newLine(text, ltTags, stream.lineNumber)

  let headMatch = line.match headRE
  if headMatch.isSome:
    return newLine(text, ltHead, stream.lineNumber)

  return newLine(text, ltBody, stream.lineNumber)

proc pushback(stream: var LineStream, line: Line): void =
  if stream.last != nil:
    raise newException(Exception, "Cannot push back 2nd line")
  stream.last = repeat(' ', line.indent) & line.content
  stream.lineNumber -= 1

proc readPreamble(feature: Feature, stream: var LineStream): void = 
  while true:
    let line : Line = stream.nextLine
    if line.ltype == ltEOF:
      break
    case line.ltype
    of ltComment:
      feature.comments.add line.content
    of ltTags:
      feature.tags.incl line.content.split().toSet
    of ltHead:
      stream.pushback line
      break
    else:
      raise newSyntaxError(line, "unexpected line before \"Feature:\".")

proc readHead(feature: Feature, stream: var LineStream): void =
  let hline = stream.nextLine
  if hline.ltype != ltHead:
    raise newSyntaxError(hline, "Feature must start with \"Feature:\".")
  let key = headKey(hline)
  if key != "Feature":
    raise newSyntaxError(hline, "Feature must start with \"Feature:\".")
  feature.description = hline.content.replace(headRE, "").strip()
  var explanation = ""
  while true:
    let line = stream.nextLine
    case line.ltype
    of ltEOF:
      break
    of ltComment:
      feature.comments.add line.content
    of ltHead, ltTags:
      stream.pushback line
      break
    of ltBody:
      if hline.indent >= line.indent:
        raise newSyntaxError(line, "Feature explanation must be indented.")
      explanation.add(line.content)
      explanation.add("\n")
    else:
      raise newSyntaxError(line, "unexpected line: " & $line.ltype)
  feature.explanation = explanation

proc readBody(
    feature: Feature, stream: var LineStream, 
    scenarioNumbers: seq[int]
    ): void =
  var comments : seq[string] = @[]
  var tags: StringSet = initSet[string]()
  while true:
    let line = stream.nextLine
    case line.ltype
    of ltComment:
      comments.add line.content
    of ltTags:
      tags.incl line.content.split.toSet
    of ltEOF: 
      break
    of ltHead:
      let key = headKey(line)
      case key
      of "Feature":
        raise newSyntaxError(line, "Features cannot be nested.")
      of "Example":
        raise newSyntaxError(
          line, "Examples must be nested under scenario outlines.")
      else:
        let scenario = feature.readScenario(stream, line)
        scenario.comments = comments & scenario.comments
        scenario.tags = tags
        comments = @[]
        tags = initSet[string]()
    else:
      raise newSyntaxError(line, "unexpected line: " & $line.ltype)
  if scenarioNumbers != nil:
    var scenarios : seq[Scenario] = @[]
    for i, scenario in feature.scenarios:
      if i + 1 in scenarioNumbers:
        scenarios.add(scenario)
    feature.scenarios = scenarios
  feature.comments.add comments

const stepTypes = ["And", "Given", "When", "Then"]
let stepTypeRE = re("($1)" % mapIt(stepTypes, ("(?:^$1)" % it)).join("|"))

proc addStep(parent: Scenario, steps: var seq[Step], line: Line) : void =
  var text = line.content.strip()
  var stepTypeM = text.match(stepTypeRE)
  if stepTypeM.isNone:
    raise newSyntaxError(line, 
      "Step must start with \"Given\", \"When\", \"Then\", \"And\".")
  var stepType = stepTypeM.get.captures[0]
  var step = Step(
    parent: parent, description: text.substr, lineNumber: line.number)
  if stepType == "And":
    if steps.len == 0:
      raise newSyntaxError(line, "First step cannot be \"And\"")
    step.stepType = steps[^1].stepType
  else:
    case stepType
    of "Given": step.stepType = stGiven
    of "When": step.stepType = stWhen
    of "Then": step.stepType = stThen
    else:
      raise newException(Exception, "unrecognized step type?")
  step.text = text.replace(stepTypeRE, "").strip()
  steps.add(step)

proc readScenario(
    feature: Feature, stream: var LineStream, head: Line
    ) : Scenario =
  let key = headKey(head)
  result = newScenario(feature, head.content)
  case key
  of "Scenario", "Scenario Outline":
    feature.scenarios.add result
  of "Background":
    if feature.background == nil:
      feature.background = result
      if feature.background.description.len <= 1:
        feature.background.description = "(background)"
    else:
      raise newSyntaxError(
        head, "Feature may not have more than one background section.")
  else:
    raise newSyntaxError(head, "Unexpected start of $1." % key)

  while true:
    let line = stream.nextLine
    if line.indent <= head.indent:
      stream.pushback line
      break
    case line.ltype:
    of ltEOF:
      break;
    of ltHead:
      let key = headKey(line)
      if key != "Examples":
        raise newSyntaxError(line, "Unexpected nested $1." % key)
      result.readExamples(stream, line.indent)
    of ltBody:
      if line.content == "\"\"\"":
        if result.steps.len == 0:
          raise newSyntaxError(line, "Multiline block must follow step.")
        result.steps[^1].readBlock(stream, line.indent)
      elif line.content[0] == '|':
        stream.pushback line
        if result.steps.len == 0:
          raise newSyntaxError(line, "Step table must follow step.")
        let lastStep = result.steps[^1]
        result.readExamples(stream, line.indent, lastStep)
      else:
        addStep(result, result.steps, line)
    of ltComment:
      result.comments.add(line.content)
    else:
        raise newSyntaxError(line, "Unexpected " & $line.ltype)

proc readBlock(step: Step, stream: var LineStream, indent: int) : void =
  var content = ""
  while true:
    let line = stream.nextLine(false)
    if line.indent < indent and line.content.strip().len != 0:
      raise newSyntaxError(line, "Unexpected end of multiline block.")
    if line.content == "\"\"\"" and line.indent <= indent:
      step.blockParam = content
      break
    content.add(repeat(" ", max(0, line.indent - indent)) & line.content & "\n")

proc readExamples(
    scenario: Scenario, stream: var LineStream, indent: int, step: Step = nil
    ) : void = 
  let result = Examples(
    parent: scenario,
    columns : @[],
    values: @[])
  if step == nil:
    scenario.examples.add result
  else:
    step.table = result
  while true:
    let line = stream.nextLine
    if line.ltype != ltBody or line.content.match(re"\|.*\|$").isNone:
      stream.pushback line
      break
    let row = line.content.split('|')[1..^2].mapIt it.strip()
    if result.columns.len == 0:
      result.columns.add row
    else:
      if row.len != result.columns.len:
        raise newSyntaxError(
          line, "Table row $1 elements, but $2 columns in table." % [
            $row.len, $result.columns.len])
      result.values.add row

when isMainModule:
  let feature = readFeature(stdin)
  echo "description: " & feature.description
  echo "comments: " & $feature.comments.len
  echo "scenarios: " & $feature.scenarios.len
