# package: cucumber_nim
# module: cucumber/hooks.nim

import macros
import sets
import sequtils
import strutils
import "./macroutil"
import "./types"
import "./parameter"
import "./feature"
import "./step"

type
  HookFct* = proc(feature: Feature, scenario: Scenario, step: Step) : void
  HookDefinition* = ref object
    hookType*: HookType
    tagFilter*: TagFilter
    defn*: HookFct
  HookDefinitionsObj* = object
    items: array[HookType, seq[HookDefinition]]

  HookDefinitions* = ref HookDefinitionsObj

  ArgumentsNodes = tuple[getters: NimNode, setters: NimNode]

var hookDefinitions*: HookDefinitions = HookDefinitions(
  items: [
    newSeq[HookDefinition](), newSeq[HookDefinition](),
    newSeq[HookDefinition](), newSeq[HookDefinition](),
    newSeq[HookDefinition](), newSeq[HookDefinition](),
    newSeq[HookDefinition](), newSeq[HookDefinition]()])

proc `[]`*(
    defs: HookDefinitions, hookType: HookType) : var seq[HookDefinition] = 
  defs.items[hookType]

proc hookTypeFor*(hookTypeName: string) : HookType {.procvar.} =
  case hookTypeName.toLower
    of "beforeall": result = htBeforeAll
    of "afterall": result = htAfterAll
    of "beforefeature": result = htBeforeFeature
    of "afterfeature": result = htAfterFeature
    of "beforescenario": result = htBeforeScenario
    of "afterscenario": result = htAfterScenario
    of "beforestep": result = htBeforeStep
    of "afterstep": result = htAfterStep
    else:
      raise newException(SyntaxError, "Unknown hook type name: " & hookTypeName)

proc makeTagFilter(tagFilter: NimNode, tags: NimNode): NimNode
proc processArguments(argList: NimNode): ArgumentsNodes
proc defineHook(hookType: HookType, tags: NimNode, argList: NimNode, hookDef: NimNode): NimNode =

  ##[
    Create a hook.

    A hook is a procedure that executes before or after steps, scenarios
    features or globally.

    The macros below (BeforeAll, AfterAll, BeforeFeature, AfterFeature,
    BeforeScenario AfterScenario, BeforeStep and AfterStep) define
    specific types of hook.

    A tag or possibly nested list of tags can be passed to condition
    execution of the hook. 

    Tag lists should be preceeded by either ``*`` for "AND" or ``+`` for "OR".
    (This syntax has also been chosen because nim does not recognize command
    call syntax when the first non-space is not an identifier or operator.)
    Individual tags can be preceeded by ``~`` to negate them.

    The argument list should specify any context variables the hook uses.
    Hooks can be used to cleanup or set defaults.

    Given a hook specification::

      BeforeScenario *[@foo, +[~@bar, @baz]], (
          feature.foo: int, scenario.bar: var string):
        bar = $foo

    The resulting hook definition would be::

      proc tagFilter(tagSet: HashSet[string]): bool =
        ("@foo" in tagSet) and (not("@bar" in tagSet) or ("@baz" in tagSet))

      proc hook(feature: Feature, scenario: Scenario, step: Step) : void =
        let foo = paramTypeIntGetter(ctFeature, "foo")
        var bar = paramTypeStringGetter(ctScenario, "bar")
        bar = $foo
        paramTypeStringSetter(ctScenario, "bar", bar)

      let hookDefinition = HookDefinition(
        hookType: htBeforeScenario, filter: tagFilter, defn: hook)
      hookDefinitions[htBeforeScenario].add(hookDefinition)

  ]##

  let tagFilter = genSym(nskProc, "tagFilter")
  let tagFilterExpr = makeTagFilter(tagFilter, tags)
  let (getters, setters) = processArguments(argList)
  let nHookType = newIdentNode($hookType)
  let hook = genSym(nskProc, "hook")
  let hookDefinition = genSym(nskLet, "hookDefinition")
  let defnsRhs = newDot(newBrkt("hookDefinitions", nHookType), "add")

  result = quote do:
    `tagFilterExpr`
    proc `hook`(feature: Feature, scenario: Scenario, step: Step): void =
      `getters`
      `hookDef`
      `setters`
    let `hookDefinition` = HookDefinition(
      hookType: `nHookType`, tagFilter: `tagFilter`, defn: `hook`)
    `defnsRhs`(`hookDefinition`)
  #mShow result

