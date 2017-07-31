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

function onAuthorize(context) {
    return context.getHeader("Authorization") == this.auth;
}

function onWrongAuthorize(context) {
    return {"hello": "there"};
}

function onUnauthorized(context) {
    context.send(401, {"message": "Unauthorized"});
}

function onTimeout(context) {
    context.send(408, {"message": "Request Timeout"});
}

function onException(context, ex) {
    context.send(500, {"message": "Internal Agent Error", "error": ex});
}

function onNotFound(context) {
    context.send(404, {"message": "Not found"});
}

function throwException(context){
    throw "Synthetic exception";
}

function throwExceptionOnException(context, ex){
    throw "Synthetic exception";
}
