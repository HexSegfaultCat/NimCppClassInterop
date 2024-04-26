discard """
targets: "cpp"
errormsg:
  "Missing implementation of method h(int): int (ensure the overridding method has pragma `cppOverride`)"
"""

import CppClassInterop

cppClass IFoo:
  proc f*(x: int): int {.cppAbstract.}
  proc g*(x: int): int {.cppAbstract.}
  proc h*(n: int): int {.cppAbstract.}

cppClass Foo of IFoo:
  proc f*(x: int): int {.cppOverride.} = discard
  proc g*(x: int): int {.cppOverride.} = discard

