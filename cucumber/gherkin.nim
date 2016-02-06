# cucumber-nim/gherkin.nim

import streams

proc read(file: File) : void = 
  var line = ""
  let lines = newFileStream(file)
  while lines.readline(line):
    echo line

read(stdin)