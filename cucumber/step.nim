# cucumber/step

import macros
import nre
import options
import strutils
import tables
import typeinfo
import "./parameter"
import "./types"
import "./macroutil"

export nre.re, nre.match, nre.Regex, nre.RegexMatch, nre.captures
export nre.Captures, nre.`[]`
export options.Option, options.get
export types.StepArgs
export parameter.resetContext

type

  StepDefinition* = object
    stepType*: StepType
    stepRE*: Regex
    defn*: proc(stepArgs: StepArgs) : StepResult
    expectsBlock*: bool

  StepDefinitions* = array[StepType, seq[StepDefinition]]

var stGiven0 : seq[StepDefinition] = @[]
var stWhen0 : seq[StepDefinition] = @[]
var stThen0 : seq[StepDefinition] = @[]
var stepDefinitions* : StepDefinitions = [stGiven0, stWhen0, stThen0]


proc ctypeFor(cname: string) : ContextType =
  case cname 
  of "global": result = ctGlobal
  of "feature": result = ctFeature
  of "scenario": result = ctScenario
  else:
    raise newException(Exception, "unknown context " & cname)

type
  ArgumentNodes = tuple
    defArgs: NimNode
    setContext: NimNode
    expectsBlock: NimNode

proc processStepArguments(actual: NimNode, arglist: NimNode) : ArgumentNodes

proc step(
    stepType: StepType, 
    pattern: string,
    arglist: NimNode,
    body: NimNode) : NimNode =

  ##[
    Creates a step definition.
    
    The macros ``Given``, ``When``, ``Then``, below, are wrappers
    around this procedure. Given a call:
    
    Given r"this step contains a (-?\d+)", (
        a: int, global.b: var int, c: blockParam):
      echo c
      b = a
    
    The resulting step definition would be:
    
        let stepRE = re(r"this step contains a (-?\d+)")
        proc stepDefinition(stepArgs: StepArgs) : StepResult =
          let actual = stepArgs.stepText.match(stepRE).get.captures
          block:
            let a : int = parseInt(actual[0])
            let b : int = paramTypeIntGetter(ctGlobal "b")
            let c : string = stepArgs.blockParam
            result = StepResult(args: stepArgs, value: srSuccess)
            try:
              echo c
              b = a
              paramTypeIntSetter(ctGlobal, "b", b)
            except:
              var exc = getCurrentException()
              result.value = srFail
              result.exception = exc
    
        let stepDef = StepDefinition(
          stepRE: stepRE, defn: stepDefinition, expectsBlock: false)
        stepDefinitions[stGiven].add(stepDef)
    
    Argument list syntax:
    
    Arguments are specified as a parenthesized list of ``name: type`` or
    ``location.name: type`` pairs. ``type`` refers to a parameter type (sic!
    *not* a nim type), which governs not only the (nim) type of the variable, 
    but also the regexp to recognize values in a gherkin step 
    specificiation, and functions to parse values and create initial values.
    
    The ``location`` field, if present, marks arguments as coming from
    context rather than from the step specification. There are
    three contexts: ``global``, ``feature`` and ``scenario`` whose 
    lifecycles are the lifetime of the runner, the current feature and
    the current scenario. Use contexts to pass information between
    steps and between hooks and steps.
    
    When a location is present variables can also have the form `var type`. 
    The var prefix means they are created as "var" parameters, and copied
    back into context on successful completion of the step.
  ]##

  let stepRE = genSym(nskLet, "stepRE")
  let nPattern = newLit(pattern)
  let stepDefinition = genSym(nskProc, "stepDefinition")
  let stepArgs = newIdentNode "stepArgs"
  let actual = genSym(nskLet, "actual")
  let stepText = newIdentNode "stepText"
  let match = newIdentNode "match"
  let get = newIdentNode "get"
  let captures = newIdentNode "captures"
  let stepDef = genSym(nskLet, "stepDef")
  let sresult = newIdentNode "result"
  let exc = newIdentNode "exc"
  let (defArgs, setContext, expectsBlock) = processStepArguments(actual, argList)
  let stepDefinitions = newBrkt("stepDefinitions", newIdentNode($stepType))
  let add = newIdentNode("add")
  result = quote do:
    let `stepRE` = re(`nPattern`)
    proc `stepDefinition`(`stepArgs`: StepArgs) : StepResult =
      let `actual` = `stepArgs`.`stepText`.`match`(`stepRE`).`get`.`captures`
      block:
        `defArgs`
        `sresult` = StepResult(args: `stepArgs`, value: srSuccess)
        try:
          `body`
          `setContext`
        except:
          var `exc` = getCurrentException()
          `sresult`.value = srFail
          `sresult`.exception = `exc`

    let `stepDef` = StepDefinition(
      stepRE: `stepRE`, defn: `stepDefinition`, expectsBlock: `expectsBlock`)
    `stepDefinitions` .`add`(`stepDef`)
  #mShow(result)

