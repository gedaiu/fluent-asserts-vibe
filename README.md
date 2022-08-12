[![DUB Version](https://img.shields.io/dub/v/fluent-asserts-vibe.svg)](https://code.dlang.org/packages/fluent-asserts-vibe)
[![DUB Installs](https://img.shields.io/dub/dt/fluent-asserts-vibe.svg)](https://code.dlang.org/packages/fluent-asserts-vibe)

There are a lot of ways in which you can test an web api. Unfortunately, vibe.d does not come with utilities that allows us to write
simple and nice tests. This is a library that improves your testing experience by extending the fluent-asserts library with features that help you
to test routes and `Json` values.

## To begin

1. Add the DUB dependency:
[https://code.dlang.org/packages/fluent-asserts-vibe](https://code.dlang.org/packages/fluent-asserts-vibe)

    ```bash
        $ dub add fluent-asserts-vive
    ```

    in your source files:
    ```
    version(unittest) import fluent.asserts.vibe;
    ```

2. Use it:
```D
    unittest {
        auto request = new RequestRouter(router);

        request
            .get("/")
            .end((Response response) => () {
                response.bodyString.should.not.equal("hello");
            });
    }

    unittest {
        Assert.equal(true, false, "this is a failing assert");
    }
```

3. Run the tests:
```D
➜  dub test --compiler=ldc2
```

# API Docs

The full documentation of the fluent-asserts can be found at:
[http://fluentasserts.szabobogdan.com/](http://fluentasserts.szabobogdan.com/)


# License

MIT. See LICENSE for details.
