[![DUB Version](https://img.shields.io/dub/v/fluent-asserts-vibe.svg)](https://code.dlang.org/packages/fluent-asserts-vibe)
[![DUB Installs](https://img.shields.io/dub/dt/fluent-asserts-vibe.svg)](https://code.dlang.org/packages/fluent-asserts-vibe)

# fluent-asserts-vibe

Extends [fluent-asserts](https://code.dlang.org/packages/fluent-asserts) with vibe.d specific assertions for testing HTTP routes and JSON values.

## Installation

Add the dependency to your `dub.json`:

```bash
dub add fluent-asserts-vibe
```

Import in your test files:

```d
version(unittest) import fluentasserts.vibe.request;
version(unittest) import fluentasserts.vibe.json;
```

## Testing HTTP Routes

Mock HTTP requests against your vibe.d router without starting a server:

```d
unittest {
    auto router = new URLRouter();
    router.get("/hello", (req, res) {
        res.writeBody("Hello, World!");
    });

    request(router)
        .get("/hello")
        .expectStatusCode(200)
        .end((Response response) => () {
            response.bodyString.should.equal("Hello, World!");
        });
}
```

### Request Methods

```d
request(router).get("/path")      // GET request
request(router).post("/path")     // POST request
request(router).put("/path")      // PUT request
request(router).patch("/path")    // PATCH request
request(router).delete_("/path")  // DELETE request
request(router).customMethod!(HTTPMethod.OPTIONS)("/path")  // Custom method
```

### Sending Data

```d
// Send JSON
request(router)
    .post("/api/users")
    .send(`{"name": "John"}`.parseJsonString)
    .end();

// Send form data
request(router)
    .post("/login")
    .send(["username": "john", "password": "secret"])
    .end();

// Send raw string
request(router)
    .post("/raw")
    .send("raw body content")
    .end();
```

### Headers

```d
request(router)
    .get("/api/data")
    .header("Authorization", "Bearer token123")
    .header("Accept", "application/json")
    .expectHeader("Content-Type", "application/json")
    .expectHeaderExist("X-Request-Id")
    .expectHeaderContains("Content-Type", "json")
    .end();
```

### Response Assertions

```d
request(router)
    .get("/api/users/1")
    .expectStatusCode(200)
    .end((Response response) => () {
        // Access response body as string
        response.bodyString.should.contain("John");

        // Access response body as JSON
        response.bodyJson["name"].should.equal("John");

        // Access raw body bytes
        response.bodyRaw.length.should.be.greaterThan(0);

        // Access response headers
        response.headers["Content-Type"].should.equal("application/json");
    });
```

## JSON Assertions

The library registers a custom JSON serializer and equality operation with fluent-asserts.

### Basic Comparisons

```d
auto json = `{"name": "John", "age": 30}`.parseJsonString;

json["name"].should.equal("John");
json["age"].should.equal(30);
json["age"].should.be.greaterThan(25);
json["age"].should.be.lessThan(40);
json["age"].should.be.between(25, 35);
```

### Whitespace-Agnostic Comparison

JSON comparisons ignore whitespace and key order:

```d
auto json1 = `{"b": 2, "a": 1}`.parseJsonString;
auto json2 = `{  "a" : 1 ,  "b" : 2  }`.parseJsonString;

json1.should.equal(json2);  // Passes

// Also works with strings
json1.should.equal(`{"a": 1, "b": 2}`);
```

### JSON Object Keys

```d
auto json = `{"name": "John", "address": {"city": "NYC"}}`.parseJsonString;

// Get top-level keys
json.keys.should.containOnly(["name", "address"]);

// Get all nested keys (dot notation for nested, brackets for arrays)
json.nestedKeys.should.contain("address.city");
```

### Flattening Nested Objects

```d
auto json = `{
    "user": {
        "name": "John",
        "contacts": {
            "email": "john@example.com"
        }
    }
}`.parseJsonString;

auto flat = json.flatten;
flat["user.name"].should.equal("John");
flat["user.contacts.email"].should.equal("john@example.com");
```

### Approximate Comparisons

```d
Json(10.0 / 3.0).should.be.approximately(3.33, 0.01);
```

## Running Tests

```bash
dub test
```

## API Documentation

Full documentation: [http://fluentasserts.szabobogdan.com/](http://fluentasserts.szabobogdan.com/)

## License

MIT. See LICENSE for details.
