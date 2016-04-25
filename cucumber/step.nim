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
  ColumnSetter* = proc(sval: string): void

  StepDefinitionObj* = object
    stepType*: StepType
    stepRE*: Regex
    defn*: proc(stepArgs: StepArgs) : StepResult
    blockParamName*: string
    columns*: TableRef[string, ColumnSetter]
  StepDefinition* = ref StepDefinitionObj

  StepDefinitionsObj* = object
    items: array[StepType, seq[StepDefinition]]
  StepDefinitions* = ref StepDefinitionsObj

var stGiven0 : seq[StepDefinition] = @[]
var stWhen0 : seq[StepDefinition] = @[]
var stThen0 : seq[StepDefinition] = @[]
var stepDefinitions* : StepDefinitions = StepDefinitions(
  items: [stGiven0, stWhen0, stThen0])

proc `[]`*(
    defs: StepDefinitions, stepType: StepType) : var seq[StepDefinition] = 
  defs.items[stepType]

proc stepTypeFor*(stName: string) : StepType {.procvar.} =
  case stName.substr().toLower
  of "given": return stGiven
  of "when": return stWhen
  of "then": return stThen
  else:
    raise newException(Exception, "Unexpected step type name \"$1\"" % stName)

type
  ArgumentNodes = tuple
    defArgs: NimNode
    setContext: NimNode
    blockParamName: NimNode
    patExpr: NimNode
    initColumns: NimNode

proc processStepArguments(
  actual: NimNode, arglist: NimNode, pattern: string, stepDef: NimNode
  ) : ArgumentNodes

proc step(
    stepType: StepType, 
    pattern: string,
    arglist: NimNode,
    body: NimNode) : NimNode =

  ##[
    Creates a step definition.
    
    The macros ``Given``, ``When``, ``Then``, below, are wrappers
    around this procedure. Given a call::
    
      Given r"this step contains a (-?\d+) and <e>", (
          a: int, global.b: var int, quote.c: string, column.d: seq[int],
          e: int):
        echo c
        b = a
    
    The resulting step definition would be::

      let stepRE = re(
        replace(r"this step contains a (-?\d+) and <e>", re("<e>"), 
          parseTypeIntPattern))
      proc stepDefinition(stepArgs: StepArgs) : StepResult =
        let actual = stepArgs.stepText.match(stepRE).get.captures
        block:
          let a : int = parseInt(actual[0])
          var b : int = paramTypeIntGetter(ctGlobal, "b")
          let c : string = paramTypeSeqIntGetter(ctQuote, "c")
          let d : seq[int] = paramTypeSeqIntGetter(ctTable, "d")
          let e : int = parseInt(actual[1])
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
        stepRE: stepRE, defn: stepDefinition, blockParamName: "c"
        columns: newTable[string, ColumnSetter]())
      stepDef.columns["d"] = proc(strVal: string): void = 
        paramTypeSeqIntColumnSetter("d", strVal)
      stepDefinitions[stGiven].add(stepDef)
    
    Argument list syntax:
    ---------------------
    
    Arguments are specified as a parenthesized list of ``name: type`` or
    ``location.name: type`` pairs. ``type`` refers to a parameter type (sic!
    *not* a nim type), which governs not only the (nim) type of the variable, 
    but also the regexp to recognize values in a gherkin step 
    specificiation, and functions to parse values and create initial values.

    The ``location`` field, if present, marks arguments as coming from
    somewhere besides the step specification: context, block quote or
    table. 

    For arguments from the step pattern order of arguments determines which 
    regex capture group is used to parse the value from.

    There are three contexts: ``global``, ``feature`` and ``scenario`` whose 
    lifecycles are the lifetime of the runner, the current feature and
    the current scenario. Use contexts to pass information between
    steps and between hooks and steps.
    
    When a context location is present variables can also have the form `var
    type`.  The var prefix means they are created as "var" parameters, and
    copied back into context on successful completion of the step.

    The ``quote`` location specifies the variable should contain the block
    quote associated with the step. Currently ``quote`` must always have type
    string.

    A ``column`` location specifies that the variable should contain a column
    from the table associated with the step. Table column should have a
    sequence type (e.g. ``seq[int]``). The type of the sequence (``int`` in
    the example) should be another parameter type -- it governs how elements
    should be parsed from the table.

    Named parameters
    ----------------

    If the step pattern contains placeholder -- that is, an identifier
    enclosed in angle brackets, (as in ``<foo>``) and there is an argument
    with that name (say  ``foo: int``), the default regex for that group (e.g.
    for an integer, ``(-?\d+)`` is substituted for the angle-bracketed
    identifier in the definition pattern. Note that the argument in the list
    still must come in the correct order to match the corresponding parameter.

    The scenario step may include a value for this identifier. Or the value
    may be substituted from the examples table.

  ]##

  let stepRE = genSym(nskLet, "stepRE")
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
  let (
      defArgs, setContext, blockParamName, 
      patExpr, initColumns) = processStepArguments(
    actual, argList, pattern, stepDef)
  let stepDefinitions = newBrkt("stepDefinitions", newIdentNode($stepType))
  let add = newIdentNode("add")
  result = quote do:
    let `stepRE` = re(`patExpr`)
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
      stepRE: `stepRE`, defn: `stepDefinition`, 
      blockParamName: `blockParamName`,
      columns: newTable[string, ColumnSetter]())
    `initColumns`
    `stepDefinitions` .`add`(`stepDef`)
  #mShow(result)

type ArgSpec = tuple
  aname: string
  atype: string
  aloc: ContextType
  avar: bool

