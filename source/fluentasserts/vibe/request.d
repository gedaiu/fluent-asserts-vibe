module fluentasserts.vibe.request;

version(Have_vibe_d_http):

import vibe.inet.url;
import vibe.http.router;
import vibe.http.form;
import vibe.data.json;

import vibe.core.stream;
import vibe.stream.memory : MemoryOutputStream, createMemoryOutputStream;

import std.conv, std.string, std.array;
import std.algorithm, std.conv;
import std.stdio;
import std.format;
import std.exception;

import fluentasserts.core.base;
import fluentasserts.core.evaluation.eval : Evaluation;
import fluentasserts.core.memory.heapstring : HeapData;
import fluentasserts.results.source.result : SourceResult;

//@safe:

/// Helper to put an integer into HeapData without GC allocation
private void putInt(ref HeapData!ubyte builder, int value) @trusted @nogc nothrow {
  if (value < 0) {
    builder.put(cast(ubyte)'-');
    value = -value;
  }

  if (value == 0) {
    builder.put(cast(ubyte)'0');
    return;
  }

  // Max int is 10 digits
  ubyte[10] digits;
  size_t count = 0;

  while (value > 0) {
    digits[count++] = cast(ubyte)('0' + (value % 10));
    value /= 10;
  }

  // Reverse and append
  foreach_reverse (i; 0 .. count) {
    builder.put(digits[i]);
  }
}

class MockInputStream: InputStream {
  @safe:
    ubyte[] data;

    this(ubyte[] data) {
      this.data = data;
    }

    bool dataAvailableForRead() {
      return data.length > 0;
    }

    bool empty() {
      return data.length == 0;
    }

    size_t leastSize() {
      return data.length;
    }

    const(ubyte)[] peek() {
      return data;
    }

    ulong read(scope ubyte[] dst, IOMode mode) {
      size_t i;

      while(i < dst.length && i < data.length) {
        dst[i] = data[i];
        i++;
      }

      data = data[i..$];

      return i;
    }
}

HTTPServerRequest _createTestHTTPServerRequest(URL url, HTTPMethod method)
@safe {
  auto ret = createTestHTTPServerRequest(url, method);
  ret.tls = false;
  ret.bodyReader = new MockInputStream([]);

  return ret;
}

HTTPServerResponse _createTestHTTPServerResponse(MemoryOutputStream stream)
@safe {
	import vibe.http.server : createTestHTTPServerResponse, TestHTTPResponseMode;

	return createTestHTTPServerResponse(stream, null, TestHTTPResponseMode.bodyOnly);
}

RequestRouter request(URLRouter router) {
  return new RequestRouter(router);
}

///
final class RequestRouter {
  private {
    alias ExpectedCallback = void delegate(Response res);
    ExpectedCallback[] expected;
    URLRouter router;
    HTTPServerRequest preparedRequest;

    string[string] headers;

    string responseBody;
  }

  ///
  this(URLRouter router) {
    this.router = router;
  }

  /// Send a string[string] to the server as x-www-form-urlencoded data
  RequestRouter send(string[string] data) {
    auto dst = appender!string;

    dst.writeFormData(data);
    header("Content-Type", "application/x-www-form-urlencoded");

    import std.stdio;
    preparedRequest.bodyReader = new MockInputStream(cast(ubyte[]) dst.data.dup);

    foreach(string key, value; data) {
      preparedRequest.form[key] = value;
    }

    return this;
  }

  /// Send data to the server. You can send strings, Json or any other object
  /// which will be serialized to Json
  RequestRouter send(T)(T data) {
    static if (is(T == string))
    {
      preparedRequest.bodyReader = new MockInputStream(cast(ubyte[]) data);
      return this;
    }
    else static if (is(T == Json))
    {
      preparedRequest.bodyReader = new MockInputStream(cast(ubyte[]) data.toPrettyString);
      preparedRequest.json = data;
      return this;
    }
    else
    {
      return send(data.serializeToJson());
    }
  }

  /// Add a header to the server request
  RequestRouter header(string name, string value) {
    if(preparedRequest is null) {
      headers[name] = value;
    } else {
      preparedRequest.headers[name] = value;
    }
    return this;
  }

  /// Send a POST request
  RequestRouter post(string host = "localhost", ushort port = 80)(string path) {
    return customMethod!(HTTPMethod.POST, host, port)(path);
  }

  /// Send a PATCH request
  RequestRouter patch(string host = "localhost", ushort port = 80)(string path) {
    return customMethod!(HTTPMethod.PATCH, host, port)(path);
  }

  /// Send a PUT request
  RequestRouter put(string host = "localhost", ushort port = 80)(string path) {
    return customMethod!(HTTPMethod.PUT, host, port)(path);
  }

