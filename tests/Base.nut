    // Wrapper of Perform a deep comparison of two values
    // Useful for comparing arrays or tables
    // @param {*} expected
    // @param {*} actual
    // @param {string} message
    // @private
    function _assertDeepEqualWrap(expected, actual, message = null) {
        try {
            assertDeepEqual(expected, actual, message);
            return true;
        } catch (err) {
            this.info(err);
            return false;
        }
    }

    // Perform a deep verification of containing the first table, class or array in the second
    // @param {table|class|array} first
    // @param {table|class|array} second
    // @param {string} message
    // @private
    function _deepContain(first, second, message = null) {
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
            if (tmp == null ||
                ! _assertDeepEqualWrap("" + v, "" + tmp, message)) {
                    return false;
            }
        }
        return true;
    }

    // Perform a deep loging for the first table, class or array
    // @param {table|class|array} value
    // @param {string} prefix - can be indent in the log line
    // @private
    function _deepLog(value, prefix = "") {
        foreach (k, v in value) {
            this.info(prefix + k + "=" + v);
            local typeOfValue = type(v);
            if ("table" == typeOfValue ||
                "class" == typeOfValue ||
                "array" == typeOfValue) {
                _deepLog(v, prefix + "  ");
            }
        }
    }

    // Create generic Promise for testing Rocky. Scenario of the method:
    // 1) Create Rocky instance if needed
    // 2) Create Rocky callback function with signature, query, headers, body verification
    // 3) Assign routes based on the specified verb and signature (with the callback) OR 
    //    call the "configureRocky" method with (Rocky instance, callback function) parameters.
    //    The "configureRocky" method may be used for registering any callbacks, "onTimeout" for example
    // 4) Create OR call "createRequestFunc" and send HTTP request to Rocky
    // 5) Get and verify the HTTP request in the Rocky callback (see 2)
    // 6) If requestFunc is not defined prepare the HTTP response and send it.
    //    Othewise call the requestFunc with "context" parameter  The function
    //    have to return status code. It will be used in HTTP responsenext step
    // 7) Get the HTTP response. Verify status code
    // 8) Call the responseFunc if it is defined. Othewise verify response body.
    //
    // @param {Rocky} app - instance of Rocky. New instance will be created if null
    // @params {string} verb - Optional. The HTTP method (verb). Default - "getVerb()"
    // @param {string} signature, query, headers, body - Optional. Parameters are used in HTTP request.
    // @params {function(Rocky,Callback)} configureRocky - Optional.
    // @params {function(Rocky.Context)} requestFunc - Optional.
    // @params {function(response : Table)} responseFunc - Optional.
    // @private
    // @return {Promise} 
    function _createTestPromise(app = null, verb = getVerb(), signature = "/test",
        query = {}, headers = {}, body = "body",
        configureRocky = null, createRequestFunc = null, requestFunc = null, responseFunc = null) {
        return Promise(function(ok, err) {
            if (app == null) {
                app = Rocky();
            }
            local methodName =verb.tolower();
            local statuscode = null;
            local response_body = "response body";
            local cb = function(context) {
                //this.info("Rocky: request is received.");
                try {
                    local actual = context.req.method;
                    local message = "Wrong context.req.method " + actual + ", should be " + verb;
                    if (!_assertDeepEqualWrap(verb, actual, message)) {
                        err(message);
                    }
                    actual = context.req.path;
                    local tmp = signature;
                    if (context.matches.len() > 0) {
                        tmp = context.matches[0];
                        message = "Wrong context.req.path should be " + signature;
                    } else {
                        message = "Wrong context.req.path " + actual + ", should be " + signature;
                    }
                    if (!_assertDeepEqualWrap(tmp, actual, message)) {
                        if (context.matches.len() > 0) {
                            this.info("---------actual pathes----------");
                            _deepLog(context.matches);
                        }
                        err(message);
                    }

                    actual = context.req.query;
                    message = "Wrong context.req.query";
                    if (!_deepContain(query, actual, message)) {
                        this.info("---------actual query----------");
                        _deepLog(actual);
                        this.info("---------should contain----------");
                        _deepLog(query);
                        this.info("---------end----------");
                        err(message);
                    }

                    actual = context.req.headers;
                    message = "Wrong context.req.headers";
                    if (!_deepContain(headers, actual, message)) {
                        this.info("---------Headers----------");
                        _deepLog(actual);
                        this.info("---------should contain----------");
                        _deepLog(headers);
                        this.info("---------end----------");
                        err(message);
                    }

                    actual = context.req.body;
                    if ("content-type" in context.req.headers &&
                        ((tmp = context.req.headers["content-type"]) == "application/json" ||
                        tmp == "application/x-www-form-urlencoded" ||
                        tmp == "multipart/form-data")) {
                        if ("table" != type(actual)) {
                            err("Wrong type of context.req.body " + type(actual) + ", should be table");
                        }
                        actual = context.req.rawbody;
                    }
                    message = "Wrong context.req.body " + actual + ", should be " + body;
                    if (!_assertDeepEqualWrap(body, actual, message)) {
                        err(message);
                    }
                    // send a response
                    if (requestFunc == null) {
                        statuscode = 200;
                        //this.info("Rocky: send response.");
                        context.send(response_body);
                    } else {
                        statuscode = requestFunc(context);
                    }
                } catch (ex) {
                    err("Unexpected error: " + ex);
                }
            }.bindenv(this);
            if (configureRocky != null) {
                configureRocky(app, cb);
            } else if (methodName in app) {
                    app[methodName](signature, cb);
            } else {
                    app.on(verb, signature, cb);
            }
            imp.wakeup(0 , function() {
                //this.info("Send request to Rocky....");
                try {
                    //TODO: query
                    local req = createRequestFunc == null ? http.request(verb, http.agenturl() + signature,
                        headers, body) : createRequestFunc();
                    req.sendasync( function(resp) {
                        //this.info("Response is received.");
                        local actual = resp.statuscode;
                        local message = "Wrong response.statuscode " + actual + ", should be " + statuscode;
                        if (!_assertDeepEqualWrap(statuscode, actual, message)) {
                            err(message);
                        }
                        if (requestFunc == null) {
                            actual = resp.body;
                            message = "Wrong response.body " + actual + ", should be " + response_body;
                            if (!_assertDeepEqualWrap(response_body, actual, message)) {
                                err(message);
                            }
                        } else if (responseFunc != null && !responseFunc(resp)) {
                            err("Wrong response.body");
                        }
                        ok();
                    }.bindenv(this));
                } catch (ex) {
                    err("Unexpected error: " + ex);
                }
            }.bindenv(this));
        }.bindenv(this));
    }
