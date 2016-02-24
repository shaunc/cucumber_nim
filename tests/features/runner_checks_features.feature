# runner checks features

Feature: check that code implements features
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

Scenario: matches simple step
  Given a step definition:
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
  Then there are 1 scenario results
  Then there is 1 successful scenario


# match single step
# pass parameter to step definition from step text
# pass parameter from context to step definition
# pass parameter from example table to step definition
# run background
# run scenario outline once for each row of examples
# run scenario outlines on join of example tables if more than one
# run feature over all examples if examples in background