  /// Send a DELETE request
  RequestRouter delete_(string host = "localhost", ushort port = 80)(string path) {
    return customMethod!(HTTPMethod.DELETE, host, port)(path);
  }

  /// Send a GET request
  RequestRouter get(string host = "localhost", ushort port = 80)(string path) {
    return customMethod!(HTTPMethod.GET, host, port)(path);
  }

  /// Send a custom method request
  RequestRouter customMethod(HTTPMethod method, string host = "localhost", ushort port = 80)(string path) {
    return customMethod!method(URL("http://" ~ host ~ ":" ~ port.to!string ~ path));
  }

  /// ditto
  RequestRouter customMethod(HTTPMethod method)(URL url) {
    preparedRequest = _createTestHTTPServerRequest(url, method);
    preparedRequest.host = url.host;

    foreach(name, value; headers) {
      preparedRequest.headers[name] = value;
    }

    return this;
  }

  RequestRouter expectHeaderExist(string name, const string file = __FILE__, const size_t line = __LINE__) {
    void localExpectHeaderExist(Response res) {
      expect(res.headers.keys, file, line).to.contain(name)
        .because("response header `" ~ name ~ "` is missing");
    }

    expected ~= &localExpectHeaderExist;

    return this;
  }

  RequestRouter expectHeader(string name, string value, const string file = __FILE__, const size_t line = __LINE__) {
    expectHeaderExist(name, file, line);

    void localExpectedHeader(Response res) {
      expect(res.headers[name], file, line).to.equal(value)
        .because("response header `" ~ name ~ "` has an unexpected value");
    }

    expected ~= &localExpectedHeader;

    return this;
  }

  RequestRouter expectHeaderContains(string name, string value, const string file = __FILE__, const size_t line = __LINE__) {
    expectHeaderExist(name, file, line);

    void localExpectHeaderContains(Response res) {
      expect(res.headers[name], file, line).to.contain(value)
        .because("response header `" ~ name ~ "` has an unexpected value");
    }

    expected ~= &localExpectHeaderContains;

    return this;
  }

  RequestRouter expectStatusCode(int code, const string file = __FILE__, const size_t line = __LINE__) {
    void localExpectStatusCode(Response res) {
      if(code != 404 && res.statusCode == 404) {
        writeln("\n\nIs your route defined here?");
        router.getAllRoutes.map!(a => a.method.to!string ~ " " ~ a.pattern).each!writeln;
      }

      if(code != res.statusCode) {
        Evaluation evaluation;
        evaluation.isEvaluated = true;
        evaluation.source = SourceResult.create(file, line);
        evaluation.result.addText("Invalid status code.");
        evaluation.result.expected.put(code.to!string ~ " - " ~ httpStatusText(code));
        evaluation.result.actual.put(res.statusCode.to!string ~ " - " ~ httpStatusText(res.statusCode));

        throw new TestException(evaluation);
      }
    }

    expected ~= &localExpectStatusCode;

    return this;
  }

  private void performExpected(Response res) {
    foreach(func; expected) {
      func(res);
    }
  }

  void end() {
    end((Response response) => () { });
  }

  void end(T)(T callback) @trusted {
    import vibe.stream.operations : readAllUTF8;
    import vibe.inet.webform;
    import vibe.http.status : httpStatusText;

    auto stream = createMemoryOutputStream();

    HTTPServerResponse res = _createTestHTTPServerResponse(stream);
    res.statusCode = 404;

    router.handleRequest(preparedRequest, res);

    // Build HTTP response manually since we use bodyOnly mode
    // Using HeapData to avoid GC allocations
    auto responseBuilder = HeapData!ubyte.create(4096);

    // Status line: "HTTP/1.1 XXX Status Text\r\n"
    responseBuilder.put(cast(const(ubyte)[])"HTTP/1.1 ");
    putInt(responseBuilder, res.statusCode);
    responseBuilder.put(cast(ubyte)' ');
    responseBuilder.put(cast(const(ubyte)[])httpStatusText(res.statusCode));
    responseBuilder.put(cast(const(ubyte)[])"\r\n");

    // Headers
    foreach (k, v; res.headers.byKeyValue) {
      responseBuilder.put(cast(const(ubyte)[])k);
      responseBuilder.put(cast(const(ubyte)[])": ");
      responseBuilder.put(cast(const(ubyte)[])v);
      responseBuilder.put(cast(const(ubyte)[])"\r\n");
    }
    responseBuilder.put(cast(const(ubyte)[])"\r\n");

    // Body
    ubyte[] bodyData = stream.data.dup;
    responseBuilder.put(bodyData);

    ubyte[] data = responseBuilder[].dup;
    if (data.length == 0 || !res.headerWritten) {
      enum notFound = "HTTP/1.1 404 No Content\r\n\r\n";
      data = cast(ubyte[]) notFound.dup;
    }

    auto response = new Response(data, bodyData.length);

    callback(response)();

    performExpected(response);
  }
}

