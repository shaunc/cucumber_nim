# runner checks features

@defMod
@runnerMod
Feature: discover whether code tested implements features
  As a nim developer
  In order to insure my code implements the features I want it to
  I want to run the steps in each scenario, and check whether
  they can be successfully completed.

Scenario: run trivial feature
  When I run the feature:
  """
  Feature: parse gherkin
  """
  Then there are 0 scenario results

Scenario: run scenario with single step
  Given step definitions:
  """
  Given "I did something", ():
    discard
  """
  When I run the feature:
  """
  Feature: parse gherkin

  Scenario: simple
    Given I did something
  """
  Then scenario results are distributed: [1, 0, 0, 0].

Scenario: run two scenarios
  Given step definitions:
  """
  Given "I did something", ():
    discard
  """
  When I run the feature:
  """
  Feature: parse gherkin

  Scenario: simple
    Given I did something

  Scenario: simple2
    Given I did something
  """
  Then scenario results are distributed: [2, 0, 0, 0].

Scenario: run failing step
  Given step definitions:
  """
  Given "I screwed up", ():
    assert false
  """
  When I run the feature:
  """
  Feature: parse gherkin

  Scenario: simple
    Given I screwed up
  """
  Then scenario results are distributed: [0, 1, 0, 0].

Scenario: run skipped scenario
  Given step definitions:
  """
  Given "I did something", ():
    discard
  """
  When I run the feature:
  """
  Feature: parse gherkin

  @skip
  Scenario: simple
    Given I did something
  """
  Then scenario results are distributed: [0, 0, 1, 0].

Scenario: run step without definition
  When I run the feature:
  """
  Feature: parse gherkin

  Scenario: simple
    Given don't know how to do this
  """
  Then scenario results are distributed: [0, 0, 0, 1].

Scenario: run all examples in scenario outline
  Given step definitions:
  """
  Given "I did something", ():
    discard
  """
  When I run the feature:
  """
  Feature: parse gherkin

  Scenario Outline: simple <trial>
    Given I did something

    Examples:
    | trial |
    | 1     |
    | 2     |
  """
  Then scenario results are distributed: [2, 0, 0, 0].

Scenario: run all examples in scenario outline with join
  Given step definitions:
  """
  Given "I did something", ():
    discard
  """
  When I run the feature:
  """
  Feature: parse gherkin

  Scenario Outline: simple <trial> <cross>
    Given I did something

    Examples:
    | trial |
    | 1     |
    | 2     |

    Examples:
    | cross |
    | 1     |
    | 2     |
  """
  Then scenario results are distributed: [4, 0, 0, 0].


Scenario: run <hookType> hooks
  Given a step definition:
  """
  Then "scenario.i is 1", (scenario.i: var int):
    assert i == 1
    inc(i)
  """  
  Given hook definitions:
  """
  <hookBefore> @any, (scenario.i: var int):
    i = 1
  <hookAfter> @any, (scenario.i: var int):
    assert i == 2
  """
  When I run the feature:
  """
  Feature: parse gherkin

  Scenario: assume i is 1
    Then scenario.i is 1
  """
  Examples:
  | hookType | hookBefore     | hookAfter     |
  | Global   | BeforeAll      | AfterAll      |
  | Feature  | BeforeFeature  | AfterFeature  |
  | Scenario | BeforeScenario | AfterScenario |
  | Step     | BeforeStep     | AfterStep     |

Scenario: run "<hookType>" hooks based on tag specified in options
  Given a step definition:
  """
  Then "scenario.i is 1", (scenario.i: var int):
    assert i == 1
    inc(i)
  """  
  Given hook definitions:
  """
  <hookBefore> @foo, (scenario.i: var int):
    i = 2
  <hookAfter> @foo, (scenario.i: var int):
    assert i == 3

  <hookBefore> @bar, (scenario.i: var int):
    i = 1
  <hookAfter> @bar, (scenario.i: var int):
    assert i == 2
  """
  When I run the feature with "@bar" defined:
  """
  Feature: parse gherkin

  Scenario: assume i is 1
    Then scenario.i is 1
  """
  Examples:
  | hookType | hookBefore     | hookAfter     |
  | Global   | BeforeAll      | AfterAll      |
  | Feature  | BeforeFeature  | AfterFeature  |
  | Scenario | BeforeScenario | AfterScenario |
  | Step     | BeforeStep     | AfterStep     |

