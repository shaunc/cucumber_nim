# cucumber/feature
#
## Defines a Feature described in a ".feature" file, written
## in gherkin.

from streams import newFileStream, Stream, readLine
from sets import toSet, contains
from strutils import split, strip, repeat, `%`
from nre import re, match, captures, `[]`
import options

type
  Scenario* = ref ScenarioObj
  Feature* = ref FeatureObj
  FeatureObj = object

    ## feature name (extracted from file name)
    name*: string

    ## feature description (string after "Feature"):
    description: string

    ## explanation, often written in e.g. "As a/In order to/I want".
    ## Specified in block of feature.
    explanation: string

    comments: seq[string]

    tags: seq[string]

    background: seq[string]

    scenarios: seq[ScenarioObj]

  ScenarioObj = object

    description: string
    feature: Feature
    steps: seq[string]
    comments: seq[string]

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

proc readFeature(path: string): Feature
proc readFeature(fstream: Stream, path: string = "?"): Feature
proc readFeature(file: File, path: string = "?") : Feature

proc readFeature(feature: Feature, fstream: Stream): void

proc newFeature(name: string): Feature = 
  result = Feature(
    name: name,
    comments: @[],
    tags: @[],
    background: @[],
    scenarios: @[]
  )

proc readFeature(path: string) : Feature = 
  let file = open(path)
  defer: file.close
  return readFeature(file, path)
  
proc readFeature(file: File, path: string = "?") : Feature =
  result = newFeature(path)  
  result.readFeature(newFileStream(file))

proc readFeature(fstream: Stream, path: string = "?"): Feature = 
  result = newFeature(path)
  result.readFeature(fstream)

proc newLineStream(stream: Stream) : LineStream =
  return LineStream(stream: stream, lineNumber: 0)

proc readPreamble(feature: Feature, stream: var LineStream): void
proc readHead(feature: Feature, stream: var LineStream): void
proc readBody(feature: Feature, stream: var LineStream): void

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

var keywords = toSet(["Feature", "Scenario"])

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

  let headMatch = line.match re(r"^(\w*):(.*)")
  if headMatch.isSome:
    let key = headMatch.get.captures[0]
    if key in keywords:
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
      raise newException(
          FeatureSyntaxError, "Unexpected line " & $line.number)


proc readHead(feature: Feature, stream: var LineStream): void =
  discard  

proc readBody(feature: Feature, stream: var LineStream): void =
  discard  

when isMainModule:
  let feature = readFeature(stdin)