///
class Response {
  ubyte[] bodyRaw;

  private {
    Json _bodyJson;
    string responseLine;
    string originalStringData;
  }

  ///
  string[string] headers;

  ///
  int statusCode;

  /// Instantiate the Response
  this(ubyte[] data, ulong len) {
    this.originalStringData = (cast(char[])data).toStringz.to!string.dup;

    auto bodyIndex = originalStringData.indexOf("\r\n\r\n");

    assert(bodyIndex != -1, "Invalid response data: \n" ~ originalStringData ~ "\n\n");

    auto headers = originalStringData[0 .. bodyIndex].split("\r\n").array;

    responseLine = headers[0];
    statusCode = headers[0].split(" ")[1].to!int;

    foreach (i; 1 .. headers.length) {
      auto header = headers[i].split(": ");
      this.headers[header[0]] = header[1];
    }

    size_t start = bodyIndex + 4;
    size_t end = bodyIndex + 4 + len;

    if("Transfer-Encoding" in this.headers && this.headers["Transfer-Encoding"] == "chunked") {

      while(start < end) {
        size_t pos = data[start..end].assumeUTF.indexOf("\r\n").to!size_t;
        if(pos == -1) {
          break;
        }

        auto ln = data[start..start+pos].assumeUTF;
        auto chunkSize = parse!size_t(ln, 16u);

        if(chunkSize == 0) {
          break;
        }

        start += pos + 2;
        bodyRaw ~= data[start..start+chunkSize];
        start += chunkSize + 2;
      }
      return;
    }

    bodyRaw = data[start .. end];
  }

  /// get the body as a string
  string bodyString() {
    return (cast(char[])bodyRaw).toStringz.to!string.dup;
  }

  /// get the body as a json object
  Json bodyJson() {
    if (_bodyJson.type == Json.Type.undefined)
    {
      string str = this.bodyString();

      try {
        _bodyJson = str.parseJson;
      } catch(Exception e) {
        writeln("`" ~ str ~ "` is not a json string");
      }
    }

    return _bodyJson;
  }

  /// get the request as a string
  override string toString() const {
    return originalStringData;
  }
}

@("Mocking a GET Request")
unittest {
  auto router = new URLRouter();

  void sayHello(HTTPServerRequest req, HTTPServerResponse res)
  {
    res.writeBody("hello");
  }

  router.get("*", &sayHello);
  request(router)
    .get("/")
      .end((Response response) => () {
        response.bodyString.should.equal("hello");
      });

  request(router)
    .post("/")
      .end((Response response) => () {
        response.bodyString.should.not.equal("hello");
      });
}

@("Mocking a POST Request")
unittest {
  auto router = new URLRouter();

  void sayHello(HTTPServerRequest req, HTTPServerResponse res)
  {
    res.writeBody("hello");
  }

  router.post("*", &sayHello);
  request(router)
    .post("/")
      .end((Response response) => () {
        response.bodyString.should.equal("hello");
      });

  request(router)
    .get("/")
      .end((Response response) => () {
        response.bodyString.should.not.equal("hello");
      });
}

@("Mocking a PATCH Request")
unittest {
  auto router = new URLRouter();

  void sayHello(HTTPServerRequest req, HTTPServerResponse res)
  {
    res.writeBody("hello");
  }

  router.patch("*", &sayHello);
  request(router)
    .patch("/")
      .end((Response response) => () {
        response.bodyString.should.equal("hello");
      });

  request(router)
    .get("/")
      .end((Response response) => () {
        response.bodyString.should.not.equal("hello");
      });
}

@("Mocking a PUT Request")
unittest {
  auto router = new URLRouter();

  void sayHello(HTTPServerRequest req, HTTPServerResponse res)
  {
    res.writeBody("hello");
  }

  router.put("*", &sayHello);
  request(router)
    .put("/")
      .end((Response response) => () {
        response.bodyString.should.equal("hello");
      });

  request(router)
    .get("/")
      .end((Response response) => () {
        response.bodyString.should.not.equal("hello");
      });
}

@("Mocking a DELETE Request")
unittest {
  auto router = new URLRouter();

  void sayHello(HTTPServerRequest req, HTTPServerResponse res)
  {
    res.writeBody("hello");
  }

  router.delete_("*", &sayHello);
  request(router)
    .delete_("/")
      .end((Response response) => () {
        response.bodyString.should.equal("hello");
      });

  request(router)
    .get("/")
      .end((Response response) => () {
        response.bodyString.should.not.equal("hello");
      });
}

