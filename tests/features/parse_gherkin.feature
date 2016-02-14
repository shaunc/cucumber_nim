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
        
Scenario: feature with explanation.
  Given a feature file:
  """
  Feature: parse gherkin
    Because I want to
  """
  When I read the feature file
  Then the feature description is "parse gherkin"
  And the feature explanation is "Because I want to"
  And the feature contains 0 scenarios
  And the feature contains 0 background blocks
