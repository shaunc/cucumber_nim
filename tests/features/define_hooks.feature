# define_hooks.feature

@hookMod
Feature: Define hook implementations
  As a nim developer
  In order to test that my code meets my specifications
  I want to define implement hooks to be called during the testing process.

Scenario Outline: trival definition of <hookType>.
  Given a <hookType> hook definition:
  """
    <hookType> @any, ():
      discard
  """
  Then I have 1 <hookType> hook definition
  Then hook <hookType> 0 has no tags
  Then hook <hookType> 0 takes 0 arguments from context.
  Then running hook <hookType> 0 succeeds.

  Examples:
    | hookType |
    | BeforeAll |
    | AfterAll |
    | BeforeFeature |
    | AfterFeature |
    | BeforeScenario |
    | AfterScenario |
    | BeforeStep |
    | AfterStep |

Scenario: reads argument <value> from <context> context.
  Given a hook definition:
  """
  BeforeAll @any, (<context>.a: int):
    assert a == <value>
  """
  Then hook BeforeAll 0 takes 1 arguments from context.
  When <context> context parameter a is <value>
  Then running hook BeforeAll 0 <succeedsOrFails>.

  Examples:
  | context  |
  | global   |
  | feature  |
  | scenario |

  Examples:
  | value | succeedsOrFails |
  | 0     | succeeds        |
  | 1     | succeeds        |

Scenario: writes argument <value> from <context> context.
  Given a hook definition:
  """
  BeforeAll @any, (<context>.a: var int):
    a = 1
  """
  Then hook BeforeAll 0 takes 1 arguments from context.
  Then running hook BeforeAll 0 succeeds.
  Then <context> context parameter a is 1

  Examples:
  | context  |
  | global   |
  | feature  |
  | scenario |


@hookFilters
Scenario: with filter "<filter>", hook tag filter <matches> {<set>}.
  Given a hook definition:
  """
    BeforeAll <filter>, ():
      discard
  """
  Then hook BeforeAll 0 tag filter <matches> {<set>}.

  Examples:
  | filter       | set       | matches       |
  | @any         |           | matches       |
  | @foo         |           | doesn't match |
  | @foo         | @foo      | matches       |
  | @foo         | @bar      | doesn't match |
  | @foo         | @foo,@bar | matches       |
  | ~@foo        |           | matches       |
  | ~@foo        | @foo      | doesn't match |
  | ~@foo        | @bar      | matches       |
  | ~@foo        | @foo,@bar | doesn't match |
  | *[]          |           | matches       |
  | *[]          | @foo      | matches       |
  | ~*[]         |           | doesn't match |
  | ~*[]         | @foo      | doesn't match |
  | +[]          |           | doesn't match |
  | +[]          | @foo      | doesn't match |
  | ~+[]         |           | matches       |
  | ~+[]         | @foo      | matches       |
  | *[@foo]      |           | doesn't match |
  | *[@foo]      | @foo      | matches       |
  | *[@foo]      | @bar      | doesn't match |
  | *[@foo]      | @foo,@bar | matches       |
  | ~*[@foo]     |           | matches       |
  | ~*[@foo]     | @foo      | doesn't match |
  | ~*[@foo]     | @bar      | matches       |
  | ~*[@foo]     | @foo,@bar | doesn't match |
  | +[@foo]      |           | doesn't match |
  | +[@foo]      | @foo      | matches       |
  | +[@foo]      | @bar      | doesn't match |
  | +[@foo]      | @foo,@bar | matches       |
  | ~+[@foo]     |           | matches       |
  | ~+[@foo]     | @foo      | doesn't match |
  | ~+[@foo]     | @bar      | matches       |
  | ~+[@foo]     | @foo,@bar | doesn't match |
  | *[@f,@b]     |           | doesn't match |
  | *[@f,@b]     | @f        | doesn't match |
  | *[@f,@b]     | @b        | doesn't match |
  | *[@f,@b]     | @f,@b     | matches       |
  | ~*[@f,@b]    |           | matches       |
  | ~*[@f,@b]    | @f        | matches       |
  | ~*[@f,@b]    | @b        | matches       |
  | ~*[@f,@b]    | @f,@b     | doesn't match |
  | +[@f,@b]     |           | doesn't match |
  | +[@f,@b]     | @f        | matches       |
  | +[@f,@b]     | @b        | matches       |
  | +[@f,@b]     | @f,@b     | matches       |
  | ~+[@f,@b]    |           | matches       |
  | ~+[@f,@b]    | @f        | doesn't match |
  | ~+[@f,@b]    | @b        | doesn't match |
  | ~+[@f,@b]    | @f,@b     | doesn't match |
  | *[@f,~@b]    |           | doesn't match |
  | *[@f,~@b]    | @f        | matches       |
  | *[@f,~@b]    | @b        | doesn't match |
  | *[@f,~@b]    | @f,@b     | doesn't match |
  | ~*[@f,~@b]   |           | matches       |
  | ~*[@f,~@b]   | @f        | doesn't match |
  | ~*[@f,~@b]   | @b        | matches       |
  | ~*[@f,~@b]   | @f,@b     | matches       |
  | +[@f,~@b]    |           | matches       |
  | +[@f,~@b]    | @f        | matches       |
  | +[@f,~@b]    | @b        | doesn't match |
  | +[@f,~@b]    | @f,@b     | matches       |
  | ~+[@f,~@b]   |           | doesn't match |
  | ~+[@f,~@b]   | @f        | doesn't match |
  | ~+[@f,~@b]   | @b        | matches       |
  | ~+[@f,~@b]   | @f,@b     | doesn't match |
  | *[@f,+[@b,@z]] | @f       | doesn't match |
  | *[@f,+[@b,@z]] | @b       | doesn't match |
  | *[@f,+[@b,@z]] | @f,@b    | matches       |
  | *[@f,+[@b,@z]] | @f,@z    | matches       |
  | *[@f,+[@b,@z]] | @b,@z    | doesn't match |
  | *[@f,+[@b,@z]] | @f,@b,@z | matches       |
  | +[@f,*[@b,@z]] | @f       | matches       |
  | +[@f,*[@b,@z]] | @b       | doesn't match |
  | +[@f,*[@b,@z]] | @f,@b    | matches       |
  | +[@f,*[@b,@z]] | @f,@z    | matches       |
  | +[@f,*[@b,@z]] | @b,@z    | matches       |
  | +[@f,*[@b,@z]] | @f,@b,@z | matches       |