@("Mocking a ACL Request")
unittest {
  auto router = new URLRouter();

  void sayHello(HTTPServerRequest, HTTPServerResponse res)
  {
    res.writeBody("hello");
  }

  router.match(HTTPMethod.ACL, "*", &sayHello);

  request(router)
    .customMethod!(HTTPMethod.ACL)("/")
      .end((Response response) => () {
        response.bodyString.should.equal("hello");
      });

  request(router)
    .get("/")
      .end((Response response) => () {
        response.bodyString.should.not.equal("hello");
      });
}

@("Sending headers")
unittest {
  auto router = new URLRouter();

  void checkHeaders(HTTPServerRequest req, HTTPServerResponse)
  {
    req.headers["Accept"].should.equal("application/json");
  }

  router.any("*", &checkHeaders);

  request(router)
    .get("/")
    .header("Accept", "application/json")
      .end();
}

@("Sending raw string")
unittest {
  import std.string;

  auto router = new URLRouter();

  void checkStringData(HTTPServerRequest req, HTTPServerResponse)
  {
    req.bodyReader.peek.assumeUTF.to!string.should.equal("raw string");
  }

  router.any("*", &checkStringData);

  request(router)
    .post("/")
        .send("raw string")
      .end();
}

@("Receiving raw binary")
unittest {
  import std.string;

  auto router = new URLRouter();

  void checkStringData(HTTPServerRequest req, HTTPServerResponse res)
  {
    res.writeBody(cast(ubyte[]) [0, 1, 2], 200, "application/binary");
  }

  router.any("*", &checkStringData);

  request(router)
    .post("/")
    .end((Response response) => () {
      response.bodyRaw.should.equal(cast(ubyte[]) [0,1,2]);
    });
}

@("Sending form data")
unittest {
  auto router = new URLRouter();

  void checkFormData(HTTPServerRequest req, HTTPServerResponse)
  {
    req.headers["content-type"].should.equal("application/x-www-form-urlencoded");

    req.form["key1"].should.equal("value1");
    req.form["key2"].should.equal("value2");
  }

  router.any("*", &checkFormData);

  request(router)
    .post("/")
    .send(["key1": "value1", "key2": "value2"])
      .end();
}

@("Sending json data")
unittest {
  auto router = new URLRouter();

  void checkJsonData(HTTPServerRequest req, HTTPServerResponse)
  {
    req.json["key"].to!string.should.equal("value");
  }

  router.any("*", &checkJsonData);

  request(router)
    .post("/")
        .send(`{ "key": "value" }`.parseJsonString)
      .end();
}

@("Receive json data")
unittest {
  auto router = new URLRouter();

  void respondJsonData(HTTPServerRequest, HTTPServerResponse res)
  {
    res.writeJsonBody(`{ "key": "value"}`.parseJsonString);
  }

  router.any("*", &respondJsonData);

  request(router)
    .get("/")
      .end((Response response) => () {
        response.bodyJson["key"].to!string.should.equal("value");
      });
}

@("Expect status code")
unittest {
  auto router = new URLRouter();

  void respondStatus(HTTPServerRequest, HTTPServerResponse res)
  {
    res.writeBody("", 200, "plain/text");
  }

  router.get("*", &respondStatus);

  request(router)
    .get("/")
    .expectStatusCode(200)
      .end();


  ({
    request(router)
      .post("/")
      .expectStatusCode(200)
        .end();
  }).should.throwException!TestException.msg.should.contain("Invalid status code.");
}


/// Expect header
unittest {
  auto router = new URLRouter();

  void respondHeader(HTTPServerRequest, HTTPServerResponse res)
  {
    res.headers["some-header"] = "some-value";
    res.writeBody("");
  }

  router.get("*", &respondHeader);


  // Check for the exact header value:
  request(router)
    .get("/")
    .expectHeader("some-header", "some-value")
      .end();


  ({
    request(router)
      .post("/")
      .expectHeader("some-header", "some-value")
        .end();
  }).should.throwAnyException.msg.should.contain("response header `some-header` is missing");

  ({
    request(router)
      .get("/")
      .expectHeader("some-header", "other-value")
        .end();
  }).should.throwAnyException.msg.should.contain("response header `some-header` has an unexpected value");

  // Check if a header exists
  request(router)
    .get("/")
    .expectHeaderExist("some-header")
      .end();


  ({
    request(router)
      .post("/")
      .expectHeaderExist("some-header")
        .end();
  }).should.throwAnyException.msg.should.contain("response header `some-header` is missing");

  // Check if a header contains a string
  request(router)
    .get("/")
    .expectHeaderContains("some-header", "value")
      .end();

  ({
    request(router)
      .get("/")
      .expectHeaderContains("some-header", "other")
        .end();
  }).should.throwAnyException.msg.should.contain("response header `some-header` has an unexpected value");
}
