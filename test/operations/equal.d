module test.operations.equal;

import fluentasserts.core.expect;
import fluent.asserts;

import trial.discovery.spec;
import vibe.data.json;

import std.string;
import std.conv;
import std.meta;

alias s = Spec!({

  alias StringTypes = AliasSeq!(string, wstring, dstring);

  static foreach(Type; StringTypes) {
    describe("using " ~ Type.stringof ~ " values", {
      Type testValue;
      Type otherTestValue;

      before({
        testValue = "test string".to!Type;
        otherTestValue = "test".to!Type;
      });

      it("should be able to compare two exact strings", {
        expect(Json("test string")).to.equal("test string");
        expect("test string").to.equal(Json("test string"));
      });

      it("should be able to check if two strings are not equal", {
        expect(Json("test string")).to.not.equal("test");
        expect("test string").to.not.equal(Json("test"));
      });

      it("should throw an exception with a detailed message when the strings are not equal", {
        auto msg = ({
          expect(Json("test string")).to.equal("test");
        }).should.throwException!TestException.msg;

        msg.split("\n")[0].should.equal(`"test string" should equal "test". "test string" is not equal to "test".`);
      });

      it("should throw an exception with a detailed message when the strings should not be equal", {
        auto msg = ({
          expect(Json("test string")).to.not.equal("test string");
        }).should.throwException!TestException.msg;

        msg.split("\n")[0].should.equal(`"test string" should not equal "test string". "test string" is equal to "test string".`);
      });

      it("should show the null chars in the detailed message", {
        auto msg = ({
          ubyte[] data = [115, 111, 109, 101, 32, 100, 97, 116, 97, 0, 0];
          expect(data.assumeUTF.to!Type).to.equal(Json("some data"));
        }).should.throwException!TestException.msg;

        msg.should.contain(`Actual:"some data\0\0"`);
        msg.should.contain(`some data[+\0\0]`);
      });
    });
  }

  alias IntegerTypes = AliasSeq!(byte, ubyte, short, ushort, int, uint, long, ulong);

  static foreach(Type; IntegerTypes) {
    describe("using " ~ Type.stringof ~ " values", {
      Type testValue;
      Type otherTestValue;

      before({
        testValue = cast(Type) 40;
        otherTestValue = cast(Type) 50;
      });

      it("should be able to compare two exact values", {
        expect(Json(testValue)).to.equal(testValue);
        expect(testValue).to.equal(Json(testValue));
      });

      it("should be able to check if two values are not equal", {
        expect(Json(testValue)).to.not.equal(otherTestValue);
        expect(testValue).to.not.equal(Json(otherTestValue));
      });

      it("should throw an exception with a detailed message when the strings are not equal", {
        auto msg = ({
          expect(Json(testValue)).to.equal(otherTestValue);
        }).should.throwException!TestException.msg;

        msg.split("\n")[0].should.equal(testValue.to!string ~ ` should equal ` ~ otherTestValue.to!string ~ `. ` ~ testValue.to!string ~ ` is not equal to ` ~ otherTestValue.to!string ~ `.`);
      });

      it("should throw an exception with a detailed message when the strings should not be equal", {
        auto msg = ({
          expect(Json(testValue)).to.not.equal(testValue);
        }).should.throwException!TestException.msg;

        msg.split("\n")[0].should.equal(testValue.to!string ~ ` should not equal ` ~ testValue.to!string ~ `. ` ~ testValue.to!string ~ ` is equal to ` ~ testValue.to!string ~ `.`);
      });
    });
  }


  alias FloatTypes = AliasSeq!(float, double, real);

  static foreach(Type; FloatTypes) {
    describe("using " ~ Type.stringof ~ " values", {
      Type testValue;
      Type otherTestValue;

      before({
        testValue = cast(Type) 40;
        otherTestValue = cast(Type) 50;
      });

      it("should be able to compare two exact values", {
        expect(Json(testValue)).to.equal(testValue);
        expect(testValue).to.equal(Json(testValue));
      });

      it("should be able to check if two values are not equal", {
        expect(Json(testValue)).to.not.equal(otherTestValue);
        expect(testValue).to.not.equal(Json(otherTestValue));
      });

      it("should throw an exception with a detailed message when the strings are not equal", {
        auto msg = ({
          expect(Json(testValue)).to.equal(otherTestValue);
        }).should.throwException!TestException.msg;

        msg.split("\n")[0].should.equal(testValue.to!string ~ ` should equal ` ~ otherTestValue.to!string ~ `. ` ~ testValue.to!string ~ ` is not equal to ` ~ otherTestValue.to!string ~ `.`);
      });

      it("should throw an exception with a detailed message when the strings should not be equal", {
        auto msg = ({
          expect(Json(testValue)).to.not.equal(testValue);
        }).should.throwException!TestException.msg;

        msg.split("\n")[0].should.equal(testValue.to!string ~ ` should not equal ` ~ testValue.to!string ~ `. ` ~ testValue.to!string ~ ` is equal to ` ~ testValue.to!string ~ `.`);
      });
    });
  }

  describe("using booleans", {
    it("should compare two true values", {
      expect(Json(true)).to.equal(true);
      expect(true).to.equal(Json(true));
    });

    it("should compare two false values", {
      expect(false).to.equal(false);
    });

    it("should be able to compare that two bools that are not equal", {
      expect(Json(true)).to.not.equal(false);
      expect(true).to.not.equal(Json(false));
    });

    it("should throw a detailed error message when the two bools are not equal", {
      auto msg = ({
        expect(true).to.equal(false);
      }).should.throwException!TestException.msg.split("\n");

      msg[0].strip.should.equal("true should equal false.");
      msg[2].strip.should.equal("Expected:false");
      msg[3].strip.should.equal("Actual:true");
    });
  });

  describe("comparing Json with Json[] arrays", {
    it("should compare a Json array value with a Json[] D array", {
      auto obj = Json.emptyObject;
      obj["key"] = "value";

      Json[] expectedArray = [obj];
      auto jsonArray = Json([obj]);

      expect(jsonArray).to.equal(expectedArray);
    });

    it("should compare a Json array value with a Json[] D array containing complex objects", {
      auto obj1 = Json.emptyObject;
      obj1["_id"] = "000000000000000000000001";
      obj1["name"] = "test";
      obj1["nested"] = Json.emptyObject;
      obj1["nested"]["value"] = 42;

      Json[] expectedArray = [obj1];
      auto jsonArray = Json([obj1]);

      expect(jsonArray).to.equal(expectedArray);
    });

    it("should fail when Json array value does not match Json[] D array", {
      auto obj1 = Json.emptyObject;
      obj1["key"] = "value1";

      auto obj2 = Json.emptyObject;
      obj2["key"] = "value2";

      Json[] expectedArray = [obj2];
      auto jsonArray = Json([obj1]);

      ({
        expect(jsonArray).to.equal(expectedArray);
      }).should.throwException!TestException;
    });

    it("should compare Json[] D array with Json array value", {
      auto obj = Json.emptyObject;
      obj["key"] = "value";

      Json[] dArray = [obj];
      auto jsonArray = Json([obj]);

      expect(dArray).to.equal(jsonArray);
    });

    it("should compare Json array from response with Json[] literal using should syntax", {
      // This mirrors: response.bodyJson["features"].should.equal([ site1 ]);
      auto site1 = Json.emptyObject;
      site1["_id"] = "000000000000000000000001";
      site1["name"] = "site1";

      auto responseJson = Json.emptyObject;
      responseJson["features"] = Json([site1]);

      // This is the exact pattern from the failing test
      responseJson["features"].should.equal([site1]);
    });
  });
});
