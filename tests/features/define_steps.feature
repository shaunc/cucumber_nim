# define_steps.feature

Feature: Define steps implementations
  As a nim developer
  In order to test that my code meets my specifications
  I want to define implementations for the steps of scenarios in 
  my gherkin files.

Scenario: trival definition:
  Given a step definition:
  """
    Given "a step definition:", ():
      echo "hello"
  """
  When I compile the step definitions
  Then I have 1 "given" definition
  Then step "given" 0 has pattern "a step definition:"
  Then step "given" 0 takes 0 arguments from step text.
  Then step "given" 0 takes 0 arguments from context.
  Then step "given" 0 takes 0 arguments from examples.
  Then step "given" 0 expects no block.
  Then running step 0 produces output:
  """
  hello
  """
