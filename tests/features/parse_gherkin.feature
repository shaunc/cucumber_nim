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

Scenario: a feature may be preceeded by blank lines.
  Given a feature file:
  """


  Feature: parse gherkin
  """
  When I read the feature file
  Then the feature description is "parse gherkin"
  And the feature explanation is ""
  And the feature contains 0 scenarios
  And the feature contains 0 background blocks

Scenario: feature files must contain a feature.
  Given a feature file:
  """
  """
  Then reading the feature file causes an error:
  """
  Line 0: Feature must start with "Feature:".

  >
  """
Scenario: error if first line not feature.
  Given a feature file:
  """
  blah
  """
  Then reading the feature file causes an error:
  """
  Line 1: unexpected line before "Feature:".

  >  blah
  """

Scenario: feature file may not contain two features.
  Given a feature file:
  """
  Feature: Feature 1
  Feature: Feature 2
  """
  Then reading the feature file causes an error:
  """
  Line 2: Features cannot be nested.

  >  Feature: Feature 2  
  """

Scenario: A feature may have an explanation.
  Given a feature file:
  """
  Feature: parse gherkin
    Because I want to
  """
  When I read the feature file
  Then the feature explanation is "Because I want to"
  And the feature contains 0 scenarios
  And the feature contains 0 background blocks

Scenario: A feature may have a scenario.
  Given a feature file:
  """
  Feature: parse gherkin

  Scenario: trivial feature
  """
  When I read the feature file
  Then the feature contains 1 scenarios
  And scenario 0 contains 0 steps

Scenario: A feature may have multiple scenarios.
  Given a feature file:
  """
  Feature: parse gherkin

  Scenario: trivial scenario

  Scenario: another trivial scenario

  Scenario: a third trivial scenario
  """
  When I read the feature file
  Then the feature contains 3 scenarios
  And scenario 0 contains 0 steps
  And scenario 1 contains 0 steps
  And scenario 2 contains 0 steps

Scenario: scenario may contain a step.
  Given a feature file:
  """
  Feature: parse gherkin

  Scenario: trivial feature
    Given nothing
  """
  When I read the feature file
  Then scenario 0 contains 1 steps
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

Scenario: scenario may contain multiple steps.
  Given a feature file:
  """
  Feature: parse gherkin

  Scenario: trivial feature
    Given nothing
    When nothing
    Then nothing
  """
  When I read the feature file
  Then scenario 0 contains 3 steps
  And step 0 of scenario 0 is of type "Given"
  And step 1 of scenario 0 is of type "When"
  And step 2 of scenario 0 is of type "Then"

Scenario: subsequent steps starting with "And" have type of step before.
  Given a feature file:
  """
  Feature: parse gherkin

  Scenario: trivial feature
    Given nothing
    And nothing else
    When nothing
    And nothing else
    Then nothing
    And nothing else
  """
  When I read the feature file
  Then scenario 0 contains 6 steps
  And step 0 of scenario 0 is of type "Given"
  And step 1 of scenario 0 is of type "Given"
  And step 2 of scenario 0 is of type "When"
  And step 3 of scenario 0 is of type "When"
  And step 4 of scenario 0 is of type "Then"
  And step 5 of scenario 0 is of type "Then"

Scenario: A scenario's first step may not start with "And".
  Given a feature file:
  """
  Feature: parse gherkin

  Scenario: trivial feature
    And nothing
  """
  Then reading the feature file causes an error:
  """
  Line 4: First step cannot be "And"

  >  And nothing
  """

# Scenario: The feature may contain background
# scenario outline
# example blocks
# tags

