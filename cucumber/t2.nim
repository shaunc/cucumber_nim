
import nre


let s = """

Given dfsdf
  sdfsfd

Given
  dfdf

When
"""

let stepStart = re"""(?m)^(?=Given|When|Then)"""

for r in s.split(stepStart):
  echo "*", r