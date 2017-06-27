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
        this.auth = "Basic 123456789qwerty";
    }

    function testSingleMiddleware() {
        return createTest({
            "signature": "/testSingleMiddleware", 
            "mw": mwPrintInfo.bindenv(this)
        });
    }

    function testSingleMiddlewareWithReturn() {
        return createTest({
            "signature": "/testSingleMiddlewareWithReturn", 
            "mw": mwWithReturn.bindenv(this)
        });
    }

    function testMultiMiddlewares() {
        return createTest({
            "signature": "/testMultiMiddleware", 
            "mw": [mwPrintInfo.bindenv(this), mwCheck4AuthPresence.bindenv(this)], 
            "statuscode": 401
        });
    }

    function testMultiMiddlewares2() {
        return createTest({
            "signature": "/testMultiMiddleware", 
            "mw": [mwPrintInfo.bindenv(this), mwCheck4AuthPresence.bindenv(this)], 
            "headers": {
                "Authorization": this.auth
            }
        });
    }

    function testSameMultiMiddlewares() {
        return createTest({
            "signature": "/testMultiMiddleware", 
            "mw": [mwPrintInfo.bindenv(this), mwPrintInfo.bindenv(this), mwPrintInfo.bindenv(this)]
        });
    }

    function testCORSMiddleware() {
        return createTest({
            "signature": "/testCORSMiddleware", 
            "paramsApp": {"accessControl": false}, 
            "mwApp": mwCustomCORS.bindenv(this)
        });
    }

    function testInvalidUseOfMiddleware() {
        return createTest({
            "signature": "/testInvalidUseOfMiddleware", 
            "mwArray": [null, true, 0, 13.37, "Middleware", [1, 2], {"hi": "there"}, blob(64), function(){}],
            "onExceptionApp": onException.bindenv(this),
            "statuscode": 500
        });
    }

    function testInvalidUseOfMiddlewares() {
        return createTest({
            "signature": "/testInvalidUseOfMiddlewares", 
            "mw": [42, {"hi": "there"}],
            "onExceptionApp": onException.bindenv(this),
            "statuscode": 500
        });
    }

    function testThrowableMiddleware() {
        return createTest({
            "signature": "/testThrowableMiddleware", 
            "mw": mwThrowException.bindenv(this), 
            "onExceptionApp": onException.bindenv(this),
            "statuscode": 500
        });
    }

    function testThrowableMiddlewareWithoutOnExceptionHandler() {
        return createTest({
            "signature": "/testThrowableMiddleware", 
            "mw": mwThrowException.bindenv(this), 
            "statuscode": 500
        });
    }

    function testMiddlewareWithoutParams() {
        return createTest({
            "signature": "/testMiddlewareWithoutParams", 
            "mw": mwWithoutParams.bindenv(this),
            "onExceptionApp": onException.bindenv(this),
            "statuscode": 500
        });
    }

    function testMiddlewareWith1Param() {
        return createTest({
            "signature": "/testMiddlewareWith1Param", 
            "mw": mwWith1Param.bindenv(this),
            "onExceptionApp": onException.bindenv(this),
            "statuscode": 500
        });
    }
    
    function mwPrintInfo(context, next) {
        /*
        this.info("Request received:");
        this.info("METHOD: " + context.req.method.tolower());
        this.info("PATH: " + context.req.path.tolower());
        this.info("TIME: " + time());
        */
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
        this.info("mwWithoutParams invoked");
    }

    function mwWith1Param(context) {
        this.info("mwWith1Param invoked");
    }
}
