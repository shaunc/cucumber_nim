Cucumber_nim
=============

Implements the `cucumber BDD testing framework <https://cucumber.io/docs/reference>`_ in and for the nim programming language.

Cucumber ".feature" files (written in the "gherkin" language) allow tests to
be organized around features, which document the goals functionality of code
in terms of a short English description and a a number of scenarios, each
containing a number of steps, all of which are written in English, subject
to a few rules.

To implement tests for a feature, a developer writes step definitions, which
associate the code to implement steps with the specification of the step
via a regular expression.

See: `<https://github.com/cucumber/cucumber/wiki/Gherkin>`_ or
`<http://docs.behat.org/en/v2.5/guides/1.gherkin.html>` for more 
general information.

Status
------

Alpha. Contributions and more extensive tests welcome. However, at least
it is running its own features!

Installation
------------

(Pending inclusion in nimble index!)::

  nimble install cucumber

Usage
-----

Using cucumber_nim involves:

1. `Write features <#features>`_ 

2. `Write step definitions <#step-definitions>`_

3. `Write hook definitions <#hook-definitions>`_

4. `Write a main file to import all definitions <#main-file>`_

5. `Run <#command-line>`_

See the features, steps and main module in cucumber_nim's own ./tests/
for an example.

.. _features:

Features
~~~~~~~~

See the links above for more information about feature files. Cucumber_nim
features may differ from standard gherkin in a few ways:

1. Scenarios need not be indented. As there is only one feature per
feature file, the indentation of scenarios is superfluous. Steps
and examples do still need to be indented to group them with particular
scenarios.

2. The use of the ``Scenario Outline`` keyword is optional. If at least
one ``Examples`` section is present, a scenario will be run as if it
were a scenario outline.

3. More than one ``Examples`` section may be present. The rows
of examples are joined (in the database sense) to generate the final
set of rows used.

4. Background sections may have examples. If they do, all the scenarios
of the feature are run for each example row.

5. The special tag "@skip" can be used to specify features and/or scenarios
which are skipped by default.

.. _step definitions:

Step Definitions
~~~~~~~~~~~~~~~~

Define steps using the ``Given``, ``When`` and ``Then`` macros, which are
defined in "cucumber/step". They all take three arguments: a 
`pattern <#step-definition-patterns>`_,  
`arguments <#step-definition-arguments>`_, and a 
`body <#step-definition-body>`_.

For example::

  Given r"this step contains a (-?\d+) and <e>", (
      a: int, global.b: var int, quote.c: string, column.d: seq[int],
      e: int):
    assert c.strip == "Some text."
    assert e == 23
    b = a


Step Definition Patterns
........................

The pattern is the string specification of a regex. This regex is used to
match step specifications in feature files so the code in the body can be run
for the step. The pattern also specifies capture groups which are used to
capture strings that are parsed into arguments available to the step
implementation. Capture groups are assigned to arguments in order (ignoring
arguments which have qualifiers -- such as "global" or "quote", etc. See the
next section for more information). As a convenience, the pattern can also
include named arguments, surrounded by angle brackets (``<`` and  ``>``). If
there is an argument by this name in the argument list, then before the regex
is compiled, the default capture group for the 
`parameter type <#parameter-types>`_ is substituted into the pattern.

Step Definition Arguments
.........................

The arguments allow step definitions to be parameterized with information
from the steps, and also facilitate passing information between steps
and between steps and hooks. The argument list is a parenthesized list
of comma-delimited formal arguments. It must be present. A step definition
without arguments looks like::

  Given "this has no arguments", ():
    echo "We are running this step"

Each formal argument has the form::

  [<qualifer>.]name: [var] type

The optional qualifier allows arguments from other sources than the
step text. Allowed values are:

* ``global``: The argument is from global context, whose values persist
  over the runner session.

* ``feature``: The argument is from feature context, whose values are
  reset between features, but persist over all feature scenarios.

* ``scenario``: The argument is from scenario context, whose value are
  reset between scenarios (or different instances of scenario outlines),
  but persist over the steps of the scenario.

