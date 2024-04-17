import unittest

import std/macros

import CppClassInterop

cppClass Foo {.cppPointerType.}:
  var xy: ptr Foo
  var yz: int = 5

  proc f*(x: int): int {.cppVirtual.} =
    echo "f called"
    if x > 0:
      discard this.g(x - 1)
    return 5

  proc g*(x: int): string {.cppVirtual.} =
    echo "g called"
    echo this.yz
    discard this.f(x)
    return "abc"

  proc h*(n: int): int {.cppVirtual.} =
    if n <= 0:
      return n
    else:
      return this.h(n - 1)

suite "Class tests":
  test "Example test":
    var x = newCpp[Foo]()
    discard x.f(5)
    discard x.h(10)

