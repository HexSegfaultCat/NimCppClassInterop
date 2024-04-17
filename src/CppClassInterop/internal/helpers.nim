import std/[macros, typetraits]
import std/[strutils, strformat]
import std/sequtils
import std/options

import types

proc declareClassType*(classType: ref ClassType): NimNode {.compileTime.} =
  let className = classType.name
  let lineInfo = className.lineInfoObj

  if classType.baseClass == nil:
    result = quote do:
      type `className`* {.byref, inheritable.} = object
  else:
    let baseClassName = classType.baseClass.name
    result = quote do:
      type `className`* {.byref.} = object of `baseClassName`

  result[0][0][0][1].setLineInfo(lineInfo)

proc getByName*(
  types: seq[ref ClassType],
  name: NimNode
): ref ClassType {.compileTime.} =
  name.expectKind(nnkIdent)

  # WARN: `types[0].name` might be a symbol (when class has `cppPointerType`), but `name` is always an ident
  let matchingTypes = types.filterIt(it.name.strVal == name.strVal)
  let matchingTypesCount = matchingTypes.len

  return (
    if matchingTypesCount > 1:
      error(
        fmt"Multiple declarations of the same class {name.strVal}",
        matchingTypes[1].name
      )
    elif matchingTypes.len == 0: nil
    else: matchingTypes[0]
  )

proc getPragma*(pragmas: seq[CppPragma], pragma: NimNode): Option[CppPragma] =
  expectKind(pragma, {nnkIdent, nnkSym})

  var foundItems = pragmas.filterIt(it.name.strVal == pragma.strVal)
  if foundItems.len > 1:
    error "Duplicated pragma " & pragma.strVal

  return (
    if foundItems.len == 0: none CppPragma
    else: some foundItems[0]
  )
