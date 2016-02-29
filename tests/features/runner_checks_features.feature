# runner checks features

@featureHookMod
@featureStepMod
Feature: discover whether code tested implements features
  As a nim developer
  In order to insure my code implements the features I want it to
  I want to run the steps in each scenario, and check whether
  they can be successfully completed.

Background:
  Given a step definition:
  """
  Given "I did something", ():
    discard

  Given "I screwed up", ():
    assert false
  """

Scenario: run trivial feature
  When I run the feature:
  """
  Feature: parse gherkin
  """
  Then there are 0 scenario results

Scenario: run scenario with single step
  When I run the feature:
  """
  Feature: parse gherkin

  Scenario: simple
    Given I did something
  """
  Then scenario results are distributed: [1, 0, 0, 0].

Scenario: run two scenarios
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
  When I run the feature:
  """
  Feature: parse gherkin

  Scenario: simple
    Given I screwed up
  """
  Then scenario results are distributed: [0, 1, 0, 0].

Scenario: run skipped scenario
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

# Scenario: run all examples in scenario outline

# Scenario: run all examples in join of scenario outline example tables

# Scenario: run <hookType> hook

# Scenario: run feature background

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


# match single step
# pass parameter to step definition from step text
# pass parameter from context to step definition
# pass parameter from example table to step definition
# run background
# run scenario outline once for each row of examples
# run scenario outlines on join of example tables if more than one
# run feature over all examples if examples in background