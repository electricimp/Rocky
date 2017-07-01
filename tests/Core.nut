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

// Default params for createTest function
defaultParams = {
    // Options for Rocky constructor
    "paramsRocky": {},
    // Options for calling Rocky.Route constructor directly
    "paramsRockyRoute": null,
    // Options for calling Rocky.Context constructor directly
    "paramsRockyContext": null,
    // Use for calling Rocky.Context constructor directly. If true, then all Rocky.Context methods will be called.
    "paramsRockyContextAdditionalUsage": false,
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
    "mwApp": [],
    // Array of middlewares for Rocky.use, that applied one by one
    "mwAppArray": [],
    // Middleware or array of middlewares for Rocky.Route.use
    "mw": [],
    // Array of middlewares for Rocky.Route.use, that applied one by one
    "mwArray": [],
    // Specifies handlers for Rocky.authorize|Rocky.onUnauthorized|Rocky.onTimeout|Rocky.onNotFound|Rocky.onException
    "onAuthorizeApp": null,
    "onUnauthorizedApp": null,
    "onTimeoutApp": null,
    "onNotFoundApp": null,
    "onExceptionApp": null,
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
// @return {Promise}
function createTest(params = {}) {
    return Promise(function(resolve, reject) {
        local app;
        local route;
        // Setup default values
        params.setdelegate(defaultParams);
        try {
            // Call Rocky.Route constructor directly
            if (params.paramsRockyRoute != null) {
                local illegalRoute = Rocky.Route(params.paramsRockyRoute);
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
                illegalRoute.use(params.mw);
                foreach (element in params.mwArray) {
                    illegalRoute.use(element);
                }
            }
            // Call Rocky.Context constructor directly
            if (params.paramsRockyContext != null) {
                local illegalContext = Rocky.Context(params.paramsRockyContext[0], params.paramsRockyContext[1]);
                if (params.paramsRockyContextAdditionalUsage != null && params.paramsRockyContextAdditionalUsage) {
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
        } catch(ex) {
            reject("Unexpected error while call constructors directly: " + ex);
            return;
        }
        try {
            // Setup Rocky handlers
            app = Rocky(params.paramsRocky);
            if (params.onAuthorizeApp != null) {
                app.authorize(params.onAuthorizeApp);
            }
            if (params.onUnauthorizedApp != null) {
                app.onUnauthorized(params.onUnauthorizedApp);
            }
            if (params.onTimeoutApp != null) {
                app.onTimeout(params.onTimeoutApp);
            }
            if (params.onNotFoundApp != null) {
                app.onNotFound(params.onNotFoundApp);
            }
            if (params.onExceptionApp != null) {
                app.onException(params.onExceptionApp);
            }
            app.use(params.mwApp);
            local failed = false;
            foreach (element in params.mwAppArray) {
                try {
                    app.use(element);
                } catch (ex) {
                    this.info("Unexpected error while setup Rocky.use: " + ex);
                    failed = true;
                }
            }
            if (failed) {
                reject();
            }
        } catch (ex) {
            reject("Unexpected error while setup Rocky handlers: " + ex);
            return;
        }
        try {
            // Setup Rocky.Route handlers
            local cb = params.cb;
            if (cb == null) {
                cb = function(context) {
                    try {
                        if (!params.timeout) {
                            if (params.callback != null) {
                                params.callback(context);
                            } else {
                                context.send(200, {"message": "OK"});
                            }
                        }
                    } catch (ex) {
                        reject("Unexpected error at Rocky.on callback: " + ex);
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
            route.use(params.mw);
            local failed = false;
            foreach (element in params.mwArray) {
                try {
                    route.use(element);
                } catch (ex) {
                    this.info("Unexpected error while setup Rocky.Route.use: " + ex);
                    failed = true;
                }
            }
            if (failed) {
                reject();
            }
        } catch (ex) {
            reject("Unexpected error while setup Rocky.Route handlers: " + ex);
            return;
        }
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
                            method.tolower();
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
                                if (typeof params.callbackVerify != "function" || (typeof params.callbackVerify == "function" && params.callbackVerify(res))) {
                                    if (assertDeepEqualWrap(params.statuscode, res.statuscode)) {
                                        if (++numberOfSucceedRequests >= numberOfRequests) {
                                            resolve();
                                        }
                                    } else {
                                        reject("Wrong response.statuscode " + res.statuscode + ", should be " + params.statuscode + ". Response body: " + res.body);
                                    }
                                } else {
                                    reject("Response verification failed by params.callbackVerify function");
                                }
                            } catch (ex) {
                                reject("Unexpected error while send request (sendasync): " + ex);
                            }
                        }.bindenv(this));
                    }
                } catch (ex) {
                    reject("Unexpected error while send request: " + ex);
                }
            }.bindenv(this));
        } catch (ex) {
            reject("Unexpected error while send request: " + ex);
            return;
        }
    }.bindenv(this));
}

// createTestAll
// Create Promise for series of tests testing Rocky
// 
// @param {array} tests - Array of 'params' for createTest(params)
// @return {Promise}
function createTestAll(tests = []) {
    return Promise(function(resolve, reject) {
        try {
            if (typeof tests != "array") {
                throw "Invalid type of createTestAll 'tests': " + typeof tests;
            }
            local length = tests.len();
            local index = -1;
            local interrupt = false;
            local execute;
            execute = function() {
                try {
                    if (++index >= length) {
                        resolve();
                    } else if (interrupt) {
                        reject();
                    } else {
                        local test = tests[index];
                        if (typeof test != "table") {
                            throw "Invalid type of createTest 'params': " + typeof test;
                        }
                        createTest(test)
                            .then(function(value) {
                                imp.wakeup(0, execute);
                            })
                            .fail(function(reason) {
                                interrupt = true;
                                reject(reason);
                            });
                    }
                } catch(ex) {
                    interrupt = true;
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
