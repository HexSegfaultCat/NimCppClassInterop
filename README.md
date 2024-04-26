# NimCppClassInterop

An incomplete library for interoperation with C++ libraries using `virtual` and `member` pragmas. I'm writing this library to learn Nim and to make it easier to wrap C++ libraries. It probably needs complete rewrite, but I'm still experimenting with Nim.

## Example (implementing a C++ interface from header file)

`./example_interface.h`
```c++
struct ExampleInterface {
  virtual int foo(const char* param1, int param2) = 0;
  virtual void bar_custom_name(int param1) = 0;
};
```

`./file.nim`
```nim
import CppClassInterop

from std/os import splitPath, joinPath

{.
  passC: "-I" & joinPath(currentSourcePath().splitPath().head, "headers")
}

cppClass Foo {.header: "example_interface.h", importcpp: "ExampleInterface".}:
  proc foo*(param1: cint): cint {.
    cppAbstract,
  .}
  proc bar*(param1: cint): void {.
    cppAbstract,
    cppName: "bar_custom_name",
  .}

cppClass Bar of Foo:
  proc foo*(param1: cint): cint {.cppOverride.} =
    echo param1

  proc bar*(param1: cint): void {.cppOverride.} =
    echo "bar"

var b = Bar()
discard b.foo(1)
b.bar(2)
```
