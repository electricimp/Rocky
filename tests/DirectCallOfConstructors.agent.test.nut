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

// DirectCallOfConstructors
// Tests for direct call of Rocky.Route(callback), Rocky.Context(_req, _res)
class DirectCallOfConstructors extends Core {

    @include __PATH__+"/CoreHandlers.nut"

    values = null;
    
    function setUp() {
        values = [null, true, 0, -1, 1, 13.37, "String", [1, 2], {"counter": "this"}, blob(64), function(){}];
    }

    // Rocky.Route

    function testRockyRouteUsage() {
        return createTest({
            "signature": "/testRockyRouteUsage",
            "onException": onException.bindenv(this),
            "routeParams": function() {
                return null;
            }.bindenv(this)
        });
    }

    function testRockyRouteUsageWithWrongOption() {
        local tests = [];
        foreach (element in values) {
            tests.push({
                "signature": "/testRockyRouteUsageWithWrongOption",
                "onException": onException.bindenv(this),
                "routeParams": element
            });
        }
        return createTestAll(tests);
    }

    function testRockyRouteUsageWithHandlers() {
        return createTest({
            "signature": "/testRockyRouteUsageWithHandlers",
            "onAuthorizeRoute": onAuthorize.bindenv(this),
            "onUnauthorizedRoute": onUnauthorized.bindenv(this),
            "onTimeoutRoute": onTimeout.bindenv(this),
            "onExceptionRoute": onException.bindenv(this),
            "routeParams": function() {
                return null;
            }.bindenv(this)
        }, "fail");
    }

    function testRockyRouteUsageWithHandlersAndWrongOption() {
        local tests = [];
        foreach (element in values) {
            tests.push({
                "signature": "/testRockyRouteUsageWithHandlersAndWrongOption",
                "onAuthorizeRoute": onAuthorize.bindenv(this),
                "onUnauthorizedRoute": onUnauthorized.bindenv(this),
                "onTimeoutRoute": onTimeout.bindenv(this),
                "onExceptionRoute": onException.bindenv(this),
                "routeParams": element
            });
        }
        return createTestAll(tests, "negative");
    }

    // Rocky.Context

    function testRockyContextUsage() {
        return createTest({
            "signature": "/testRockyContextUsage",
            "onException": onException.bindenv(this),
            "contextParams": [{}, {}]
        });
    }

    function testRockyContextUsageWithWrongOption() {
        local tests = [];
        foreach (element in values) {
            tests.push({
                "signature": "/testRockyContextUsageWithWrongOption",
                "onException": onException.bindenv(this),
                "contextParams": [element, element]
            });
        }
        return createTestAll(tests);
    }

    function testRockyContextUsageWithMethods() {
        return createTest({
            "signature": "/testRockyContextUsageWithMethods",
            "contextParams": [{}, {}],
            "contextParamsAdditionalUsage": true
        }, "fail");
    }

    function testRockyContextUsageWithMethodsAndWrongOption() {
        local tests = [];
        foreach (element in values) {
            tests.push({
                "signature": "/testRockyContextUsageWithMethodsAndWrongOption",
                "contextParams": [element, element],
                "contextParamsAdditionalUsage": true
            });
        }
        return createTestAll(tests, "negative");
    }
}