type ArgSpec = tuple
  aname: string
  atype: string
  aloc: ContextType
  avar: bool

proc unpackArg(argdef: NimNode) : ArgSpec =
  var anameN = argdef[0]
  var atypeN = argdef[1]
  var aname, atype : string
  var aloc : ContextType = ctNotContext
  var avar : bool = false
  if anameN.kind == nnkDotExpr:
    aloc = ctypeFor($anameN[0])
    aname = $anameN[1]
  else:
    aname = $anameN
  if atypeN.kind == nnkVarTy:
    avar = true
    atype = $atypeN[0]
  else:
    atype = $atypeN
  return (aname, atype, aloc, avar)

proc processStepArguments(actual : NimNode, arglist: NimNode) : ArgumentNodes =
  var defArgs = newStmtList()
  var setContext = newStmtList()
  let expectsBlock = newLit(false)
  result = (defArgs, setContext, expectsBlock)
  var iactual = -1
  for argdef in arglist:
    let (aname, atype, aloc, avar) = unpackArg(argdef)
    if aloc != ctNotContext:
      if avar:
        defArgs.add newVar(aname, cast[string](nil), newCall(
          ptName(atype, "Getter"), newIdentNode($aloc), newLit(aname)))
        setContext.add newCall(
          newIdentNode(ptName(atype, "Setter")), 
          newIdentNode($aloc), newLit(aname), newIdentNode(aname))
      else:
        defArgs.add newLet(aname, cast[string](nil), newCall(
          ptName(atype, "Getter"), newIdentNode($aloc), newLit(aname)))

    elif atype == "blockParam":
      defArgs.add newLet(aname, "string", newDot("stepArgs", "blockParam"))
      result.expectsBlock = newLit(true)
    else:
      iactual += 1
      defArgs.add newLet(aname, cast[string](nil), newCall(
        ptName(atype, "parseFct"), newBrkt(actual, newLit(iactual))))

macro Given*(
    pattern: static[string], arglist: untyped, body: untyped
    ) : typed =
  result = step(stGiven, pattern, arglist, body)

macro When*(
    pattern: static[string], arglist: untyped, body: untyped
    ) : typed =
  result = step(stWhen, pattern, arglist, body)

macro Then*(
    pattern: static[string], arglist: untyped, body: untyped
    ) : untyped {.immediate.} =
  result = step(stThen, pattern, arglist, body)
  #echo result.toStrLit.strVal

when isMainModule:
  import typeinfo

  Given r"(-?\d+)", (foo: int):
    echo "hello: " & $(foo + 1)
    raise newException(Exception, "XXX")

  When r"((?:yes)|(?:no))", (global.foo: int, bar: bool):
   echo "hello: " & $(foo + 1) & " " & $bar

  Then r"", (b: blockParam):
    echo "block: " & b

  var args = StepArgs(stepText: "1")

  var r = stepDefinitions[stGiven][0].defn(args)
  echo "result " & $r.value
  var exc = r.exception
  echo "exc " & $exc.getStackTrace()
  var a = 10;
  paramTypeIntSetter(ctGlobal, "foo", a)  
  args.stepText = "yes"
  r = stepDefinitions[stWhen][0].defn(args)
  echo "result " & $r.value

