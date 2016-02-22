# define_steps.feature

Feature: Define steps implementations
  As a nim developer
  In order to test that my code meets my specifications
  I want to define implementations for the steps of scenarios in 
  my gherkin files.

# convert to outline: vary over step type.

Scenario: trival definition:
  Given a step definition:
  """
    Given "a step definition:", ():
      discard
  """
  Then I have 1 "given" definition
  Then step "given" 0 has pattern "a step definition:"
  Then step "given" 0 takes 0 arguments from step text.
  Then step "given" 0 takes 0 arguments from context.
  Then step "given" 0 takes 0 arguments from outline examples.
  Then step "given" 0 expects no block.
  Then running step "given" 0 succeeds.

# check wrapper generation fails if step has invalid body?

Scenario: exception causes failure.
  Given a step definition:
  """
  Given "a failing step definition", ():
    assert 0 == 1
  """
  Then running step "given" 0 fails with error:
  """
  false
  """

Scenario: reads argument from step text.
  Given a step definition:
  """
  Given r"a (\d+)", (a: int):
    assert a == 1
  """
  Then step "given" 0 takes 1 arguments from step text.
  Then running step "given" 0 succeeds with text "a 1"
  Then running step "given" 0 fails with text "a 0"

# text arg
# context args
# var context arg

# outline args
# err: no var outline args

# block quote args
# err: no var quote args
# block -- can be type convertable from string

# table column args
# err: no var column args
