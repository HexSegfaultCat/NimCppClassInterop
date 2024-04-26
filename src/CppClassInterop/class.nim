import std/[macros, genasts, sugar]
import std/[strutils, strformat]
import std/sequtils
import std/options

import pragmas
import internal/[types, helpers]

proc processMethodNode(classType: ref ClassType, node: NimNode) {.compileTime.} =
  if node.pragma.kind == nnkEmpty:
    node.pragma = newNimNode(nnkPragma)

  var methodType = new MethodType
  classType.methods.add(methodType)

  methodType.name = node.name
  methodType.returnType = CppParameter(cppType: node.params[0])
  methodType.parameters = node.params
    .filterIt(it.kind == nnkIdentDefs)
    .map(it => (block:
      var parameter = CppParameter()

      parameter.cppType = it[1]
      if it[0].kind == nnkPragmaExpr:
        parameter.name = it[0][0]
        parameter.cppConst = it[0][1].mapIt(it.strVal).contains((genAst cppConst).strVal) # TODO: Fix this hacky solution
        parameter.cppReference = it[0][1].mapIt(it.strVal).contains((genAst cppRef).strVal) # TODO: Fix this hacky solution
      else:
        parameter.name = it[0]
        parameter.cppConst = false
        parameter.cppReference = false

      return parameter
    ))

  let isPointerType = classType.ast.pragmas.getPragma(genAst cppPointerType).isSome
  let classInstanceType = (
    if isPointerType: newNimNode(nnkPtrTy).add(classType.name)
    else: classType.name
  )
  node.params.insert(
    pos = 1,
    newIdentDefs(ident"this", classInstanceType),
  )

  methodType.ast.pragmas = node.pragma.mapIt(
    case it.kind:
      of nnkIdent: CppPragma(name: it, value: none NimNode)
      of nnkExprColonExpr: CppPragma(name: it[0], value: some it[1])
      else: error fmt"Unknown pragma type"
  )

  let foreignName = methodType.ast.pragmas.getPragma(genAst cppName)

  let hasAbstract = isSome methodType.ast.pragmas.getPragma(genAst cppAbstract)
  let hasVirtual = isSome methodType.ast.pragmas.getPragma(genAst cppVirtual)
  let hasOverride = isSome methodType.ast.pragmas.getPragma(genAst cppOverride)

  methodType.cppName = (
    if foreignName.isSome and not hasOverride:
      foreignName.get.value.get.strVal
    else:
      node.name.strVal
  )

  if classType.isImported:
    if hasOverride:
      error(
        fmt"Method {methodType.name} is imported from C++ code and cannot have override pragma",
        node
      )
  else:
    if hasAbstract and hasOverride:
      error(fmt"Method {methodType.name} cannot be both abstract and non-abstract", node)
    if hasAbstract and node[6].kind != nnkEmpty:
      error(fmt"Abstract method {methodType.name} cannot have an implementation", node)
    if hasOverride and foreignName.isSome:
      error(fmt"Overridding method {methodType.name} cannot have exported name defined", node)

    methodType.isOverriding = hasOverride
    methodType.kind = (
      if hasAbstract: MethodKind.Abstract
      elif hasVirtual: MethodKind.Virtual
      else: MethodKind.Member
    )

  methodType.ast.node = node

proc classMethodsValidations(classType: ref ClassType) {.compileTime.} =
  var abstractMethods: seq[ref MethodType] = @[]
  var overriddingMethods: seq[ref MethodType] = @[]

  var currentClass = classType
  while currentClass.baseClass != nil:
    for abstractMethod in currentClass.baseClass.methods.filterIt(it.kind == Abstract):
      abstractMethods.add(abstractMethod)
    for overriddingMethod in currentClass.methods.filterIt(it.isOverriding):
      overriddingMethods.add(overriddingMethod)

    currentClass = currentClass.baseClass

  for methodToImplement in abstractMethods:
    let possibleImplementations = overriddingMethods
      .filterIt(it.name == methodToImplement.name)

    var serializedParams = methodToImplement.parameters
      .mapIt(it.cppType.toStrLit)
      .join(", ")
    var serializedMethod = (
      fmt"{methodToImplement.name}({serializedParams}): " &
      fmt"{methodToImplement.returnType.cppType.toStrLit}"
    )

    if possibleImplementations.len == 0:
      error(
        (
          fmt"Missing implementation of method {serializedMethod} " &
          fmt"(ensure the overridding method has pragma `cppOverride`)"
        ),
        classType.name
      )
    elif possibleImplementations.len > 1:
      error(
        fmt"Multiple declarations of method {methodToImplement.name}",
        possibleImplementations[1].ast.node
      )

    let methodImplementation = possibleImplementations[0]
    if (
      methodToImplement.parameters != methodImplementation.parameters or
      methodToImplement.returnType != methodImplementation.returnType
    ):
      error(
        fmt"Wrong implementation of method {serializedMethod}",
        methodImplementation.ast.node
      )

    if methodImplementation in classType.methods:
      methodImplementation.cppName = methodToImplement.cppName

