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

@include "github:electricimp/Rocky/Rocky.class.nut"

// Middleware
// Tests for Middleware, Rocky.use, Rocky.Route.use, CORS Requests
class Middleware extends ImpTestCase {

    @include __PATH__+"/Core.nut"
    @include __PATH__+"/CoreHandlers.nut"

    auth = null;
    
    function setUp() {
        auth = "Basic 123456789qwerty";
    }

    function testSingleMiddleware() {
        return createTest({
            "signature": "/testSingleMiddleware", 
            "routeMiddleware": mwPrintInfo.bindenv(this)
        });
    }

    function testSingleMiddlewareWithReturn() {
        return createTest({
            "signature": "/testSingleMiddlewareWithReturn", 
            "routeMiddleware": mwWithReturn.bindenv(this)
        });
    }

    function testMultiMiddlewares() {
        return createTest({
            "signature": "/testMultiMiddleware", 
            "routeMiddleware": [mwPrintInfo.bindenv(this), mwCheck4AuthPresence.bindenv(this)], 
            "statuscode": 401
        });
    }

    function testMultiMiddlewares2() {
        return createTest({
            "signature": "/testMultiMiddleware", 
            "routeMiddleware": [mwPrintInfo.bindenv(this), mwCheck4AuthPresence.bindenv(this)], 
            "headers": {
                "Authorization": auth
            }
        });
    }

    function testSameMultiMiddlewares() {
        return createTest({
            "signature": "/testMultiMiddleware", 
            "routeMiddleware": [mwPrintInfo.bindenv(this), mwPrintInfo.bindenv(this), mwPrintInfo.bindenv(this)]
        });
    }

    function testCORSMiddleware() {
        return createTest({
            "method": "OPTIONS",
            "signature": "/testCORSMiddleware", 
            "params": {"accessControl": false}, 
            "appMiddleware": mwCustomCORS.bindenv(this),
            "callbackVerify": function(res) {
                try {
                    if (res.headers["access-control-allow-origin"] != "*") {
                        throw "Response header 'Access-Control-Allow-Origin' must contain '*'";
                    }
                    if (res.headers["access-control-allow-headers"] != "Origin, X-Requested-With, Content-Type, Accept, X-Version") {
                        throw "Response header 'Access-Control-Allow-Headers' must contain 'Origin, X-Requested-With, Content-Type, Accept, X-Version'";
                    }
                    if (res.headers["access-control-allow-methods"] != "POST, PUT, PATCH, GET, OPTIONS") {
                        throw "Response header 'Access-Control-Allow-Methods' must contain 'POST, PUT, PATCH, GET, OPTIONS'";
                    }
                    return true;
                } catch (ex) {
                    info(ex);
                    return false;
                }
                info(res.headers);
            }.bindenv(this)
        });
    }

    function testInvalidUseOfMiddleware() {
        local tests = [];
        local values = [null, true, 0, 13.37, "Middleware", [1, 2], {"hi": "there"}, blob(64)];
        foreach (element in values) {
            tests.push({
                "signature": "/testInvalidUseOfMiddleware", 
                "routeMiddleware": element,
                "onException": onException.bindenv(this),
                "statuscode": 500
            });
        }
        return createTestAll(tests, "negative");
    }

    function testInvalidUseOfMiddlewares() {
        return createTest({
            "signature": "/testInvalidUseOfMiddlewares", 
            "routeMiddleware": [42, {"hi": "there"}],
            "onException": onException.bindenv(this),
            "statuscode": 500
        }, "fail");
    }

    function testThrowableMiddleware() {
        return createTest({
            "signature": "/testThrowableMiddleware", 
            "routeMiddleware": mwThrowException.bindenv(this), 
            "onException": onException.bindenv(this),
            "statuscode": 500
        });
    }

    function testThrowableMiddlewareWithoutOnExceptionHandler() {
        return createTest({
            "signature": "/testThrowableMiddleware", 
            "routeMiddleware": mwThrowException.bindenv(this),
            "onException": onException.bindenv(this),
            "statuscode": 500
        });
    }

    function testMiddlewareWithoutParams() {
        return createTest({
            "signature": "/testMiddlewareWithoutParams", 
            "routeMiddleware": mwWithoutParams.bindenv(this),
            "onException": onException.bindenv(this),
            "statuscode": 500
        });
    }

    function testMiddlewareWith1Param() {
        return createTest({
            "signature": "/testMiddlewareWith1Param", 
            "routeMiddleware": mwWith1Param.bindenv(this),
            "onException": onException.bindenv(this),
            "statuscode": 500
        });
    }
    
    function mwPrintInfo(context, next) {
        // this.info("Request received:");
        // this.info("METHOD: " + context.req.method.tolower());
        // this.info("PATH: " + context.req.path.tolower());
        // this.info("TIME: " + time());
        next();
    }

    function mwCheck4AuthPresence(context, next) {
        local authString = context.getHeader("Authorization");
        if (authString == null) {
            context.send(401, {"error": "unauthorized"});
        }
        next();
    }

    function mwWithReturn(context, next) {
        next();
        return false;
    }

    function mwCustomCORS(context, next) {
        context.setHeader("Access-Control-Allow-Origin", "*");
        context.setHeader("Access-Control-Allow-Headers", "Origin, X-Requested-With, Content-Type, Accept, X-Version");
        context.setHeader("Access-Control-Allow-Methods", "POST, PUT, PATCH, GET, OPTIONS");
        next();
    }

    function mwThrowException(context, next) {
        throw "Synthetic exception";
        next();
    }

    function mwWithoutParams() {
        info("mwWithoutParams invoked");
    }

    function mwWith1Param(context) {
        info("mwWith1Param invoked");
    }
}
