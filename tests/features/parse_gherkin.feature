# parse_gherkin.feature

Feature: Parse gherkin
  As a nim developer
  In order to specify what I want my code to do
  I want a tool that interprets ".feature" files written in gherkin

Scenario: trivial feature.
  When I read the feature file:
  """
  Feature: parse gherkin
  """
  Then the feature description is "parse gherkin"
  And the feature explanation is ""
  And the feature contains 0 scenarios
  And the feature has no background block

Scenario: a feature may be preceeded by blank lines.
  When I read the feature file:
  """


  Feature: parse gherkin
  """
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
  When I read the feature file:
  """
  Feature: parse gherkin
    Because I want to
  """
  Then the feature explanation is "Because I want to"
  And the feature contains 0 scenarios
  And the feature has no background block

Scenario: A feature may have a scenario.
  When I read the feature file:
  """
  Feature: parse gherkin

  Scenario: trivial scenario
  """
  Then the feature contains 1 scenarios
  And scenario 0 contains 0 steps

Scenario: A feature may have multiple scenarios.
  When I read the feature file:
  """
  Feature: parse gherkin

  Scenario: trivial scenario

  Scenario: another trivial scenario

  Scenario: a third trivial scenario
  """
  Then the feature contains 3 scenarios
  And scenario 0 contains 0 steps
  And scenario 1 contains 0 steps
  And scenario 2 contains 0 steps

Scenario: scenario may contain a step.
  When I read the feature file:
  """
  Feature: parse gherkin

  Scenario: trivial scenario
    Given nothing
  """
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
  When I read the feature file:
  """
  Feature: parse gherkin

  Scenario: trivial scenario
    Given nothing
    When nothing
    Then nothing
  """
  Then scenario 0 contains 3 steps
  And step 0 of scenario 0 is of type "Given"
  And step 1 of scenario 0 is of type "When"
  And step 2 of scenario 0 is of type "Then"

Scenario: subsequent steps starting with "And" have type of step before.
  When I read the feature file:
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
  When I read the feature file:
  """
  Feature: parse gherkin

  Scenario: trivial scenario
    Given block:
    """
    The block
    """
  """
  Then step 0 of scenario 0 has block parameter:
  """
  The block
  """

Scenario: The feature may contain background
  When I read the feature file:
  """
  Feature: parse gherkin

  Background: trivial background
  """
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
  When I read the feature file:
  """
  Feature: parse gherkin

  Background: trivial background
    Given nothing
  """
  Then the background contains 1 steps
  And step 0 of the background is of type "Given"
  And step 0 of the background has text "nothing"
  And step 0 of the background has no block parameter

Scenario: A feature may include a scenario outline.
  When I read the feature file:
  """
  Feature: parse gherkin

  Scenario Outline: trivial scenario outline
  """
  Then the feature contains 1 scenarios
  And scenario 0 contains 0 steps

Scenario: A scenario outline may include an example section.
  When I read the feature file:
  """
  Feature: parse gherkin

  Scenario Outline: trivial scenario outline
    Given I see <nsheep> sheep

    Examples:
      | nsheep |
      | 1      |
      | 2      |
  """
  Then the feature contains 1 scenarios
  And scenario 0 contains 1 example
  And example 0 of scenario 0 has 1 column
  And column 0 of example 0, scenario 0 is named "nsheep"

Scenario: A scenario outline may include multiple examples sections
  When I read the feature file:
  """
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

Scenario: Examples must have as many cells in each row as columns.
  Given a feature file:
  """
  Feature: parse gherkin

  Scenario Outline: trivial scenario outline
    Given I see <nsheep> sheep and <nfish> fish

    Examples:
      | nsheep |
      | 1      | foo |
      | 2      |
  """
  Then reading the feature file causes an error:
  """
  Line 8: Table row 2 elements, but 1 columns in table.

  >  | 1      | foo |
  """

Scenario: A feature may have a tag.
  When I read the feature file:
  """
  @tag1
  Feature: parse gherkin
  """
  Then the feature has tag "@tag1"

Scenario: A feature may have multiple tags.
  When I read the feature file:
  """
  @tag1 @tag2 @tag3
  Feature: parse gherkin
  """
  Then the feature has tags "@tag1 @tag2 @tag3"

Scenario: A feature may have tags specified on mulitple lines
  When I read the feature file:
  """
  @tag1
  @tag2
  Feature: parse gherkin
  """
  Then the feature has tag "@tag1 @tag2"

Scenario: A scenario may have a tag.
  When I read the feature file:
  """
  Feature: parse gherkin

  @tag1
  Scenario: somesuch
  """
  Then scenario 0 has tag "@tag1"

Scenario: A scenario may have multiple tags.
  When I read the feature file:
  """
  Feature: parse gherkin

  @tag1 @tag2 @tag3
  Scenario: somesuch
  """
  Then scenario 0 has tags "@tag1 @tag2 @tag3"

Scenario: A scenario may have tags specified on mulitple lines
  When I read the feature file:
  """
  Feature: parse gherkin
  
  @tag1
  @tag2
  Scenario: somesuch
  """
  Then scenario 0 has tags "@tag1 @tag2"

Scenario: Feature and scenarios may all have multiple tags
  When I read the feature file:
  """
  @tag1
  @tag2
  Feature: parse gherkin

  @tag1 @tag2 @tag3
  Scenario: somesuch

  @tag4
  @tag5
  Scenario: other
  """
  Then the feature has tag "@tag1 @tag2"
  Then scenario 0 has tags "@tag1 @tag2 @tag3"
  Then scenario 1 has tags "@tag4 @tag5"

# A feature file may contain comments
# Comments before feature are associated with the feature
# comments before scenario are associated with the scenario
# comments in scenario are associated with the scenario
# commends in tag lines are ignored
# comment start character in scenario heading is part of heading
# comment start character in steps is part of the step

# tables in steps

@check
Scenario: A step may define a table
  When I read the feature file:
  """
  Feature: parse gherkin

  Scenario: somesuch
    Given a table:
      | a | b |
      | 1 | 2 |
      | 3 | 3 |
  """
  Then step 0 of scenario 0 has table with 2 rows and columns:
    | name |
    | a    |
    | b    |