* ``quote``: The argument is from a block quote specified with the step.
  Such arguments must currently have type string.

* ``column``: The argument is a sequence of values taken from a column
  of a table specified by the step.

Context arguments (``global``, ``feature`` or ``scenario``- qualified) may
optionally include the ``var`` keyword. If they do, the variable is
modifiable, and will be copied back into the context after the body of the
step has been run.

Thus, in the example above::

  Given r"this step contains a (-?\d+) and <e>", (
      a: int, global.b: var int, quote.c: string, column.d: seq[int],
      e: int):

`a` matches the first pattern; `b` comes from global context, and, since
it is marked as `var`, is copied back into global context after the body
of the step runs; `c` is taken from a block quote specified with the step;
`d` is a sequence of integers taken from a column of a table specified with
the step; and `e` is parsed from the context using the default pattern for
integers (which is `r"(-?\d+)"`).

See the steps in package tests/steps for further examples.

Step Definition Body
....................

The body of the step definition will be executed as the implementation
of steps in features. The example code above will be compiled by the
``Given`` macro into a procedure more or less in the form of::

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
          assert c.strip == "Some text."
          assert e == 23
          b = a
          paramTypeIntSetter(ctGlobal, "b", b)
        except:
          var exc = getCurrentException()
          result.value = srFail
          result.exception = exc


Parameter Types
~~~~~~~~~~~~~~~

The type of a formal parameter is a "parameter type" -- which doesn't
(necessarily) correspond to a nim type. The "cucumber/parameters" defines some
common types (currently: int, string, bool and float, as well as sequences of
these). It also defines the ``DeclareParamType`` and ``DeclareRefParamType``
macros, which can be used to define other parameter types.


DeclareParamType
................

Form::

  DeclareParamType(name, ptype, parseFct, newFct, pattern)

Where:

* ``name``: Name of the parameter type (to be used in argument list
  specification).
* ``ptype``: Actual nim type (not quoted). Is used to declare variables
  in step definitions.
* ``parseFct``: Function which takes a string and returns parsed value
  of type ``ptype``. 

  Can be ``nil`` for arguments not from step text (e.g.
  which are just stored in context).
* ``newFct``: Function which can be used to initialize or create a value 
  of type ``ptype``. 

  If ``nil`` then ``nil`` will be used as initial value.
  (This is only legal if it is legal for ``ptype``).
  
* ``pattern``: string pattern which can be used as default capture in 
  regex. Can be nil; if defined must define exactly one capture group.


As a convenience::

  DeclareRefParamType(ptype)

is short for::

  DeclareParamType("<ptype>", ptype, nil, nil, nil)

This is useful for declaring reference parameter types stored in context.

Note when declaring parameter types, that the name in quotes needn't
correspond to the nim type name. This means for a given nim type you
can declare different parameter types, perhaps in order to use different
parsing functions, etc. Keep in mind that, in a step or hook definition,
parameters should be declared using the cucumber name (without quotes).

For example::

  DeclareParamType("IntA", int, parseIntA, newIntA, r"(\d+)")
  DeclareParamType("IntB", int, parseIntB, newIntB, r"(-?\d+)")

would be used like this in a step definition::

  Then "<a> is less than <b>", (a: IntA, b: IntB):
    assert a < b

When matching a step, `a` would accept strings using regex `r"(\d+)"`; 
`b` would match using `r"(-?\d+)"`, (and their respective parsers
would be used as well as their respective initialization functions
for default vaules).

Sequences as parameter types
............................

The columns of a step table are loaded into a sequence. Currently to
support this, when a parameter with a name like `seq[Foo]` is created,
cucumber will create a procedure to parse strings representing sequence
elements and add them to the sequence. This assumes the existence
of a function `parseFoo(string): Foo`, to parse the individual elements.

This is a temporary feature; in the future, either there will be a
special form of a parameter type declaration for parsing elements,
or cucumber will detect the presence of the function. In the meantime,
you can either declare a element parser, or you can use a name
that does not have the form `seq[...]` for the name of the parameter
type corresponding to a nim `seq`.


.. _hook definitions:

Hook Definitions
~~~~~~~~~~~~~~~~

Macros can be used to define hooks:

===========  ==============  ==============
Around What  Before          After
-----------  --------------  --------------
Global       BeforeAll       AfterAll
Feature      BeforeFeature   AfterFeature
Scenario     BeforeScenario  AfterScenario
Step         BeforeStep      AfterStep
===========  ==============  ==============

Hooks can run before or after processing of the given unit -- either
unilaterally or based on a tag filter associated with the hook.

Hook implementations looks like::

    BeforeAll @any, ():
      echo "Buckle your seatbelt, please"

    AfterScenario *[@foo, +[@bar, ~baz]], (scenario.a: int):
      assert a == 0

Hook macros take a `tag filter`_, an 
`argument list`_, and a `hook body`_.

Tag Filter
..........

The tag filter conditions when the hook is run. A hook with a filter specified
as ``@any`` will always run before or after the given event. Otherwise a
filter specification must have the form ``<tag>``,  ``~<tag filter>``,
``*[<filter list>]`` or ``+[<filter list>]``. Where ``<tag>`` is an individual
tag (an identifier starting with "@"), ``<tag filter>`` is another tag filter,
and ``filter list`` is a comma separated list of tag filters. The meanings of
the operators are:

===== ========
``~`` negation
``*`` and
``+`` or
===== ========

Argument List
.............

The argument list is similar to 
`the step definition argument list <#sd-arguments>`_. However, it can
only specify qualifiers ``global``, ``feature`` or ``scenario``.

Hook Body
.........

The hook body is nim code that can use the arguments, similarly to
a `step definition body`_.

Main File
~~~~~~~~~

The main file gathers together all of the implementations for the nim
compiler. Typically it will just call "cucumber/main.main" to load,
run and report on results. The main runner file in tests/run.nim for
cucumber_nim itself looks like::

  import "../cucumber"
  import "./steps/featureSteps"
  import "./steps/stepDefinitionSteps"
  import "./steps/hookDefinitionSteps"
  import "./steps/dynmodHooks"
  import "./steps/runnerSteps"

  when isMainModule:
    let nfail = main()
    if nfail > 0:
      quit(nfail)


Command Line
~~~~~~~~~~~~

```cucumber/main.main`` parses the command line, taking options and
feature file paths.

If no file paths are included, paths ``./features`` and ``./tests/features``
are searched recursively for ``.feature`` files. If one or more paths are
specified then the given feature files or directories containing feature files
are used instead of the default.

Options include:

* `-v` `--verbosity`: Verbosity of runner and reporter. Currently:

  * `-2`: very quiet: return code is \# of errors

  * `-1`: quiet: lists features run and failing scenarios

  * `0` (default): lists features and scenarios; writes exception info for
  caught exceptions.

  * `1`: logs when features are executing

  * `2`: logs when features and scenarios are executing

  * `3`: logs when features, scenarios and steps are executing

  * `4`: logs when features, scenarios, steps and hooks are executing

  * `5`: logs all of the above, and also lists attempted regex matches
  for steps and tag matches for hooks.

* `-b` `--bail`: stop on first failure or undefined step

* `-t` `--tags`: only run tags matching spec (in format of
  `hook tag filter <#tag-filter>`_). The default is ``~@skip``.

* `-d` `--define`: define a comma-separated list of tags globally.

Debugging Aids
~~~~~~~~~~~~~~

The `steps` module contains `ShowGiven`, `ShowWhen` and `ShowThen`, which
dump the resulting nim code to the console as well as generating 
the step definitions.

Testing -- SECURITY WARNING
---------------------------

**WARNING** Currently, in order to test step and hook definition macros,
tests write source to a temporary file generated by mktemp, compile this
source into a dll and link to it dynamically. This is insecure as attacker
could overwrite either the source, object or dll files. Until a better
method is found (PRs happily accepted!) please use with caution. Automated
testing should be done in a safe environment (e.g. appropriately configured
docker instance).

Run:

    nim c -r --verbosity:0 ./tests/run

or:

    nimble tests

To run tests.


