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

class Core extends ImpTestCase {
    
    // Default params for createTest function
    defaultParams = {
        // Options for Rocky constructor
        "params": {},
        // Options for calling Rocky.Route constructor directly
        "routeParams": null,
        // Options for calling Rocky.Context constructor directly
        "contextParams": null,
        // Use for calling Rocky.Context constructor directly. If true, then all Rocky.Context methods will be called.
        "contextParamsAdditionalUsage": false,
        // Method to send requests
        "method": "GET",
        // Method to receive requests
        // If not specified, defaultParams.method will be used
        "methodOverride": null,
        // If true, get post put methods will execute with Rocky.on function directly.
        "methodStrictUsage": false,
        // Signature to receive requests
        "signature": "/test",
        // Signature to send requests
        // If not specified, defaultParams.signature will be used
        "signatureOverride": null,
        // Headers to send requests
        "headers": {},
        // Body to send requests
        "body": "",
        // If true, server will not respond to received requests
        "timeout": false,
        // If defined, set timeout param at Rocky.on|Rocky.VERB
        "timeoutRoute": null,
        // Expected statuscode of server's response. If real statuscode will be different, then test will be failed.
        "statuscode": 200,
        // Callback, that will be called, when server will receive new request. This callback (if specified) will be passed directly into Rocky.on method.
        "cb": null,
        // If true, defaultParams.cb will be forced to be null
        "cbUseNull": false,
        // Callback, that will be called, when server will receive new request. 
        // If not specified, then server will respond with 200 statuscode.
        // If params.cb specified, then this callback will have no affect.
        "callback": null,
        // Callback, that will be called, when programm will get response from the server. Usefull to verify server response.
        // Should return true, if the test was successful, false otherwise.
        // If not specified, then by default the test will be successful (or not, considering the statuscode).
        "callbackVerify": null,
        // Specifies how many times program should send requests to the server.
        "numberOfRequests": 1,
        // Middleware or array of middlewares for Rocky.use
        "appMiddleware": [],
        // Middleware or array of middlewares for Rocky.Route.use
        "routeMiddleware": [],
        // Specifies handlers for Rocky.authorize|Rocky.onUnauthorized|Rocky.onTimeout|Rocky.onNotFound|Rocky.onException
        "onAuthorize": null,
        "onUnauthorized": null,
        "onTimeout": null,
        "onNotFound": null,
        "onException": null,
        // Specifies handlers for Rocky.Route.authorize|Rocky.Route.onUnauthorized|Rocky.Route.onTimeout|Rocky.Route.onException
        "onAuthorizeRoute": null,
        "onUnauthorizedRoute": null,
        "onTimeoutRoute": null,
        "onExceptionRoute": null
    };

    // createTest
    // Create Promise for testing Rocky.
    // All customization is carried out through a single parameter - table. Table's params described above.
    // Scenario of the method:
    // 1) Apply default values to 'params' if undefined
    // 2) Create Rocky instance
    // 3) Set Rocky's handlers from 'params' if defined (Rocky.authorize, Rocky.onUnauthorized, Rocky.onTimeout, Rocky.onNotFound, Rocky.onException)
    // 4) Set Rocky's middlewares from 'params' if defined (Rocky.use)
    // 5) Create handler for incoming requests (Rocky.Route)
    // 6) Set Rocky.Route's handlers from 'params' if defined (Rocky.Route.authorize, Rocky.Route.onUnauthorized, Rocky.Route.onTimeout, Rocky.Route.onException)
    // 7) Set Rocky.Route's middlewares from 'params' if defined (Rocky.Route.use)
    // 8) Send one (or more) request(s) and wait for Rocky's response.
    //    When get response, verify statuscode and call callback function for additional verify (if defined). If everything ok, then test passed, otherwise failed.
    //    If more than one requests send, then test will be passed only when all responses verifications passed.
    // 
    // @param {table} params
    // @param {string} expect - Expected completion of the test (success|fail)
    // @return {Promise}
    function createTest(params = {}, expect = "success") {
        return Promise(function(resolve, reject) {
            local success = function() {
                if (expect == "fail") {
                    reject("createTest test was resolved, but 'fail' expected");
                } else {
                    resolve();
                }
            };
            local fail = function(reason = null) {
                if (expect == "fail") {
                    resolve();
                } else {
                    reject(reason);
                }
            };
            local app;
            local route;
            params.setdelegate(defaultParams); // Setup default values
            _createTestCallConstructorsDirectly(params, fail) && 
            _createTestSetupHandlers(params, fail, app, route) && 
            _createTestSendRequest(params, fail, success, expect);
        }.bindenv(this));
    }