proc getPrefix(n : NimNode): string = $n

proc transformTags(tagSet: NimNode, tags: NimNode): NimNode =
  let head = getPrefix(tags[0])
  let body = tags[1]
  case head 
  of "@":
    if $body == "any":
      result = newLit(true)
    else:
      result = newPar(infix(newLit("@" & $body), "in", tagSet))
  of "~":
    result = newPar(prefix(transformTags(tagSet, body), "not"))
  of "*":
    if body.len == 0:
      result = newLit(true)
    elif body.len == 1:
      result = transformTags(tagSet, body[0])
    else:
      result = newPar(body.foldl infix(
        transformTags(tagSet, a), "and", transformTags(tagSet, b)))
  of "+":
    if body.len == 0:
      result = newLit(false)
    elif body.len == 1:
      result = transformTags(tagSet, body[0])
    else:
      result = newPar(body.foldl infix(
        transformTags(tagSet, a), "or", transformTags(tagSet, b)))
  of "~@", "~*", "~+":
    let sbody = prefix(body, head[1..1])
    result = newPar(prefix(transformTags(tagSet, sbody), "not"))
  else:
    raise newException(
      HookDefinitionError, "Tag expression: unexpected prefix: " & head)


proc makeTagFilter(tagFilter: NimNode, tags: NimNode): NimNode =
  let tagSet = newIdentNode("tagSet")
  var tagExpr: NimNode
  try:
    tagExpr = transformTags(tagSet, tags)
  except:
    raise newException(
      HookDefinitionError, 
      "Tag expression invalid: \"$1\"" % tags.toStrLit.strVal)
  result = quote do:
    proc `tagFilter`(`tagSet`: StringSet) : bool =
      `tagExpr`
  result = result[0]

proc processArguments(arglist: NimNode): ArgumentsNodes =
  let (getters, setters) = (newStmtList(), newStmtList())
  for argdef in arglist:
    let (aname, atype, aloc, avar) = unpackArg(argdef)
    if not (aloc in {ctGlobal, ctFeature, ctScenario}):
      raise newException(
        HookDefinitionError, "Only context parameters allowed in hook.")
    getters.add newVar(aname, cast[string](nil), newCall(
      ptName(atype, "Getter"), newIdentNode($aloc), newLit(aname)))
    if avar:
      setters.add newCall(
        newIdentNode(ptName(atype, "Setter")), 
        newIdentNode($aloc), newLit(aname), newIdentNode(aname))
  result = (getters, setters)

macro BeforeAll*(tags: untyped, argList: untyped, hookDef: untyped) : untyped =
  defineHook(htBeforeAll, tags, argList, hookDef)

macro AfterAll*(tags: untyped, argList: untyped, hookDef: untyped) : untyped =
  defineHook(htAfterAll, tags, argList, hookDef)

macro BeforeFeature*(tags: untyped, argList: untyped, hookDef: untyped) : untyped =
  defineHook(htBeforeFeature, tags, argList, hookDef)

macro AfterFeature*(tags: untyped, argList: untyped, hookDef: untyped) : untyped =
  defineHook(htAfterFeature, tags, argList, hookDef)

macro BeforeScenario*(tags: untyped, argList: untyped, hookDef: untyped) : untyped =
  defineHook(htBeforeScenario, tags, argList, hookDef)

macro AfterScenario*(tags: untyped, argList: untyped, hookDef: untyped) : untyped =
  defineHook(htAfterScenario, tags, argList, hookDef)

macro BeforeStep*(tags: untyped, argList: untyped, hookDef: untyped) : untyped =
  defineHook(htBeforeStep, tags, argList, hookDef)

macro AfterStep*(tags: untyped, argList: untyped, hookDef: untyped) : untyped =
  defineHook(htAfterStep, tags, argList, hookDef)

when isMainModule:

  BeforeAll *[@foo], ():
    discard

  BeforeAll *[@f,~@b], ():
    discard

  BeforeAll *[@foo, +[~@bar, @baz]], (feature.foo: int, scenario.bar: var string):
    bar = $foo


