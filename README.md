[![Build Status](https://travis-ci.org/gedaiu/fluent-asserts.svg?branch=master)](https://travis-ci.org/gedaiu/fluent-asserts)
[![Line Coverage](https://szabobogdan3.gitlab.io/fluent-asserts-coverage/coverage-shield.svg)](https://szabobogdan3.gitlab.io/fluent-asserts-coverage/)
[![DUB Version](https://img.shields.io/dub/v/fluent-asserts.svg)](https://code.dlang.org/packages/fluent-asserts)
[![DUB Installs](https://img.shields.io/dub/dt/fluent-asserts-coverage.svg)](https://code.dlang.org/packages/fluent-asserts-coverage)

There are a lot of ways in which you can test an web api. Unfortunately, vibe.d does not come with utilities that allows us to write
simple and nice tests. This is a library that improves your testing experience by extending the fluent-asserts library.

## To begin

1. Add the DUB dependency:
[https://code.dlang.org/packages/fluent-asserts](https://code.dlang.org/packages/fluent-asserts-vibe)

2. Import it:

    in `dub.json`:
    ```json
        ...
        "configurations": [
            ...
            {
                "name": "unittest",
                "dependencies": {
                    "fluent-asserts-vibe": "~>0.1.0",
                    ...
                }
            },
            ...
        ]
        ...
    ```

    in your source files:
    ```D
    version(unittest) import fluent.asserts.vibe;
    ```

3. Use it:
```D
    unittest {
        auto request = new RequestRouter(router);

        request
            .get("/")
            .end((Response response) => {
                response.bodyString.should.not.equal("hello");
            });
    }

    unittest {
        Assert.equal(true, false, "this is a failing assert");
    }
```

4. Run the tests:
```D
➜  dub test --compiler=ldc2
```

# API Docs

The full documentation of the fluent-asserts can be found at:
[http://fluentasserts.szabobogdan.com/](http://fluentasserts.szabobogdan.com/)


# License

MIT. See LICENSE for details.
