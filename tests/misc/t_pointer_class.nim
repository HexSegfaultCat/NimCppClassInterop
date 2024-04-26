discard """
targets: "cpp"

# ---
output: '''
5
abc
'''
"""

import CppClassInterop

cppClass Foo {.cppPointerType.}:
  var xy: ptr Foo
  var yz: int = 5

  proc f*(x: int): int {.cppVirtual.} =
    return x

  proc g*(x: string): string {.cppVirtual.} =
    return x

var fooObj = newCpp[Foo]()
echo fooObj.f(5)
echo fooObj.g("abc")