Scenario: run <hookType> hooks based on tag (specified for feature)
  Given a step definition:
  """
  Then "scenario.i is 1", (scenario.i: var int):
    assert i == 1
    inc(i)
  """  
  Given hook definitions:
  """
  <hookBefore> @foo, (scenario.i: var int):
    i = 2
  <hookAfter> @foo, (scenario.i: var int):
    assert i == 3

  <hookBefore> @bar, (scenario.i: var int):
    i = 1
  <hookAfter> @bar, (scenario.i: var int):
    assert i == 2
  """
  When I run the feature:
  """
  @bar
  Feature: parse gherkin

  Scenario: assume i is 1
    Then scenario.i is 1
  """
  Then scenario results are distributed: [1, 0, 0, 0].

  Examples:
  | hookType | hookBefore     | hookAfter     |
  | Feature  | BeforeFeature  | AfterFeature  |
  | Scenario | BeforeScenario | AfterScenario |
  | Step     | BeforeStep     | AfterStep     |

Scenario: run <hookType> hooks based on tag (specified for scenario)
  Given a step definition:
  """
  Then "scenario.i is 1", (scenario.i: var int):
    assert i == 1
    inc(i)
  """  
  Given hook definitions:
  """
  <hookBefore> @foo, (scenario.i: var int):
    i = 2
  <hookAfter> @foo, (scenario.i: var int):
    assert i == 3

  <hookBefore> @bar, (scenario.i: var int):
    i = 1
  <hookAfter> @bar, (scenario.i: var int):
    assert i == 2
  """
  When I run the feature:
  """
  Feature: parse gherkin

  @bar
  Scenario: assume i is 1
    Then scenario.i is 1
  """
  Then scenario results are distributed: [1, 0, 0, 0].

  Examples:
  | hookType | hookBefore     | hookAfter     |
  | Scenario | BeforeScenario | AfterScenario |
  | Step     | BeforeStep     | AfterStep     |

Scenario: run <hookType> hooks based on combined feature & scenario tags
  Given a step definition:
  """
  Then "scenario.i is 1", (scenario.i: var int):
    assert i == 1
    inc(i)
  """  
  Given hook definitions:
  """
  <hookBefore> *[@foo,~@bar], (scenario.i: var int):
    i = 2
  <hookAfter> *[~@foo,@bar], (scenario.i: var int):
    assert i == 3

  <hookBefore> *[@foo,@bar], (scenario.i: var int):
    i = 1
  <hookAfter> *[@foo,@bar], (scenario.i: var int):
    assert i == 2
  """
  When I run the feature:
  """
  @foo
  Feature: parse gherkin

  @bar
  Scenario: assume i is 1
    Then scenario.i is 1
  """
  Then scenario results are distributed: [1, 0, 0, 0].

  Examples:
  | hookType | hookBefore     | hookAfter     |
  | Scenario | BeforeScenario | AfterScenario |
  | Step     | BeforeStep     | AfterStep     |


Scenario: run feature background
  Given step definitions:
  """
  Given "i set to 1", (scenario.i: var int):
    i = 1

  Then "scenario.i is 1", (scenario.i: var int):
    assert i == 1
    inc(i)
  """
  When I run the feature:
  """
  Feature: parse gherkin

  Background:
    Given i set to 1

  Scenario: assume 1 is 1
    Then scenario.i is 1
  """  
  Then scenario results are distributed: [1, 0, 0, 0].

# Scenario: run feature background and scenarios for each background example

# Scenario: <clear> <context> context before <testNode>

#   Examples: 
#   | context   | testNode | clear |
#   | global    | feature  | false |
#   | global    | scenario | false |
#   | global    | step     | false |
#   | feature   | feature  | true  |
#   | feature   | scenario | false |
#   | feature   | step     | false |
#   | scenario  | feature  | true  |
#   | scenario  | scenario | true  |
#   | scenario  | step     | false |

  # Given step definitions:
  # """
  # Given "scenario.i set from feature context", (
  #     feature.ifeat: int, scenario.i: var int):
  #   i = ifeat
  # """


# match single step
# pass parameter to step definition from step text
# pass parameter from context to step definition
# pass parameter from example table to step definition
# run background
# run scenario outline once for each row of examples
# run scenario outlines on join of example tables if more than one
# run feature over all examples if examples in background