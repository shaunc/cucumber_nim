type
  Obj* = ref object of RootObj
    foo*: int

  Der* = ref object of Obj
    up*: Obj
