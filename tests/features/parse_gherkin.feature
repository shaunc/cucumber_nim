# parse_gherkin.feature

Feature: Parse gherkin
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
  And the feature has no background block

Scenario: a feature may be preceeded by blank lines.
  Given a feature file:
  """


  Feature: parse gherkin
  """
  When I read the feature file
  Then the feature description is "parse gherkin"
  And the feature explanation is ""
  And the feature contains 0 scenarios
  And the feature has no background block

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
  And the feature has no background block

Scenario: A feature may have a scenario.
  Given a feature file:
  """
  Feature: parse gherkin

  Scenario: trivial scenario
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

  Scenario: trivial scenario
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

  Scenario: trivial scenario
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

  Scenario: trivial scenario
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

  Scenario: trivial scenario
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

  Scenario: trivial scenario
    And nothing
  """
  Then reading the feature file causes an error:
  """
  Line 4: First step cannot be "And"

  >  And nothing
  """

Scenario: A step may include a block parameter.
  Given a feature file:
  """
  Feature: parse gherkin

  Scenario: trivial scenario
    Given block:
    """
    The block
    """
  """
  When I read the feature file
  Then step 0 of scenario 0 has block parameter:
  """
  The block
  """

Scenario: The feature may contain background
  Given a feature file:
  """
  Feature: parse gherkin

  Background: trivial background
  """
  When I read the feature file
  Then the feature has a background block
  And the background contains 0 steps

Scenario: The feature may not contain more than one background section
  Given a feature file:
  """
  Feature: parse gherkin

  Background: trivial background

  Background: more trivial background
  """
  Then reading the feature file causes an error:
  """
  Line 5: Feature may not have more than one background section.

  >  Background: more trivial background 
  """

Scenario: background may contain a step.
  Given a feature file:
  """
  Feature: parse gherkin

  Background: trivial background
    Given nothing
  """
  When I read the feature file
  Then the background contains 1 steps
  And step 0 of the background is of type "Given"
  And step 0 of the background has text "nothing"
  And step 0 of the background has no block parameter

Scenario: A feature may include a scenario outline.
  Given a feature file:
  """
  Feature: parse gherkin

  Scenario Outline: trivial scenario outline
  """
  When I read the feature file
  Then the feature contains 1 scenarios
  And scenario 0 contains 0 steps

Scenario: A scenario outline may include an example section.
  Given a feature file:
  """
  Feature: parse gherkin

  Scenario Outline: trivial scenario outline
    Given I see <nsheep> sheep

    Examples:
      | nsheep |
      | 1      |
      | 2      |
  """
  When I read the feature file
  Then the feature contains 1 scenarios
  And scenario 0 contains 1 example
  And example 0 of scenario 0 has 1 column
  And column 0 of example 0, scenario 0 is named "nsheep"

Scenario: A scenario outline may include multiple examples sections
  Feature: parse gherkin

  Scenario Outline: trivial scenario outline
    Given I see <nsheep> sheep and <nfish> fish

    Examples:
      | nsheep |
      | 1      |
      | 2      |
    Examples:
      | nfish |
      | 3     | 
      | 8     |
  """
  Then scenario 0 contains 2 examples


# tables in steps
# A feature may have a tag
# A feature may have multple tags
# A feature may have tags specified on multiple lines
# A scenario may have a tag
# A scenario may have multiple tags
# A feature file may contain comments
# Comments before feature are associated with the feature
# comments before scenario are associated with the scenario
# comments in scenario are associated with the scenario
# commends in tag lines are ignored
# comment start character in scenario heading is part of heading
# comment start character in steps is part of the step