proc unpackArg*(argdef: NimNode) : ArgSpec =
  var anameN = argdef[0]
  var atypeN = argdef[1]
  var aname, atype : string
  var aloc : ContextType = ctNotContext
  var avar : bool = false
  if anameN.kind == nnkDotExpr:
    aloc = contextTypeFor($anameN[0])
    aname = $anameN[1]
  else:
    aname = $anameN
  if atypeN.kind == nnkVarTy:
    avar = true
    atype = $atypeN[0]
  else:
    atype = atypeN.toStrLit.strVal
  return (aname, atype, aloc, avar)

##[ 

  React to placeholders in step definition pattern.

  The placeholder has a value in the step text. The default pattern for the
  type is substituted in place of the identifier. As the type pattern
  is not accessible, an expression to carry out the substitution is
  constructed and passed back.

2. aloc == ctTable:

  The placeholder stands for a column of values from step table. The
  pattern is left as step text also has the placeholder. Columns must
  have a sequence type. The setter for the underlying type is placed in
  "typePats" for the runner to use to fill in the context.

]##

proc subsPattern(
    pattern: string, patExpr: var NimNode, aname: string, atype: string
    ): void = 

  let pname = "<$1>" % aname
  if not (pname in pattern):
    return
  let npname = newLit(pname)
  let typePat = newIdentNode(ptName(atype, "pattern"))
  let patStmt = quote do:
    (`patExpr`).replace(re(`npname`), `typePat`)
  patExpr = patStmt[0] # remove "stmtlist" wrapper

##[
  Creates a statement mapping parameter name to column setter
  for column values.
]##
proc newColumnInit(aname: string, atype: string, stepDef: NimNode): NimNode =
  let csetter = ptName(atype, "columnSetter")
  let colTarget = newBrkt(newDot(stepDef, "columns"), aname.newLit)
  let strVal = newIdentNode("strVal")
  let csetStmt = newCall(csetter, aname.newLit, strVal)
  let slist = quote do:
    `colTarget` = proc(`strVal`: string): void =
      `csetStmt`
  result = slist[0]

proc processStepArguments(
    actual : NimNode, arglist: NimNode, pattern: string, stepDef: NimNode
    ) : ArgumentNodes =

  var defArgs = newStmtList()
  var setContext = newStmtList()
  let blockParamName = newNilLit()
  var pattern = pattern.substr
  var initColumns = newStmtList()
  var patExpr = newLit(pattern)
  result = (defArgs, setContext, blockParamName, patExpr, initColumns)
  var iactual = -1
  for argdef in arglist:
    let (aname, atype, aloc, avar) = unpackArg(argdef)
    if aloc != ctNotContext:
      if avar:
        if aloc == ctQuote:
          raise newException(
            StepDefinitionError, "Block quote may not be `var`.")
        if aloc == ctTable:
          raise newException(
            StepDefinitionError, "Step table column may not be `var`.")
        defArgs.add newVar(aname, cast[string](nil), newCall(
          ptName(atype, "Getter"), newIdentNode($aloc), newLit(aname)))
        setContext.add newCall(
          newIdentNode(ptName(atype, "Setter")), 
          newIdentNode($aloc), newLit(aname), newIdentNode(aname))
      else:
        if aloc == ctQuote:
          result.blockParamName = aname.newLit
        defArgs.add newLet(aname, cast[string](nil), newCall(
          ptName(atype, "Getter"), newIdentNode($aloc), newLit(aname)))
        if aloc == ctTable:
          initColumns.add(newColumnInit(aname, atype, stepDef))
    else:
      iactual += 1
      subsPattern(pattern, patExpr, aname, atype)
      defArgs.add newLet(aname, cast[string](nil), newCall(
        ptName(atype, "parseFct"), newBrkt(actual, newLit(iactual))))
    result.patExpr = patExpr
    result.initColumns = initColumns

macro Given*(
    pattern: static[string], arglist: untyped, body: untyped
    ) : typed =
  result = step(stGiven, pattern, arglist, body)

macro ShowGiven*(
    pattern: static[string], arglist: untyped, body: untyped
    ) : typed =
  result = step(stGiven, pattern, arglist, body)
  echo "Given --------------"
  echo result.toStrLit.strVal

macro When*(
    pattern: static[string], arglist: untyped, body: untyped
    ) : typed =
  result = step(stWhen, pattern, arglist, body)

macro ShowWhen*(
    pattern: static[string], arglist: untyped, body: untyped
    ) : typed =
  result = step(stWhen, pattern, arglist, body)
  echo result.toStrLit.strVal

macro Then*(
    pattern: static[string], arglist: untyped, body: untyped
    ) : typed  =
  result = step(stThen, pattern, arglist, body)

macro ShowThen*(
    pattern: static[string], arglist: untyped, body: untyped
    ) : typed  =
  result = step(stThen, pattern, arglist, body)
  echo result.toStrLit.strVal

when isMainModule:
  import typeinfo

  Given r"(-?\d+)", (foo: int):
    echo "hello: " & $(foo + 1)
    raise newException(Exception, "XXX")

  When r"((?:yes)|(?:no))", (global.foo: int, bar: bool):
   echo "hello: " & $(foo + 1) & " " & $bar

  Then r"", (quote.b: string, column.d: seq[int]):
    echo "block: " & b
    echo $d

  Given r"<foo>", (foo: int):
    echo "FOO" & $foo

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
  paramTypeStringSetter(ctQuote, "b", "hello")
  args.stepText = ""
  stepDefinitions[stThen][0].columns["d"]("4")
  r = stepDefinitions[stThen][0].defn(args)

