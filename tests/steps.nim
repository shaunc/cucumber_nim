# package: cucumber
# module: tests/steps

import tables
import typeinfo
import streams
import "../cucumber"
import "../cucumber/parameter"
import "../cucumber/feature"
import macros

#[
proc getFeature(a : Any) : Feature =
  result = cast[Feature](a.getPointer)
proc setFeature(a: Any, feature: Feature): void =
  var b = toAny[Feature](feature)
  assign(a, b)
]#
var streamStack : seq[Stream] = @[]
var streamIndices: seq[int] = @[]
var streamSentinel = -1
proc getStream(a: Any) : Stream =
  var idx = typeinfo.getInt(a)
  return if idx >= 0: streamStack[idx] else: nil
proc setStream(a: Any, s: Stream): void =
  streamStack.add(s)
  streamIndices.add(streamIndices.len)
  var b = toAny[int](streamIndices[^1])
#[  
  var b: Any
  if s == nil:
    b = toAny[int](streamSentinel)
  else:
    streamIndices.add(streamIndices.len)
    b = toAny[int](streamIndices[^1])
    streamStack.add(s)
]#
  assign(a, b)

dumpTree:
  proc resetFeature*(context: Context; key: string): void =
    setFeature(context[key], cast[var Feature](nil))

#declarePT(
#  "Feature", Feature, nil, getFeature, setFeature, "", nil)
declarePT(
  "Stream", Stream, nil, getStream, setStream, nil, nil)

Given "a simple feature file", (
    data: blockParam, scenario.featureStream: var Stream):
  echo "data", data
  featureStream = newStringStream(data)

When "I read the feature file", (scenario.featureStream: Stream):
  var content = featureStream.readAll()
  echo "data", content

Then "the feature description is \"(.*)\"", (
    scenario.featureContent: string, description: string):
  echo "OK"