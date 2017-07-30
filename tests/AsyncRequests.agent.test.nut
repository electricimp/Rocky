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

// AsyncRequests
// Tests for Rocky.getContext, Rocky.sendToAll, Rocky.Context.id, Rocky.Context.isComplete, Rocky.Context.userdata
class AsyncRequests extends Core {

    connections = null;
    
    function setUp() {
        connections = [];
    }

    function testBasicAsyncRequest() {
        return createTest({
            "signature": "/testBasicAsyncRequest"
            "callback": asyncCallback.bindenv(this)
        });
    }

    function testMultipleAsyncRequests() {
        info("This test will take a couple of seconds");
        imp.wakeup(10, function() {
            completeMultipleAsyncRequests();
        }.bindenv(this));
        return createTest({
            "signature": "/testMultipleAsyncRequests",
            "params": {
                "timeout": 20
            },
            "numberOfRequests": 5,
            "callback": asyncCallbackMultiple.bindenv(this)
        });
    }

    // issue: https://github.com/electricimp/Rocky/issues/21
    //function testMultipleAsyncRequestsWithSendToAll() {
    //    info("This test will take a couple of seconds");
    //    imp.wakeup(10, function() {
    //        completeMultipleAsyncRequestsWithSendToAll();
    //    }.bindenv(this));
    //    return createTest({
    //        "signature": "/testMultipleAsyncRequestsWithSendToAll",
    //        "params": {
    //            "timeout": 20
    //        },
    //        "numberOfRequests": 5,
    //        "callback": asyncCallbackMultiple.bindenv(this)
    //    });
    //}

    function testInvalidContexts() {
        return createTest({
            "signature": "/testInvalidContexts"
            "callback": invalidContextsCallback.bindenv(this)
        });
    }

    function testUserdata() {
        return createTest({
            "signature": "/testUserdata"
            "callback": asyncCallbackWithUserdata.bindenv(this)
        });
    }

    function asyncCallback(context) {
        connections.push(context.id);
        imp.wakeup(1, function() {
            completeAsyncRequest(context.id);
        }.bindenv(this));
    }

    function completeAsyncRequest(cid) {
        connections.remove(connections.find(cid));
        local context = Rocky.getContext(cid);
        if (!context.isComplete()) {
            context.send(200, {"message": "OK"});
        }
    }

    function asyncCallbackMultiple(context) {
        connections.push(context.id);
    }

    function completeMultipleAsyncRequestsWithSendToAll() {
        Rocky.sendToAll(200, {"message": "OK"});
        connections.clear();
    }

    function completeMultipleAsyncRequests() {
        foreach (cid in connections) {
            local ctx = Rocky.getContext(cid);
            ctx.send(200, {"message": "OK"});
        }
        connections.clear();
    }

    function invalidContextsCallback(context) {
        try {
            local ctx;
            ctx = Rocky.getContext(null);
            ctx = Rocky.getContext(true);
            ctx = Rocky.getContext(0);
            ctx = Rocky.getContext(0.1);
            ctx = Rocky.getContext("qwerty");
            ctx = Rocky.getContext(blob(64));
            ctx = Rocky.getContext([1, 2, 3]);
            ctx = Rocky.getContext({"hello": "there"});
            ctx = Rocky.getContext(function(){});
            context.send(200, {"message": "OK"});
        } catch (ex) {
            context.send(500, {"error": ex});
        }
    }

    function asyncCallbackWithUserdata(context) {
        context.userdata = {"startTime": time()};
        connections.push(context.id);
        imp.wakeup(2, function() {
            completeAsyncRequestWithUserdata(context.id);
        }.bindenv(this));
    }

    function completeAsyncRequestWithUserdata(cid) {
        connections.remove(connections.find(cid));
        local context = Rocky.getContext(cid);
        local elapsedTime = time() - context.userdata.startTime;
        if (!context.isComplete()) {
            if (elapsedTime > 0) {
                context.send(200, {"message": "OK"});
            } else {
                context.send(400, {"error": "Invalid context.userdata.startTime data"});
            }
        }
    }
}
