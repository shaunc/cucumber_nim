# app.nim

import "./testType"

{.push exportc.}

proc test1*(i: int): void =
  echo "test1", i

proc test2*(der: Der): void =
  let d2 = Der(der.up)
  echo "got it"
  discard d2

{.pop.}
