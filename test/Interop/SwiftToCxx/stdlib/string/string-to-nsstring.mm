// RUN: %empty-directory(%t)
// RUN: split-file %s %t

// RUN: %target-swift-frontend -typecheck %t/create_string.swift -typecheck -module-name StringCreator -enable-experimental-cxx-interop -emit-clang-header-path %t/StringCreator.h

// RUN: %target-interop-build-clangxx -std=gnu++20 -fobjc-arc -c %t/string-to-nsstring.mm -I %t -o %t/swift-stdlib-execution.o
// RUN: %target-build-swift %t/use_foundation.swift %t/create_string.swift -o %t/swift-stdlib-execution -Xlinker %t/swift-stdlib-execution.o -module-name StringCreator -Xfrontend -entry-point-function-name -Xfrontend swiftMain -lc++
// RUN: %target-codesign %t/swift-stdlib-execution
// RUN: %target-run %t/swift-stdlib-execution

// RUN: %target-interop-build-clangxx -std=gnu++20 -fobjc-arc -c %t/string-to-nsstring-one-arc-op.mm -I %t -Xclang -emit-llvm -S -o - -O1 |  %FileCheck --check-prefix=CHECKARC %s

// REQUIRES: executable_test
// REQUIRES: objc_interop

//--- use_foundation.swift
import Foundation

//--- create_string.swift
@_expose(Cxx)
public func createString(_ ptr: UnsafePointer<CChar>) -> String {
    return String(cString: ptr)
}

//--- string-to-nsstring-one-arc-op.mm

#include "StringCreator.h"

int main() {
  using namespace Swift;
  auto emptyString = String::init();
  NSString *nsStr = emptyString;
}

// CHECKARC: %[[VAL:.*]] = {{(tail )?}}call swiftcc ptr @"$sSS23_bridgeToObjectiveCImplyXlyF"
// CHECKARC: call ptr @llvm.objc.autorelease(ptr %[[VAL]])
// CHECKARC: @llvm.objc.
// CHECKARC-SAME: autorelease(ptr)
// CHECKARC-NOT: @llvm.objc.

//--- string-to-nsstring.mm

#include <cassert>
#include <string>
#include "StringCreator.h"

int main() {
  using namespace Swift;

  auto emptyString = String::init();

  {
    NSString *nsStr = emptyString;
    assert(std::string(nsStr.UTF8String) == "");
    assert([nsStr isEqualToString:@""]);
  }

  auto aStr = StringCreator::createString("hello");
  {
    NSString *nsStr = aStr;
    assert(std::string(nsStr.UTF8String) == "hello");
    assert([nsStr isEqualToString:@"hello"]);
  }
  return 0;
}
