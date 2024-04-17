# This is just an example to get you started. A typical library package
# exports the main API in this file. Note that you cannot rename this file
# but you can remove it if you wish.

import CppClassInterop/[class, pragmas]

export class, pragmas

proc newCpp*[T](): ptr T {.importcpp: "new '*0()".}
proc destroyCpp*[T](this: var T) {.importcpp: "#.~'*0()".}

