discard """
targets: "cpp"

# ---
output: '''
abcd
bar
'''
"""

import CppClassInterop

from std/os import splitPath, joinPath

{.
  passC: "-I" & joinPath(currentSourcePath().splitPath().head, "headers")
}

cppClass Foo {.header: "example_interface.h", importcpp: "ExampleInterface".}:
  proc foo*(param1 {.cppConst.}: ptr char, param2: cint): cint {.
    cppAbstract,
  .}
  proc bar*(param1: cint): void {.
    cppAbstract,
    cppName: "bar_custom_name",
  .}

cppClass Bar of Foo:
  proc foo*(param1 {.cppConst.}: ptr char, param2: cint): cint {.cppOverride.} =
    echo param1
    return param2

  proc bar*(param1: cint): void {.cppOverride.} =
    echo "bar"

converter toCharPointer*(x: cstring | string): ptr cchar =
  return cast[ptr cchar](addr x[0])

var someString = "abcd"
var barObj = Bar()

discard barObj.foo(someString, 100)
barObj.bar(200)

