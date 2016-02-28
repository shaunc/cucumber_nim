# define_steps.feature

@stepMod
Feature: Define steps implementations
  As a nim developer
  In order to test that my code meets my specifications
  I want to define implementations for the steps of scenarios in 
  my gherkin files.

# convert to outline: vary over step type.

Scenario Outline: trival definition of <stepType>.
  Given a <stepType> step definition:
  """
    <stepType> "a step definition:", ():
      discard
  """
  Then I have 1 <stepType> step definition
  Then step <stepType> 0 has pattern "a step definition:"
  Then step <stepType> 0 takes 0 arguments from step text.
  Then step <stepType> 0 takes 0 arguments from context.
  Then step <stepType> 0 expects no block.
  Then running step <stepType> 0 succeeds.

  Examples:
    | stepType |
    | Given |
    | When |
    | Then |

Scenario: definition pattern includes type regexes for placeholders.
  Given a step definition:
  """
    Given "a <foo>", (foo: int):
      discard foo
  """
  Then step Given 0 has pattern "a (-?\d+)"

Scenario: exception causes failure.
  Given a step definition:
  """
  Given "a failing step definition", ():
    assert 0 == 1
  """
  Then running step Given 0 fails with error:
  """
  false
  """

Scenario: reads argument from step text.
  Given a step definition:
  """
  Given r"a (\d+)", (a: int):
    assert a == 1
  """
  Then step Given 0 takes 1 arguments from step text.
  Then running step Given 0 succeeds with text "a 1"
  Then running step Given 0 fails with text "a 0"

Scenario: reads argument <value> from <context> context.
  Given a step definition:
  """
  Given "a step definition:", (<context>.a: int):
    assert a == 1
  """
  Then step Given 0 takes 1 arguments from context.
  When <context> context parameter a is <value>
  Then running step Given 0 <succeedsOrFails>.

  Examples:
  | context  |
  | global   |
  | feature  |
  | scenario |

  Examples:
  | value | succeedsOrFails |
  | 0     | fails           |
  | 1     | succeeds        |

Scenario: writes argument <value> to <context> context.
  Given a step definition:
  """
  Given "a step definition:", (<context>.a: var int):
    a = <value>
  """
  Then running step Given 0 succeeds.
  Then <context> context parameter a is <value>

  Examples:
  | context  |
  | global   |
  | feature  |
  | scenario |

  Examples:
  | value |
  | 0     |
  | 1     |

Scenario: reads argument from block quote (<succeedsOrFails>)
  Given a step definition:
  """
  Given "a step definition:", (quote.a: string):
    assert a.strip == "foo"
  """
  Then step Given 0 expects a block.
  Then step Given 0 <succeedsOrFails> with block <block>.

  Examples:
  | succeedsOrFails | block |
  | succeeds        | foo   |
  | fails           | bar   |


# TODO
# err: no var quote args
# block -- can be type convertable from string

# table column args
# err: no var column args
