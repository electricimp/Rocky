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

// RockyContext
// Tests for Rocky.Context.send, Rocky.Context.getHeader, Rocky.Context.req, Rocky.Context.path, Rocky.Context.matches, Rocky.Context.isbrowser
class RockyContext extends ImpTestCase {

    @include __PATH__+"/Core.nut"
    @include __PATH__+"/CoreHandlers.nut"

    function testSend() {
        return createTest({
            "signature": "/testSend",
            "onExceptionApp": onException.bindenv(this),
            "callback": function(context) {
                context.send(200, {"message": "OK"});
            }.bindenv(this)
        });
    }

    function testSendWithOnlyMessage() {
        return createTest({
            "signature": "/testSendWithOnlyMessage",
            "onExceptionApp": onException.bindenv(this),
            "callback": function(context) {
                context.send({"message": "OK"});
            }.bindenv(this)
        });
    }

    function testSendWithOnlyStatuscode() {
        return createTest({
            "signature": "/testSendWithOnlyStatuscode",
            "onExceptionApp": onException.bindenv(this),
            "callback": function(context) {
                context.send(201);
            }.bindenv(this),
            "statuscode": 201
        });
    }

    function testSendWithWrongStatuscode() {
        return createTest({
            "signature": "/testSendWithWrongStatuscode",
            "callback": function(context) {
                context.send("wrong", {"message": "OK"});
            }.bindenv(this),
            "onExceptionApp": onException.bindenv(this)
        }, "fail");
    }

    function testSendWithWrongMessage() {
        return createTest({
            "signature": "/testSendWithWrongMessage",
            "callback": function(context) {
                context.send(200, function(a){
                    return a + 2;
                });
            }.bindenv(this),
            "onExceptionApp": onException.bindenv(this)
        }, "fail");
    }

    function testGetHeader() {
        local headers = {
            "First": "1",
            "Second": "2",
            "Third": "3"
        };
        return createTest({
            "signature": "/testGetHeader",
            "callback": function(context) {
                try {
                    foreach (key, value in headers) {
                        if (context.getHeader(key) != value) {
                            throw "Missing transmitted header";
                        }
                    }
                    context.send(200, {"message": "OK"});
                } catch (ex) {
                    this.info(ex);
                    context.send(500, {"error": ex});
                }
            }.bindenv(this),
            "headers": headers
        });
    }

    function testReq() {
        local headers = {
            "content-type": "application/json"
        };
        local body = {
            "hello": "there"
        };
        return createTest({
            "signature": "/testReq",
            "callback": function(context) {
                try {
                    if (typeof context.req.body != "table") {
                        throw "Invalid context.req.body type";
                    }
                    if (typeof context.req.rawbody != "string") {
                        throw "Invalid context.req.body rawbody";
                    }
                    if (!("hello" in context.req.body)) {
                        throw "context.req.body must contain 'hello' key";
                    }
                    context.send(200, {"message": "OK"});
                } catch (ex) {
                    this.info(ex);
                    context.send(500, {"error": ex});
                }
            }.bindenv(this),
            "headers": headers,
            "body": http.jsonencode(body)
        });
    }

    function testPath() {
        local p = ["testPath", "a", "b", "c"]
        return createTest({
            "signature": "/testPath/a/b/c",  // "/" + p.join("/")
            "callback": function(context) {
                try {
                    if (context.path.len() != p.len()) {
                        throw "context.path contains invalid number of items";
                    }
                    for (local i = 0; i < 4; i++) {
                        if (context.path[i].tolower() != p[i].tolower()) {
                            throw "context.path contains invalid item: '" + context.path[i].tolower() + "' != '" + p[i].tolower() + "'";
                        }
                    }
                    context.send(200, {"message": "OK"});
                } catch (ex) {
                    this.info(ex);
                    context.send(500, {"error": ex});
                }
            }.bindenv(this)
        });
    }

    function testMatches() {
        return createTest({
            "signature": "/testMatches/([^/]*)",
            "signatureOverride": "/testMatches/hello",
            "callback": function(context) {
                try {
                    if (context.matches[0].tolower() != "/testMatches/hello".tolower()) {
                        throw "Invalid context.matches[0] value: " + context.matches[0].tolower();
                    }
                    if (context.matches[1].tolower() != "hello".tolower()) {
                        throw "Invalid context.matches[1] value: " + context.matches[1].tolower();
                    }
                    context.send(200, {"message": "OK"});
                } catch (ex) {
                    this.info(ex);
                    context.send(500, {"error": ex});
                }
            }.bindenv(this)
        });
    }

    function testIsbrowserPositive() {
        return createTest({
            "signature": "/testIsbrowserPositive",
            "callback": function(context) {
                if (context.isbrowser()) {
                    context.send(200, {"message": "OK"});
                } else {
                    context.send(400, {"error": "Not a browser"});
                }
            }.bindenv(this),
            "headers": {
                "Accept": "text/html"
            }
        });
    }

    function testIsbrowserNegative() {
        return createTest({
            "signature": "/testIsbrowserPositive",
            "callback": function(context) {
                if (context.isbrowser()) {
                    context.send(400, {"error": "You a browser"});
                } else {
                    context.send(200, {"message": "OK"});
                }
            }.bindenv(this)
        });
    }
}