macro cppClass*(header: untyped, body: untyped): untyped =
  var classType = new ClassType
  cppTypes.add(classType)

  var passedPragmas = newNimNode(nnkPragma)

  # TODO: Use `genSym(nskType, ...)` to generate symbols for types
  if header.kind == nnkIdent:
    classType.name = header # TODO: Remove
  elif header.kind == nnkPragmaExpr and header[0].kind == nnkIdent:
    classType.name = header[0] # TODO: Remove

    passedPragmas = header[1]
  elif header.kind == nnkInfix and header[0].eqIdent("of"):
    var baseClass = header[2]
    if baseClass.kind == nnkPragmaExpr:
      passedPragmas = header[2][1]
      baseClass = header[2][0]

    classType.name = header[1] # TODO: Remove
    classType.baseClass = cppTypes.getByName(baseClass)
    if classType.baseClass == nil:
      error(fmt"Type is not declared {baseClass.strVal}", header[2])
  else:
    error("Invlaid node: " & header.lispRepr(), header)

  for pragma in passedPragmas.mapIt(
    case it.kind:
      of nnkIdent: CppPragma(name: it, value: none NimNode)
      of nnkExprColonExpr: CppPragma(name: it[0], value: some it[1])
      else: error "Unknown pragma type"
  ):
    classType.ast.pragmas.add(pragma)

  if classType.ast.pragmas.getPragma(genAst importcpp).isNone:
    let classForeignName = classType.ast.pragmas.getPragma(genAst cppName)
    classType.cppName = (
      if classForeignName.isSome:
        classForeignName.get.value.get.strVal
      else:
        classType.name.strVal
    )

    let exportPragma = CppPragma(
      name: ident"exportcpp",
      value: some newStrLitNode(classType.cppName)
    )
    classType.ast.pragmas.add(exportPragma)
    classType.isImported = false
  else:
    classType.isImported = true

  if not classType.ast.pragmas.getPragma(genAst used).isSome:
    classType.ast.pragmas.add(CppPragma(name: genAst(used), value: none NimNode))

  var classVariables = newNimNode(nnkRecList)

  for node in body.items:
    case node.kind:
      of nnkVarSection:
        for variable in node.items:
          classVariables.add(variable)
      of nnkProcDef:
        processMethodNode(classType, node)
      else:
        error("Unknown node", node)

  classMethodsValidations(classType)

  classType.ast.node = declareClassType(classType)
  classType.ast.node[0][2][2] = classVariables

  for pragma in classType.ast.pragmas:
    let expr = (
      if pragma.value == none NimNode: pragma.name
      else: newColonExpr(pragma.name, pragma.value.get)
    )
    classType.ast.node[0][0][1].add(expr)

  result = newStmtList()
  result.add(classType.ast.node)

  # Parse and translate pragmas
  for classMethod in classType.methods:
    classMethod.ast.node.pragma.add(genAst used)
    if classType.isImported:
      let foreignPragma = newColonExpr(
        ident"importcpp",
        newStrLitNode fmt"#.{classMethod.cppName}(@)"
      )
      classMethod.ast.node.pragma.add(foreignPragma)

    if classType.isImported:
      continue

    let templateArgs =
      zip(
        toSeq(2 ..< 2 + classMethod.parameters.len),
        classMethod.parameters,
      )
      .map(it => (block:
        let typeSuffix = if it[1].cppReference: "&" else: ""
        let resultString = fmt"'{it[0]}{typeSuffix} #{it[0]}"

        if it[1].cppConst:
          return "const " & resultString
        else:
          return resultString
      ))
      .join(", ")

    let suffix = case classMethod.kind:
      of Abstract: " = 0"
      else:
        if classMethod.isOverriding: " override"
        else: ""

    let methodDeclaration = fmt"{classMethod.cppName}({templateArgs}){suffix}"
    if classMethod.kind == Member:
      let memberPragma = newColonExpr(
        genAst member,
        newStrLitNode methodDeclaration
      )
      classMethod.ast.node.pragma.add(memberPragma)
    else:
      let virtualPragma = newColonExpr(
        genAst virtual,
        newStrLitNode methodDeclaration
      )
      classMethod.ast.node.pragma.add(virtualPragma)

    if classMethod.kind == Abstract:
      classMethod.ast.node[6] = newStmtList(quote do: discard)

  for classMethod in classType.methods:
    let forwardDeclaration = newProc(
      classMethod.ast.node[0].copy(),
      classmethod.ast.node.params.copy().toseq,
      newEmptyNode(),
      nnkProcDef,
      classMethod.ast.node.pragma,
    )
    result.add(forwardDeclaration)

  for classMethod in classType.methods:
    if classType.isImported == false:
      result.add(classMethod.ast.node)

