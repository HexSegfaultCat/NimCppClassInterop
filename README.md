# NimCppClassInterop

An incomplete library for interoperation with C++ libraries using `virtual` and `member` pragmas. I'm writing this library to learn Nim and to make it easier to wrap C++ libraries. It probably needs complete rewrite, but I'm still experimenting with Nim.

Example with implementation of interface declared in `.h` file (part of my OpenVR driver implementation, which I use to test if the library works):
```nim
from os import splitPath

import CppClassInterop
# ...

{.
  passC: "-I" & currentSourcePath().splitPath().head
}

cppClass IServerTrackedDeviceProvider {.
  header: "openvr_driver.h",
  importcpp: "vr::IServerTrackedDeviceProvider",
.}:
  proc init*(driverContext: ptr IVRDriverContext): EVRInitError {.
    header: "openvr_driver.h",
    cppName: "Init",
    cppAbstract,
  .}
  proc cleanup*() {.
    header: "openvr_driver.h",
    cppName: "Cleanup",
    cppAbstract,
  .}
  proc getInterfaceVersions*(): ConstCharPointerConstPointer {.
    header: "openvr_driver.h",
    cppName: "GetInterfaceVersions",
    cppAbstract,
  .}
  proc runFrame*() {.
    header: "openvr_driver.h",
    cppName: "RunFrame",
    cppAbstract,
  .}
  proc shouldBlockStandbyMode*(): bool {.
    header: "openvr_driver.h",
    cppName: "ShouldBlockStandbyMode",
    cppAbstract,
  .}
  proc enterStandby*() {.
    header: "openvr_driver.h",
    cppName: "EnterStandby",
    cppAbstract,
  .}
  proc leaveStandby*() {.
    header: "openvr_driver.h",
    cppName: "LeaveStandby",
    cppAbstract,
  .}
```
```nim
import CppClassInterop
# ...

cppClass DeviceProvider of IServerTrackedDeviceProvider:
  var exampleController*: ControllerDevice
  var exampleHmd*: HmdControllerDevice

  proc init*(driverContext: ptr IVRDriverContext): EVRInitError {.
    cppOverride,
  .} =
    this.exampleController.addr.deviceId = TrackedDeviceIndexInvalid
    echo "[Nim] Got init"

    var errorCode = initServerDriverContext(driverContext)
    if errorCode != VRInitErrorNone:
      echo "[Nim] Error in init, stopping initialization"
      return errorCode

    var controllerStatus = vrServerDriverHost().trackedDeviceAdded(
      "ExampleController",
      TrackedDeviceClass_Controller,
      addr this.exampleController
    )
    echo "[Nim] Controller initialization status: " & $controllerStatus

    var hmdStatus = vrServerDriverHost().trackedDeviceAdded(
      "ExampleHmd",
      TrackedDeviceClass_HMD,
      addr this.exampleHmd
    )
    echo "[Nim] HMD initialization status: " & $hmdStatus

    return VRInitErrorNone

  proc cleanup*() {.cppOverride.} =
    echo "[Nim] Cleanup"
    cleanupDriverContext()

  proc getInterfaceVersions*(): ConstCharPointerConstPointer {.cppOverride.} =
    echo "[Nim] GetInterfaceVersions"
    return InterfaceVersions

  proc runFrame*() {.cppOverride.} =
    var vrEvent: VREvent
    while vrServerDriverHost().pollNextEvent(
      addr vrEvent,
      sizeof(vrEvent).uint32
    ):
      this.exampleController.addr.handleEvent(vrEvent)
      echo "[Nim] Handling event " & repr vrEvent

    this.exampleController.addr.runFrame()
    this.exampleHmd.addr.poseUpdateBackground()

  proc shouldBlockStandbyMode*(): bool {.cppOverride.} =
    echo "[Nim] ShouldBlockStandbyMode"
    return false

  proc enterStandby*() {.cppOverride.} =
    echo "[Nim] EnterStandby"

  proc leaveStandby*() {.cppOverride.} =
    echo "[Nim] LeaveStandby"
```
