// MIT License
//
// Copyright 2017 Electric Imp
//
// SPDX-License-Identifier: MIT
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be
// included in all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
// EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
// MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO
// EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES
// OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,
// ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
// OTHER DEALINGS IN THE SOFTWARE.
// "Promise" symbol is injected dependency from ImpUnit_Promise module,
// while class being tested can be accessed from global scope as "::Promise".

@include __PATH__+"/Core.nut"

// RockyConstructor
// Tests for Rocky([options])
class RockyConstructor extends Core {

    @include __PATH__+"/CoreHandlers.nut"

    values = null;

    function setUp() {
        values = [null, true, 0, -1, 1, 13.37, "String", [1, 2], {"counter": "this"}, blob(64), function(){}];
    }

    function testRockyAccessControlOption() {
        local tests = [];
        foreach (element in values) {
            tests.push({
                "signature": "/testAccessControlOption",
                "params": {"accessControl": element}
            });
        }
        return createTestAll(tests);
    }

    function testRockyAllowUnsecureOption() {
        local tests = [];
        foreach (element in values) {
            tests.push({
                "signature": "/testAllowUnsecureOption",
                "params": {"allowUnsecure": element}
            });
        }
        return createTestAll(tests);
    }

    function testRockyStrictRoutingOption() {
        local tests = [];
        foreach (element in values) {
            tests.push({
                "signature": "/testStrictRoutingOption",
                "params": {"strictRouting": element}
            });
        }
        return createTestAll(tests);
    }

    // issue: https://github.com/electricimp/Rocky/issues/24 (and 23)
    function testRockyTimeoutOptionBad() {
        // These should FAIL
        local tests = [];
        foreach (idx, element in values) {
            if (idx < 2 && idx > 5) {
                tests.push({
                    "signature": "/testTimeoutOption",
                    "params": {"timeout": element},
                });
            }
        }
        return createTestAll(tests, "negative");
    }

    function testRockyTimeoutOptionGood() {
        // These should PASS
        local tests = [];
        foreach (idx, element in values) {
            if (idx > 1 && idx < 6) {
                tests.push({
                    "signature": "/testTimeoutOption",
                    "params": {"timeout": element},
                });
            }
        }
        return createTestAll(tests);
    }

    function testRockyWrongOption() {
        local values = ["hello", "strictrouting", "AllowUnsecure", "TimeOut"];
        local params = {};
        local c = 0;
        foreach (element in values) {
            params[element] <- c++;
        }
        return createTest({
            "signature": "/testWrongOption",
            "params": params
        });
    }

    function testRockySingleton() {

        // Make ten rocky references -- all of of which are expected to point
        // to the SAME rocky instance
        local rockies = [];
        for (local i = 0 ; i < 10 ; i++) {
            rockies.append(Rocky.init());
        }

        // Check all ten references point to the same instance
        foreach (index, rocky in rockies) {
            foreach (count, aRocky in rockies) {
                if (count != index) {
                    this.assertEqual(rocky, aRocky);
                }
            }
        }

    }
}
