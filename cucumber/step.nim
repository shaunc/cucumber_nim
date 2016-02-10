# cucumber/step

import macros
import nre
import options
import "./parameter"
import "./types"

export nre.re, nre.match, nre.Regex, nre.RegexMatch
export options.Option

type

  StepArgs* = ref object of RootObj
    stepText*: string
    blockParam*: string

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
  ##         var arg1 : arg1Type = parseArg1(actual[0])
  ##         ...
  ##         var argN : argNType = parseArgN(actual[<N+1>])
  ##         try:
  ##           <body>
  ##           result = srSuccess
  ##         except:
  ##           result = srFail
  ##     
  ## stepDefinitions.add(StepDefinition(stepRE: stepRE, defn: stepDefinition))
  ## 

  let pattern = pattern0
  let reID = genSym(nskLet, "stepRE")
  let procID = genSym(nskProc, "stepDefinition")
  let sdefID = genSym(nskLet, "stepDef")
  let actualID = genSym(nskLet, "actual")
  let bodyNode = newStmtList()
  var blockParam : string = nil
  for i in 0..<arglist.len:
    let argDef = arglist[i]
    let aname = $argDef[0]
    var atype = $argDef[1]
    var ainit : NimNode
    if atype == "blockParam":
      blockParam = aname
      atype = "string"
      ainit = newDotExpr(newIdentNode("stepArgs"), newIdentNode("blockParam"))
    else:
      ainit = newCall(
        ptID(atype, "parseFct"), 
        newTree(nnkBracketExpr, actualID, newLit(i)))
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
    nnkTryStmt, body, newTree(
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
  echo result.toStrLit.strVal
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

  Given r"(-?\d+)", (foo: int):
    echo "hello: " & $(foo + 1)
    raise newException(Exception, "XXX")

  When r"(-?\d+) ((?:yes)|(?:no))", (foo: int, bar: bool):
   echo "hello: " & $(foo + 1) & " " & $bar

  Then r"", (b: blockParam):
    echo "block: " & b

  var r = stepDefinitions[stGiven][0].defn(StepArgs(stepText: "1"))
  echo "result " & $r.value
  var exc = r.exception
  echo "exc " & $exc.getStackTrace()
  r = stepDefinitions[stWhen][0].defn(StepArgs(stepText: "1 yes"))
  echo "result " & $r.value

