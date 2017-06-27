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

function createTest(params) {
    return Promise(function(resolve, reject) {
        local app;
        local route;
        try {
            // Setup default values
            local setDefaultValue = function(key, value) {
                if (!(key in params) || params[key] == null) {
                    params[key] <- value;
                }
            }.bindenv(this);
            setDefaultValue("paramsApp", {});
            setDefaultValue("mw", []);
            setDefaultValue("mwArray", []);
            setDefaultValue("mwApp", []);
            setDefaultValue("mwAppArray", []);
            setDefaultValue("method", "GET");
            setDefaultValue("signature", "/test");
            setDefaultValue("signatureOverride", null);
            setDefaultValue("statuscode", 200);
            setDefaultValue("headers", {});
            setDefaultValue("body", "");
            setDefaultValue("timeout", false);
            setDefaultValue("callback", null);
            setDefaultValue("numberOfRequests", 1);
            setDefaultValue("onAuthorizeApp", null);
            setDefaultValue("onUnauthorizedApp", null);
            setDefaultValue("onTimeoutApp", null);
            setDefaultValue("onNotFoundApp", null);
            setDefaultValue("onExceptionApp", null);
            setDefaultValue("onAuthorizeRoute", null);
            setDefaultValue("onUnauthorizedRoute", null);
            setDefaultValue("onTimeoutRoute", null);
            setDefaultValue("onExceptionRoute", null);
        } catch (ex) {
            reject("Unexpected error while setup default values: " + ex);
            return;
        }
        try {
            // Setup Rocky handlers
            app = Rocky(params.paramsApp);
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
            route = app.on(params.method, params.signature, function(context) {
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
            }.bindenv(this));
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
                        local req = http.request(
                            params.method.tolower(), 
                            http.agenturl() + (typeof params.signatureOverride == "string" ? params.signatureOverride : params.signature), 
                            params.headers, 
                            params.body
                        );
                        req.sendasync(function(res) {
                            try {
                                local message = "Wrong response.statuscode " + res.statuscode + ", should be " + params.statuscode;
                                if (assertDeepEqualWrap(params.statuscode, res.statuscode, message)) {
                                    if (++numberOfSucceedRequests >= numberOfRequests) {
                                        resolve();
                                    }
                                } else {
                                    reject(message);
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

function assertDeepEqualWrap(expected, actual, message = null) {
    try {
        this.assertDeepEqual(expected, actual, message);
        return true;
    } catch (ex) {
        //this.info(ex);
        return false;
    }
}