    function _createTestCallConstructorsDirectly(params, fail) {
        try {
            // Call Rocky.Route constructor directly
            if (params.routeParams != null) {
                local illegalRoute = Rocky.Route(params.routeParams);
                if (params.onAuthorizeRoute != null) {
                    illegalRoute.authorize(params.onAuthorizeRoute);
                }
                if (params.onUnauthorizedRoute != null) {
                    illegalRoute.onUnauthorized(params.onUnauthorizedRoute);
                }
                if (params.onTimeoutRoute != null) {
                    illegalRoute.onTimeout(params.onTimeoutRoute);
                }
                if (params.onExceptionRoute != null) {
                    illegalRoute.onException(params.onExceptionRoute);
                }
                illegalRoute.use(params.routeMiddleware);
            }
            // Call Rocky.Context constructor directly
            if (params.contextParams != null) {
                local illegalContext = Rocky.Context(params.contextParams[0], params.contextParams[1]);
                if (params.contextParamsAdditionalUsage != null && params.contextParamsAdditionalUsage) {
                    local tmp;
                    tmp = illegalContext.isComplete();
                    illegalContext.setHeader("Header", "here");
                    tmp = illegalContext.getHeader("Header");
                    tmp = illegalContext.req.method;
                    tmp = illegalContext.req.path;
                    tmp = illegalContext.req.query;
                    tmp = illegalContext.req.headers;
                    tmp = illegalContext.req.body;
                    tmp = illegalContext.id;
                    tmp = illegalContext.userdata;
                    tmp = illegalContext.path;
                    tmp = illegalContext.matches;
                    tmp = illegalContext.isbrowser();
                    illegalContext.send(200);
                }
            }
            return true;
        } catch(ex) {
            fail("Unexpected error while call constructors directly: " + ex);
            return false;
        }
    }

    function _createTestSetupHandlers(params, fail, app, route) {
        try {
            // Setup Rocky handlers
            app = Rocky(params.params);
            if (params.onAuthorize != null) {
                app.authorize(params.onAuthorize);
            }
            if (params.onUnauthorized != null) {
                app.onUnauthorized(params.onUnauthorized);
            }
            if (params.onTimeout != null) {
                app.onTimeout(params.onTimeout);
            }
            if (params.onNotFound != null) {
                app.onNotFound(params.onNotFound);
            }
            if (params.onException != null) {
                app.onException(params.onException);
            }
            app.use(params.appMiddleware);
        } catch (ex) {
            fail("Unexpected error while setup Rocky handlers: " + ex);
            return false;
        }
        try {
            // Setup Rocky.Route handlers
            local cb = params.cb;
            if (cb == null && !params.cbUseNull) {
                cb = function(context) {
                    try {
                        if (!params.timeout) {
                            if (params.callback != null) {
                                params.callback(context);
                            } else {
                                context.send(200, "head" == params.method.tolower() ? "" : {"message": "OK"});
                            }
                        }
                    } catch (ex) {
                        fail("Unexpected error at Rocky.on callback: " + ex);
                    }
                }.bindenv(this);
            }
            if (params.method in app && !params.methodStrictUsage) {
                if (params.timeoutRoute == null) {
                    route = app[params.method](params.signature, cb);
                } else {
                    route = app[params.method](params.signature, cb, params.timeoutRoute);
                }
            } else {
                if (params.timeoutRoute == null) {
                    route = app.on(params.method, params.signature, cb);
                } else {
                    route = app.on(params.method, params.signature, cb, params.timeoutRoute);
                }
            }
            if (params.onAuthorizeRoute != null) {
                route.authorize(params.onAuthorizeRoute);
            }
            if (params.onUnauthorizedRoute != null) {
                route.onUnauthorized(params.onUnauthorizedRoute);
            }
            if (params.onTimeoutRoute != null) {
                route.onTimeout(params.onTimeoutRoute);
            }
            if (params.onExceptionRoute != null) {
                route.onException(params.onExceptionRoute);
            }
            route.use(params.routeMiddleware);
        } catch (ex) {
            fail("Unexpected error while setup Rocky.Route handlers: " + ex);
            return false;
        }
        return true;
    }

