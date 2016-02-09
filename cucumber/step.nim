# cucumber/step

import macros
import nre
import options
import "./parameter"


type
  StepType* = enum
    stGiven,
    stWhen,
    stThen

  ArgDef = tuple
    aname: string
    atype: string
  #ArgList[N : static[int]] = array[N, ArgDef]

  StepResult* = enum
    srSuccess
    srFail
    srSkip

  StepDefinition* = object
    re: Regex
    defn: proc(stepText: string) : StepResult

var stepDefinitionLibrary* : seq[StepDefinition] = @[]

proc arg(aname: string, atype: string) : ArgDef =
  result = (aname: aname, atype: atype)

macro step(
    stepType: static[StepType], 
    pattern: static[string],
    arglist: static[openArray[ArgDef]],
    body: untyped) : typed =
  ## Creates a step definition.
  ## 
  ## The result will look something like this:
  ## 
  ##     let stepXXRE = re(stepPattern)
  ##     proc stepXXDefinition(stepText: string) : StepResult =
  ##       let actual = stepText.match(stepRE).get
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
  ## stepDefinitionLibrary.add((re: stepRE, defn: stepXXDefinition))
  ## 
  let reNode = genSym(nskLet, "stepRE")
  let procIDNode = genSym(nskProc, "stepDefinition") #newIdentNode(stepName & "RE")
  let bodyNode = newStmtList()
  for i, argDef in arglist:
    let aimpl = newTree(nnkVarSection, newIdentDefs(
      newIdentNode(argDef.aname), newIdentNode(argDef.atype), 
      newCall(
        ptID(argDef.atype, "parseFct"), 
        newTree(nnkBracketExpr, newIdentNode("actual"), newLit(i))
      )))
    bodyNode.add(aimpl)
  bodyNode.add(newAssignment(
    newIdentNode("result"), newIdentNode("srSuccess")))
  bodyNode.add(newTree(
    nnkTryStmt, body, newTree(
      nnkExceptBranch, newAssignment(
        newIdentNode("result"), newIdentNode("srFail")))))
  result = newStmtList(
    newLetStmt(
      reNode.copy, 
      newCall(newIdentNode("re"), newLit(pattern))),
    newProc(
      procIDNode.copy,
      [ newIdentNode("StepResult"),
        newIdentDefs(newIdentNode("stepText"), newIdentNode("string")) ],
      newStmtList(
        newLetStmt(
          newIdentNode("actual"), 
          newDotExpr(
            newDotExpr(
              newCall(
                newDotExpr(
                  newIdentNode("stepText"),
                  newIdentNode("match")), 
                reNode.copy),
              newIdentNode("get")),
            newIdentNode("captures"))),
        newBlockStmt(bodyNode)
      )
    ),
    newCall(newDotExpr(
      newIdentNode("stepDefinitionLibrary"), newIdentNode("add")),
      newTree(
        nnkObjConstr,
        newIdentNode("StepDefinition"),
        newColonExpr(newIdentNode("re"), reNode.copy),
        newColonExpr(newIdentNode("defn"), procIDNode.copy)))
  )
  #echo result.toStrLit.strVal
  #echo result.treeRepr


step stGiven, r"(-?\d+)", [arg("foo", "int")]:
  echo "hello: " & $(foo + 1)
  raise newException(Exception, "XXX")

step stGiven, r"(-?\d+) ((?:yes)|(?:no))", [
    arg("foo", "int"), arg("bar", "bool")]:
  echo "hello: " & $(foo + 1) & " " & $bar

var r = stepDefinitionLibrary[0].defn("1")
echo "result " & $r
r = stepDefinitionLibrary[1].defn("1 yes")
echo "result " & $r
