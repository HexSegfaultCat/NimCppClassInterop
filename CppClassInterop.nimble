# Package

version       = "0.1.0"
author        = "Anonymous"
description   = "A new awesome nimble package"
license       = "MIT"
srcDir        = "src"
backend       = "cpp"

# Dependencies

requires "nim >= 2.1.1"

task test, "Run tests with Testament runner":
  exec """testament --targets:"cpp" --megatest:off all"""