    function _createTestSendRequest(params, fail, success, expect) {
        try {
            // Send request
            imp.wakeup(0, function() {
                try {
                    local numberOfSucceedRequests = 0;
                    local numberOfRequests = params.numberOfRequests;
                    if (typeof numberOfRequests != "integer") {
                        numberOfRequests = 1;
                    }
                    for (local i = 0; i < numberOfRequests; i++) {
                        local method = params.methodOverride != null ? params.methodOverride : params.method;
                        if (typeof method == "string") {
                            method = method.tolower();
                        }
                        local signature = typeof params.signatureOverride == "string" ? params.signatureOverride : params.signature;
                        local req = http.request(
                            method,
                            http.agenturl() + signature, 
                            params.headers, 
                            params.body
                        );
                        req.sendasync(function(res) {
                            try {
                                local failedStatuscode = params.statuscode == 200 ? 500 : params.statuscode;
                                if (expect == "fail" && !assertDeepEqualWrap(res.statuscode, failedStatuscode)) {
                                    reject("createTest expected to be failed. Got response.statuscode " + res.statuscode + ", should be " + failedStatuscode + ". Response body: " + res.body);
                                    return;
                                }
                                if (typeof params.callbackVerify != "function" || (typeof params.callbackVerify == "function" && params.callbackVerify(res))) {
                                    if (assertDeepEqualWrap(params.statuscode, res.statuscode)) {
                                        if (++numberOfSucceedRequests >= numberOfRequests) {
                                            success();
                                        }
                                    } else {
                                        fail("Wrong response.statuscode " + res.statuscode + ", should be " + params.statuscode + ". Response body: " + res.body);
                                    }
                                } else {
                                    fail("Response verification failed by params.callbackVerify function");
                                }
                            } catch (ex) {
                                fail("Unexpected error while send request (sendasync): " + ex);
                            }
                        }.bindenv(this));
                    }
                } catch (ex) {
                    fail("Unexpected error while send request: " + ex);
                }
            }.bindenv(this));
            return true;
        } catch (ex) {
            fail("Unexpected error while send request: " + ex);
            return false;
        }
    }

    // createTestAll
    // Create Promise for series of tests testing Rocky
    // 
    // @param {array} tests - Array of 'params' for createTest(params)
    // @param {string} type - The condition for the success of all tests (positive|negative)
    // @return {Promise}
    function createTestAll(tests = [], type = "positive") {
        return Promise(function(resolve, reject) {
            try {
                if (typeof tests != "array") {
                    throw "Invalid type of createTestAll 'tests': " + typeof tests;
                }
                local length = tests.len();
                local index = 0;
                local successes = 0;
                local fails = 0;
                local lastReason = null;
                local execute;
                execute = function() {
                    try {
                        switch (type) {
                            case "negative": {
                                if (successes > 0) {
                                    reject("createTestAll resolved one of the tests, but 'type' was 'negative'");
                                    return;
                                }
                                if (fails >= length) {
                                    resolve();
                                    return;
                                }
                                break;
                            }
                            case "positive": default: {
                                if (fails > 0) {
                                    reject(lastReason);
                                    return;
                                }
                                if (successes >= length) {
                                    resolve();
                                    return;
                                }
                                break;
                            }
                        }
                        local test = tests[index++];
                        if (typeof test != "table") {
                            throw "Invalid type of createTest 'params': " + typeof test;
                        }
                        local expect = "success";
                        if ("_createTestExpect" in test) {
                            expect = test["_createTestExpect"];
                        }
                        createTest(test, expect)
                            .then(function(value) {
                                successes++;
                            })
                            .fail(function(reason) {
                                fails++;
                                lastReason = reason;
                            })
                            .finally(function(valueOrReason) {
                                imp.wakeup(0, execute);
                            });
                    } catch(ex) {
                        reject("Unexpected error while execute series of tests: " + ex);
                    }
                }.bindenv(this);
                execute();
            } catch(ex) {
                reject("Unexpected error while execute series of tests: " + ex);
            }
        }.bindenv(this));
    }

    // Wrapper of Perform a deep comparison of two values
    // Useful for comparing arrays or tables
    // @param {*} expected
    // @param {*} actual
    // @param {string} message
    function assertDeepEqualWrap(expected, actual, message = null) {
        try {
            this.assertDeepEqual(expected, actual, message);
            return true;
        } catch (ex) {
            // this.info(ex);
            return false;
        }
    }

    // Perform a deep verification of containing the first table, class or array in the second
    // @param {table|class|array} first
    // @param {table|class|array} second
    // @param {string} message
    // @private
    function deepContain(first, second, message = null) {
        foreach (k, v in first) {
            local tmp = null;
            if (k in second) {
                tmp = second[k];
            } else if ("string" == type(k)) {
                if (k.tolower() in second) {
                    tmp = second[k.tolower()];
                } else if (k.toupper() in second) {
                    tmp = "" + second[k.toupper()];
                }
            }
            if (tmp == null || !assertDeepEqualWrap("" + v, "" + tmp, message)) {
                return false;
            }
        }
        return true;
    }

    // Perform a deep loging for the first table, class or array
    // @param {table|class|array} value
    // @param {string} prefix - can be indent in the log line
    // @private
    function deepLog(value, prefix = "") {
        foreach (k, v in value) {
            this.info(prefix + k + "=" + v);
            local typeOfValue = type(v);
            if ("table" == typeOfValue || "class" == typeOfValue || "array" == typeOfValue) {
                deepLog(v, prefix + "  ");
            }
        }
    }
}
