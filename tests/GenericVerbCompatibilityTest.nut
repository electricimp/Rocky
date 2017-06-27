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

@include "github:electricimp/Rocky/Rocky.class.nut"

class GenericVerbCompatibilityTest extends ImpTestCase {
@include __PATH__+"/Base.nut"

    function _createGenericTestPromise(signature, query = {}, headers = {}, body = "body") {
        return _createTestPromise(null, getVerb(), signature, query, headers, body);
    }

    function testSimple() {
        return _createTestPromise();
    }

    function testFull() {
        //TODO: add query = {}
        return _createGenericTestPromise("/testFull", {},
            {"testFull" : "testFull", "GenericVerbCompatibilityTest" : true},
            "testFull body");
    }

    function testSimpleWOSignature() {
        return _createGenericTestPromise("/");
    }

    function testWOSignatureFull() {
        //TODO: add query = {}
        return _createGenericTestPromise("/", {}
            {"testWOSignatureFull" : 35, "GenericVerbCompatibilityTest" : false},
            "testWOSignatureFull body");
    }

    function testTimeout() {
        //TODO: add query = {}
        return _createTestPromise(null, getVerb(), "/", {}
            {"testTimeout" : 35, "GenericVerbCompatibilityTest" : "testTimeout"},
            "testTimeout body", function (app, cb) {
                local methodName = getVerb().tolower();
                if (methodName in app) {
                    app[methodName]("/", cb, 15);
                } else {
                    app.on(getVerb(), "/", cb, 15);
                }
            });
    }

    function testSimpleRegexp_1() {
        local headers = {"testSimpleRegexp" : "testSimpleRegexp", "GenericVerbCompatibilityTest" : "testSimpleRegexp"};
        local body = "testSimpleRegexp body";
        return _createTestPromise(null, getVerb(), ".*", {}, headers,
            body, null, function () {
                return http.request(getVerb(), http.agenturl() + "/test", headers,
                        body);
                });
    }

    function testSimpleRegexp_2() {
        local headers = {"testSimpleRegexp" : "testSimpleRegexp", "GenericVerbCompatibilityTest" : "testSimpleRegexp"};
        local body = "testSimpleRegexp body";
        return _createTestPromise(null, getVerb(), "/test1(.*/test\\d.*)", {}, headers,
            body, null, // configureRocky
            function () { // createRequestFunc
                return http.request(getVerb(), http.agenturl() + "/test1/test2/test3", headers,
                        body);
            }.bindenv(this), function (context) { // requestFunc
                if (context.matches.len() != 2) {
                    throw "Wrong context.matches.len()=" + context.matches.len() + ", should be 2";
                } else if ("/test2/test3" != context.matches[1]) {
                    throw "Wrong context.matches[1]=" +  context.matches[1]+ ", should be /test2/test3";
                }
                context.send(body);
                return 200;
            }.bindenv(this), function(resp) { // responseFunc
                return body == resp.body;
            }.bindenv(this));
    }

    function testContentType() {
        local headers = {"testContentType" : "testContentType", "content-type" : "application/gson"};
        local body = "testContentType body";
        return _createTestPromise(null, getVerb(), "/testContentType", {}, headers,
            body);
    }

    function contentType(contentType) {
        local headers = {"contentType" : "contentType", "content-type" : contentType};
        local body = "{ \"contentType\" : \"body\"}";
        return _createTestPromise(null, getVerb(), "/contentType", {}, headers,
            body, null, // configureRocky
            null, // createRequestFunc
            function (context) { // requestFunc
                local tmp = context.req.headers;
                if ("content-type" in tmp) {
                    if (contentType != tmp["content-type"]) {
                        throw "Wrong content-type=" + tmp["content-type"] + ", should be "+contentType;
                    }
                    tmp = context.req.body;
                    if ("table" != type(tmp)) {
                        throw "Wrong type of context.req.body " + type(tmp) + ", should be table";
                    } else if (!("contentType" in tmp) || "body" != tmp["contentType"]) {
                        this.info("---------actual body----------");
                        _deepLog(tmp);
                        throw "Wrong context.req.body";
                    }
                } else {
                    throw "content-type is absent in headers";
                }
                context.send(body);
                return 200;
            }.bindenv(this), function(resp) { // responseFunc
                return body == resp.body;
            }.bindenv(this));
    }

    function testContentTypeJson() {
        return contentType("application/json");
    }

    function testContentTypeForm() {
        return contentType("application/x-www-form-urlencoded");
    }

    function testContentTypeMultipart() {
        return contentType("multipart/form-data");
    }
}
