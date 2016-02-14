# parse_gherkin.feature

Feature: parse gherkin
  As a nim developer
  In order to develop with more agility
  I want to interpret ".feature" files written in gherkin

Scenario: trivial feature.
  Given a feature file:
  """
  Feature: parse gherkin
  """
  When I read the feature file
  Then the feature description is "parse gherkin"
  And the feature explanation is ""
  And the feature contains 0 scenarios
  And the feature contains 0 background blocks

Scenario: error if no feature.
  Given a feature file:
  """
  """
  Then reading the feature file causes an error:
  """
  Line 0: Feature must start with "Feature:".

  >
  """

Scenario: feature with explanation.
  Given a feature file:
  """
  Feature: parse gherkin
    Because I want to
  """
  When I read the feature file
  Then the feature explanation is "Because I want to"
  And the feature contains 0 scenarios
  And the feature contains 0 background blocks

Scenario: feature with trivial scenario.
  Given a feature file:
  """
  Feature: parse gherkin

  Scenario: trivial feature
  """
  When I read the feature file
  Then the feature contains 1 scenarios
  And scenario 0 contains 0 steps

Scenario: feature with two scenarios.
  Given a feature file:
  """
  Feature: parse gherkin

  Scenario: trivial feature

  Scenario: feature with explanation
  """
  When I read the feature file
  Then the feature contains 2 scenarios
  And scenario 0 contains 0 steps
  And scenario 1 contains 0 steps

Scenario: scenario containing a step.
  Given a feature file:
  """
  Feature: parse gherkin

  Scenario: trivial feature
    Given nothing
  """
  When I read the feature file
  Then the feature description is "parse gherkin"
  And the feature contains 1 scenarios
  And scenario 0 contains 1 steps
  And step 0 of scenario 0 is of type "Given"
  And step 0 of scenario 0 has text "nothing"
  And step 0 of scenario 0 has no block parameter

Scenario: error unknown step type.
  Given a feature file:
  """
  Feature: parse gherkin

  Scenario: trivial feature
    Taken nothing
  """
  Then reading the feature file causes an error:
  """
  Line 4: Step must start with "Given", "When", "Then", "And".

  >  Taken nothing
  """


