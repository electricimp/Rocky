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

// RockyHandlers
// Tests for Rocky.authorize, Rocky.onUnauthorized, Rocky.onTimeout, Rocky.onException, Rocky.onNotFound
class RockyHandlers extends ImpTestCase {

    @include __PATH__+"/Core.nut"
    @include __PATH__+"/CoreHandlers.nut"

    auth = null;
    authWrong = null;

    function setUp() {
        this.auth = "Basic 123456789qwerty";
        this.authWrong = "Basic wrong";
    }

    function testAuthorizationSuccess() {
        return createTest({
            "signature": "/testAuthorizationSuccess",
            "onAuthorizeApp": onAuthorize.bindenv(this),
            "headers": {
                "Authorization": this.auth
            }
        });
    }

    function testAuthorizationFailure() {
        return createTest({
            "signature": "/testAuthorizationFailure",
            "onAuthorizeApp": onAuthorize.bindenv(this),
            "onUnauthorizedApp": onUnauthorized.bindenv(this),
            "headers": {
                "Authorization": this.authWrong
            },
            "statuscode": 401
        });
    }

    function testAuthorizationException() {
        return createTest({
            "signature": "/testAuthorizationException",
            "onAuthorizeApp": throwException.bindenv(this),
            "onExceptionApp": onException.bindenv(this),
            "statuscode": 500
        });
    }

    function testAuthorizationFailureException() {
       return createTest({
            "signature": "/testAuthorizationFailureException",
            "onAuthorizeApp": onAuthorize.bindenv(this),
            "onUnauthorizedApp": throwException.bindenv(this),
            "onExceptionApp": onException.bindenv(this),
            "headers": {
                "Authorization": this.authWrong
            },
            "statuscode": 500
        });
    }

    function testAuthorizationWrongReturn() {
        return createTest({
            "signature": "/testAuthorizationWrongReturn",
            "onAuthorizeApp": onWrongAuthorize.bindenv(this)
        });
    }

    function testTimeout() {
        this.info("This test will take a couple of seconds");
        return createTest({
            "signature": "/testTimeout",
            "timeout": true,
            "onTimeoutApp": onTimeout.bindenv(this),
            "statuscode": 408
        });
    }

    function testTimeoutException() {
        this.info("This test will take a couple of seconds");
        return createTest({
            "signature": "/testTimeout",
            "timeout": true,
            "onTimeoutApp": throwException.bindenv(this),
            "onExceptionApp": onException.bindenv(this),
            "statuscode": 500
        });
    }

    function testNotFound() {
        return createTest({
            "signature": "/testNotFound",
            "signatureOverride": "/testNotFoundIDontExist",
            "onNotFoundApp": onNotFound.bindenv(this),
            "statuscode": 404
        });
    }

    function testNotFoundException() {
        return createTest({
            "signature": "/testNotFoundException",
            "signatureOverride": "/testNotFoundIDontExist",
            "onNotFoundApp": throwException.bindenv(this),
            "onExceptionApp": onException.bindenv(this),
            "statuscode": 500
        });
    }

    function testExceptionAtOnException() {
        return createTest({
            "signature": "/testExceptionAtOnException",
            "signatureOverride": "/testExceptionAtExceptionIDontExist",
            "onNotFoundApp": throwException.bindenv(this),
            "onExceptionApp": throwExceptionOnException.bindenv(this),
            "statuscode": 500
        });
    }
}
