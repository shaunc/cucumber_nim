import dynlib
import os

type
  FN= (proc(i:int): void {.nimcall.})

var lib = loadLib("libapp.dynlib")
let fct: FN = cast[FN]((checkedSymAddr(lib, "test1")))
echo "FOO"
fct()
unloadLib(lib)
removeFile("libapp.dynlib")
