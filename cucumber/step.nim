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

export nre.re, nre.match, nre.Regex, nre.RegexMatch
export options.Option

type

  StepArgs* = ref object of RootObj
    stepText*: string
    blockParam*: string
    context*: Context

  StepDefinition* = object
    stepType*: StepType
    stepRE*: Regex
    defn*: proc(stepArgs: StepArgs) : StepResult
    expectsBlock*: bool

  StepDefinitions* = array[StepType, seq[StepDefinition]]

  ContextType = enum
    ctGlobal,
    ctFeature,
    ctScenario
  ResetContext = proc(): void

var stGiven0 : seq[StepDefinition] = @[]
var stWhen0 : seq[StepDefinition] = @[]
var stThen0 : seq[StepDefinition] = @[]
var stepDefinitions* : StepDefinitions = [stGiven0, stWhen0, stThen0]
var context*: Context = initTable[string, Any]()
var resetContext* = initTable[ContextType, seq[ResetContext]]()
resetContext[ctGlobal] = @[]
resetContext[ctFeature] = @[]
resetContext[ctScenario] = @[]

proc ctype(cname: string) : ContextType =
  case cname 
  of "global": result = ctGlobal
  of "feature": result = ctFeature
  of "scenario": result = ctScenario
  else:
    raise newException(Exception, "unknown context " & cname)

type
  ContextArg = tuple
    na: string
    lo: string
    ty: string

