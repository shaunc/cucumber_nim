# cucumber/feature
#
## Defines a Feature described in a ".feature" file, written
## in gherkin (see https://github.com/cucumber/cucumber/wiki/Gherkin).
## See also http://docs.behat.org/en/v2.5/guides/1.gherkin.html
## for syntax.

from streams import newFileStream, Stream, readLine
from sequtils import mapIt, apply
from sets import toSet, contains
from strutils import split, strip, repeat, `%`, join
from nre import re, match, captures, `[]`
import options

type
  Node = ref NodeObj
  NodeObj = object of RootObj
    description*: string
    tags*: seq[string]
    comments*: seq[string]
    parent: Node

  Scenario* = ref ScenarioObj
  Step* = ref StepObj
  Examples* = ref ExamplesObj

  Feature* = ref object of NodeObj
    ## Contents of a gherkin (`.feature`) file.

    name*: string
    explanation*: string
    background*: seq[Scenario]
    scenarios*: seq[Scenario]

  ScenarioObj* = object of Node
    ## a senario or scenario outline of a feature

    steps*: seq[Step]
    examples*: seq[Examples]

  StepObj* = object of Node
    text*: string
    blockParameter: string

  ExamplesObj* = object of Node
    parameters*: seq[string]
    values*: seq[seq[string]]

  ## feature file contains bad syntax
  FeatureSyntaxError = object of ValueError

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

proc newSyntaxError(line : Line, message : string) : ref FeatureSyntaxError = 
  let fullMessage = "$1: $2\n\n>  $3" % [$line.number, message, line.content]
  return newException(FeatureSyntaxError, fullMessage)

proc readFeature*(path: string): Feature
proc readFeature*(fstream: Stream, path: string = "?"): Feature
proc readFeature*(file: File, path: string = "?") : Feature

proc readFeature(feature: Feature, fstream: Stream): void

proc newFeature(name: string): Feature = 
  result = Feature(
    name: name,
    comments: @[],
    tags: @[],
    background: @[],
    scenarios: @[]
  )
proc newScenario(feature: Feature, description: string) : Scenario =
  result = Scenario(
    description: description,
    parent: feature,
    steps: @[],
    comments: @[])

proc readFeature*(path: string) : Feature = 
  let file = open(path)
  defer: file.close
  return readFeature(file, path)

proc readFeature*(file: File, path: string = "?") : Feature =
  result = newFeature(path)  
  result.readFeature(newFileStream(file))

proc readFeature*(fstream: Stream, path: string = "?"): Feature = 
  result = newFeature(path)
  result.readFeature(fstream)

proc newLineStream(stream: Stream) : LineStream =
  return LineStream(stream: stream, lineNumber: 0)

proc readPreamble(feature: Feature, stream: var LineStream): void
proc readHead(feature: Feature, stream: var LineStream): void
proc readBody(feature: Feature, stream: var LineStream): void
proc readScenario(
    feature: Feature, stream: var LineStream, head: Line
    ) : Scenario
proc readExamples(
    scenario: Scenario, stream: var LineStream, indent: int
    ) : void
proc readBlock(step: Step, stream: var LineStream, indent: int): void

proc readFeature(feature: Feature, fstream: Stream): void =
  var stream = newLineStream(fstream)
  feature.readPreamble(stream)
  feature.readHead(stream)
  feature.readBody(stream)

proc newLine(line: string, ltype: LineType, number: int): Line =
  let sline = line.strip(trailing = false)
  echo "$1($3): $2" % [$number, sline.strip, $ltype]
  return Line(
      number: number,
      ltype: ltype,
      indent: line.len - sline.len,
      content: sline.strip)

let keywords = ["Feature", "Scenario"]
let headRE = re("($1)" % (keywords.mapIt "(?:$1)" % it).join("|"))
echo $headRE.pattern

proc headKey(line: Line) : string =
  return (line.content.match headRE).get.captures[0]

proc nextLine(stream: var LineStream) : Line = 
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
    if line.len > 0:
      break

  if line[0] == '#':
    return newLine(text, ltComment, stream.lineNumber)
  if line[0] == '@':
    return newLine(text, ltTags, stream.lineNumber)
    #let tags = line.split(",").mapIt it.strip(re "\s")

  let headMatch = line.match headRE
  if headMatch.isSome:
    return newLine(text, ltHead, stream.lineNumber)

  return newLine(text, ltBody, stream.lineNumber)

proc pushback(stream: var LineStream, line: Line): void =
  if stream.last != nil:
    raise newException(Exception, "Cannot push back 2nd line")
  stream.last = repeat(' ', line.indent) & line.content

proc readPreamble(feature: Feature, stream: var LineStream): void = 
  while true:
    let line : Line = stream.nextLine
    if line.ltype == ltEOF:
      break
    case line.ltype
    of ltComment:
      feature.comments.add line.content
    of ltTags:
      feature.tags.add line.content
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
  feature.description = hline.content
  var explanation = ""
  while true:
    let line = stream.nextLine
    case line.ltype
    of ltEOF:
      break
    of ltComment:
      feature.comments.add line.content
    of ltHead:
      stream.pushback line
      break
    of ltBody:
      if hline.indent >= line.indent:
        raise newSyntaxError(line, "Feature explanation must be indented.")
      explanation.add(line.content)
      explanation.add("\n")
    else:
      raise newSyntaxError(line, "unexpected line: " & $line.ltype)

proc readBody(feature: Feature, stream: var LineStream): void =
  var comments : seq[string] = @[]
  while true:
    let line = stream.nextLine
    case line.ltype
    of ltComment:
      comments.add line.content
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
        comments = @[]
    else:
      raise newSyntaxError(line, "unexpected line: " & $line.ltype)
  feature.comments.add comments

proc readScenario(
    feature: Feature, stream: var LineStream, head: Line
    ) : Scenario =
  let key = headKey(head)
  result = newScenario(feature, head.content)
  case key
  of "Scenario", "Scenario Outline":
    feature.scenarios.add result
  of "Background":
    feature.background.add result
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
          raise newSyntaxError(line, "multiline block must follow step")
        result.steps[result.steps.len - 1].readBlock(stream, line.indent)
      result.steps.add(Step(text: line.content))
    else:
        raise newSyntaxError(line, "Unexpected " & $line.ltype)

proc readBlock(step: Step, stream: var LineStream, indent: int) : void =
  var content = ""
  while true:
    let line = stream.nextLine
    if line.indent < indent:
      raise newSyntaxError(line, "Unexpected end of multiline block.")
    if line.content == "\"\"\"":
      step.blockParameter = content
      break
    content.add(repeat(" ", line.indent - indent) & line.content & "\n")

proc readExamples(
    scenario: Scenario, stream: var LineStream, indent: int
    ) : void = 
  let result = Examples(
    parent: scenario,
    parameters : @[],
    values: @[])
  scenario.examples.add result
  while true:
    let line = stream.nextLine
    if line.ltype != ltBody:
      stream.pushback line
      break
    if line.content.match(re("|.*|$")).isNone:
      raise newSyntaxError(line, "Malformed examples table.")
    let row = line.content.split('|')[1..^1]
    if result.parameters.len == 0:
      result.parameters.add row
    else:
      result.values.add row

when isMainModule:
  let feature = readFeature(stdin)
  echo "description: " & feature.description
  echo "comments: " & $feature.comments.len
  echo "scenarios: " & $feature.scenarios.len
