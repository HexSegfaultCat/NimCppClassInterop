discard """
targets: "cpp"
errormsg: "Multiple declarations of method f"
"""

import CppClassInterop

cppClass IFoo:
  proc f*(x: int): int {.cppAbstract.}
  proc g*(x: int): int {.cppAbstract.}
  proc h*(n: int): int {.cppAbstract.}

cppClass Foo of IFoo:
  proc f*(x: int): int {.cppOverride.} = discard
  proc f*(x: int): int {.cppOverride.} = discard
  proc g*(x: int): int {.cppOverride.} = discard
  proc h*(x: int): int {.cppOverride.} = discard