proc step(
    stepType: StepType, 
    pattern0: string,
    arglist: NimNode,
    body: NimNode) : NimNode =
  ## Creates a step definition.
  ## 
  ## The result will look something like this:
  ## 
  ##     let stepRE = re(stepPattern)
  ##     proc stepDefinition(stepArgs: StepArgs) : StepResult =
  ##       let actual = stepArgs.stepText.match(stepRE).get
  ##       block:
  ##         let arg1 : arg1Type = parseArg1(actual[0])
  ##         ...
  ##         let argN : argNType = parseArgN(actual[<N+1>])
  ##         var argC1 : argcC1Type = getC1Type(stepArgs.context, "global.argC1")
  ##         ...
  ##         try:
  ##           <body>
  ##           result = srSuccess
  ##           stepArgs.context["location.argC1"] = argC1
  ##           ...
  ##         except:
  ##           result = srFail
  ##     
  ## stepDefinitions.add(StepDefinition(stepRE: stepRE, defn: stepDefinition))
  ## var ctxArgC1 : ctxArgType = argC1TypeDefault
  ## proc resetCtxArgC1(): void =
  ##   resetArgC1Type(context, "global.argC1")
  ## if not context.hasKey("global.argC1"):
  ##   context["global.argC1"] = ctxArgC1
  ##   resetContext["global.argC1"] = resetCtxArgC1
  ## 
  ## 
  ## 
  ## Argument list syntax:
  ## 
  ## Arguments are specified as a parenthesized list of ``name: type`` or
  ## ``location.name: type`` pairs. ``type`` refers to a parameter type,
  ## which governs not only the type of the variable, but also the regexp
  ## to recognize values in a gherkin step specificiation, and functions
  ## to parse values and convert them from ``Any``.
  ## 
  ## The ``location`` field, if present, marks arguments as coming from
  ## context rather than from the step specification. Arguments from
  ## context are extracted from context using a key in the form 
  ## ``location.name``. Locations supported are ``global`` ``feature``
  ## and ``scenario``: keys with these prefixes are (re)initialized before
  ## the start of each scenario/feature/global run, so that steps
  ## and hooks can pass each other values.
  ## 
  ## Locations can also have the form `var global/feature/scenario`. The
  ## Var prefix means they are created as "var" parameters, and copied
  ## back into context on successful completion of the step.

  let pattern = pattern0
  let reID = genSym(nskLet, "stepRE")
  let procID = genSym(nskProc, "stepDefinition")
  let sdefID = genSym(nskLet, "stepDef")
  let actualID = genSym(nskLet, "actual")
  let bodyNode = newStmtList()
  var bodyAndFinal = newStmtList()
  for child in body:
    bodyAndFinal.add(child)
  var blockParam : string = nil
  var iactual = -1
  var contextArgs : seq[ContextArg] = @[]
  for i in 0..<arglist.len:
    let argDef = arglist[i]
    var aname: string;
    var aloc : string = nil;
    var atype = $argDef[1]
    var ainit : NimNode
    if argDef[0].kind == nnkDotExpr:
      aloc = $argDef[0][0]
      aname = $argDef[0][1]
    else:
      aname = $argDef[0]
      iactual += 1
    if aloc != nil:
      let key = newLit("$1.$2" % [aloc, aname]);
      let ncontext = newDotExpr(
        newIdentNode("stepArgs"), newIdentNode("context"))
      if aloc.startsWith("var"):
        aloc = aloc.split(" ")[1]
        bodyAndFinal.add(newAssignment(
          newTree(nnkBracketExpr, ncontext, key),
          newIdentNode(aname)))
      contextArgs.add((na: aname, lo: aloc, ty: atype))
      let getID = newIdentNode("get" & capitalize(atype))
      ainit = newCall(getID, ncontext.copy, key)  
    elif atype == "blockParam":
      blockParam = aname
      atype = "string"
      ainit = newDotExpr(newIdentNode("stepArgs"), newIdentNode("blockParam"))
    else:
      ainit = newCall(
        ptID(atype, "parseFct"), 
        newTree(nnkBracketExpr, actualID, newLit(iactual)))
    let aimpl = newTree(nnkVarSection, newIdentDefs(
      newIdentNode(aname), newIdentNode(atype), ainit))
    bodyNode.add(aimpl)
  bodyNode.add(newAssignment(
    newIdentNode("result"), newTree(
      nnkObjConstr,
      newIdentNode("StepResult"), 
      newColonExpr(newIdentNode("value"), newIdentNode("srSuccess")),
      newColonExpr(newIdentNode("exception"), newNilLit()))))
  bodyNode.add(newTree(
    nnkTryStmt, bodyAndFinal, newTree(
      nnkExceptBranch, newStmtList(
        newAssignment(
          newDotExpr(newIdentNode("result"), newIdentNode("value")), 
          newIdentNode("srFail")),
        newAssignment(
          newDotExpr(newIdentNode("result"), newIdentNode("exception")), 
          newCall(newIdentNode("getCurrentException")))
        ))))
  var wrapperParams = [
   newIdentNode("StepResult"),
   newIdentDefs(newIdentNode("stepArgs"), newIdentNode("StepArgs"))]
  var procBody : NimNode
  let nonBlockParams = arglist.len - (if blockParam == nil: 0 else: 1)
  if nonBlockParams > 0:
    procBody = newStmtList(
      newLetStmt(
        actualID, 
        newDotExpr(
          newDotExpr(
            newCall(
              newDotExpr(
                newDotExpr(
                  newIdentNode("stepArgs"), newIdentNode("stepText")),
                newIdentNode("match")), 
              reID.copy),
            newIdentNode("get")),
          newIdentNode("captures"))),
      newBlockStmt(bodyNode))
  else:
    procBody = bodyNode
  result = newStmtList(
    newLetStmt(
      reID.copy, 
      newCall(newIdentNode("re"), newLit(pattern))),
    newProc(
      procID.copy,
      wrapperParams,
      procBody),
    newLetStmt(
      sdefID.copy,
      newTree(
        nnkObjConstr,
        newIdentNode("StepDefinition"),
        newColonExpr(newIdentNode("stepType"), newIdentNode($stepType)),
        newColonExpr(newIdentNode("stepRE"), reID.copy),
        newColonExpr(newIdentNode("defn"), procID.copy),
        newColonExpr(newIdentNode("expectsBlock"), newLit(blockParam != nil)))
    ),
    newCall(
      newDotExpr(
        newTree(
          nnkBracketExpr, 
          newIdentNode("stepDefinitions"),
          newIdentNode($stepType)),
        newIdentNode("add")),
      sdefID.copy)
  )
  for a in contextArgs:
    let asuffix = capitalize(a.na) & capitalize(a.lo)
    let label = newLit("$1.$2" % [a.lo, a.na])
    echo $a, label.strVal
    let ctxVar = genSym(nskVar, "ctx" & asuffix)
    let atype = newIdentNode(a.ty)
    let adef = ptID(a.ty, "default")
    let ctxReset = genSym(nskProc, "resetCtx" & asuffix)
    let areset = newIdentNode("reset" & capitalize(a.ty))
    let nnot = newIdentNode("not")
    let nhasKey = newIdentNode("hasKey")
    let assignC = newAssignment(newBrkt("context", label), 
      newCall(newBrkt("toAny", "int"), ctxVar))
    let addReset = newCall(newDot(
      newBrkt("resetContext", $ctype(a.lo)), "add"), ctxReset)
    var argCoda = quote do:
      var `ctxVar` : `atype` = `adef`
      proc `ctxReset`() : void =
        `areset`(context, `label`)
      if `nnot` context.`nhasKey`(`label`):
        `assignC`
        `addReset`
    for stm in argCoda:
      result.add(stm)

  #echo result.toStrLit.strVal
  #echo result.treeRepr


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

  var args = StepArgs(stepText: "1", context: context)

  var r = stepDefinitions[stGiven][0].defn(args)
  echo "result " & $r.value
  var exc = r.exception
  echo "exc " & $exc.getStackTrace()
  var a = 10;
  args.context["global.foo"] = toAny[int](a)
  args.stepText = "yes"
  r = stepDefinitions[stWhen][0].defn(args)
  echo "result " & $r.value

