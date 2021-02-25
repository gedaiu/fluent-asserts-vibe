module some.module;

import std.exception;

class Foo {

    this() {
        ///...
    }

    void bar() {
        assert(false);
    }

    void bar2() {
        enforce(false);
    }
}
