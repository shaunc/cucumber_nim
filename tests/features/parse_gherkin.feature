# parse_gherkin.feature

Feature: parse gherkin
  As a nim developer
  In order to develop with more agility
  I want to interpret ".feature" files

Scenario: simple file with only feature.
  Given a simple feature file:
  """
  Feature: parse gherkin
  """
  When I read the feature file
  Then the feature description is "parse gherkin"
  #And the feature contains 0 scenarios
  #And the feature contains 0 background
        
