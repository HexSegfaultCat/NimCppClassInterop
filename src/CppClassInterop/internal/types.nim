import std/[macros, typetraits]
import std/[strutils, strformat]
import std/sequtils
import std/options

type MethodKind* {.pure.} = enum
  Abstract,
  Virtual,
  Member,

type CppPragma* {.byRef.} = object
  name*: NimNode
  value*: Option[NimNode]

type CppAst* {.byRef.} = object
  node*: NimNode
  pragmas*: seq[CppPragma] = @[]

type CppParameter* {.byRef.} = object
  name*: NimNode
  cppType*: NimNode
  cppConst*: bool
  cppReference*: bool

type MethodType* {.byRef.} = object
  ast*: CppAst = CppAst()
  name*: NimNode
  kind*: MethodKind
  cppName*: string
  isImported*: bool
  isOverriding*: bool
  returnType*: CppParameter
  parameters*: seq[CppParameter] = @[]

type ClassType* {.byRef.} = object
  ast*: CppAst = CppAst()
  name*: NimNode
  baseClass*: ref ClassType = nil
  methods*: seq[ref MethodType] = @[]
  cppName*: string

var cppTypes* {.compileTime.}: seq[ref ClassType] = @[]

