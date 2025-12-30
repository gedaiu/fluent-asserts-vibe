module fluentasserts.vibe.json;

version (Have_vibe_serialization):

public import fluentasserts.vibe.json.helpers;
public import fluentasserts.vibe.json.operations;
public import fluentasserts.vibe.json.serializer;

import vibe.data.json;

import fluentasserts.core.base;
import fluentasserts.operations.registry : Registry;
import fluentasserts.results.serializers.heap_registry : HeapSerializerRegistry;

static this() {
  HeapSerializerRegistry.instance.register!Json(&jsonToHeapString);
  HeapSerializerRegistry.instance.register!(Json[])(&jsonArrayToHeapString);

  Registry.instance.register!(Json, Json)("equal", &jsonEqual);
  Registry.instance.register!(Json, Json[])("equal", &jsonEqual);
  Registry.instance.register!(Json[], Json)("equal", &jsonEqual);
  Registry.instance.register!(Json, string)("equal", &jsonEqual);
  Registry.instance.register!(string, Json)("equal", &jsonEqual);
  Registry.instance.register!(Json, immutable(char)[])("equal", &jsonEqual);
  Registry.instance.register!(immutable(char)[], Json)("equal", &jsonEqual);
}

version(unittest) {
  import std.string;
}

/// Two sepparate json objects are equal
unittest {
  Json.emptyObject.should.equal(Json.emptyObject);
}

/// An json object with an undefined value is iqual to an empty object json with no values
unittest {
  auto value = Json.emptyObject;
  value["key"] = Json();

  value.should.equal(Json.emptyObject);
}

/// It should be able to compare an empty object with an empty array
unittest {
  ({
    Json.emptyObject.should.equal(Json.emptyArray);
  }).should.throwException!TestException;

  ({
    Json.emptyObject.should.not.equal(Json.emptyArray);
  }).should.not.throwException!TestException;
}

/// It should be able to compare two strings
unittest {
  ({
    Json("test string").should.equal("test string");
    Json("other string").should.not.equal("test");
  }).should.not.throwAnyException;

  ({
    Json("test string").should.equal(Json("test string"));
    Json("other string").should.not.equal(Json("test"));
  }).should.not.throwAnyException;

  ({
    Json("test string").should.equal("test");
  }).should.throwException!TestException;
}

/// It throw on comparing a Json number with a string
unittest {
  ({
    Json(4).should.equal("some string");
  }).should.throwException!TestException;
}

/// It throws when you compare a Json string with integer values
unittest {
  ({
    byte val = 4;
    Json("some string").should.equal(val);
  }).should.throwException!TestException;

  ({
    short val = 4;
    Json("some string").should.equal(val);
  }).should.throwException!TestException;

  ({
    int val = 4;
    Json("some string").should.equal(val);
  }).should.throwException!TestException;

  ({
    long val = 4;
    Json("some string").should.equal(val);
  }).should.throwException!TestException;
}

/// It throws when you compare a Json string with unsigned integer values
unittest {
  ({
    ubyte val = 4;
    Json("some string").should.equal(val);
  }).should.throwException!TestException;

  ({
    ushort val = 4;
    Json("some string").should.equal(val);
  }).should.throwException!TestException;

  ({
    uint val = 4;
    Json("some string").should.equal(val);
  }).should.throwException!TestException;

  ({
    ulong val = 4;
    Json("some string").should.equal(val);
  }).should.throwException!TestException;
}

/// It throws when you compare a Json string with floating point values
unittest {
  ({
    float val = 3.14;
    Json("some string").should.equal(val);
  }).should.throwException!TestException;

  ({
    double val = 3.14;
    Json("some string").should.equal(val);
  }).should.throwException!TestException;
}

/// It throws when you compare a Json string with bool values
unittest {
  ({
    Json("some string").should.equal(false);
  }).should.throwException!TestException;
}

/// It should be able to compare two integers
unittest {
  Json(4L).should.equal(4f);
  Json(4).should.equal(4);
  Json(4).should.not.equal(5);

  Json(4).should.equal(Json(4));
  Json(4).should.not.equal(Json(5));
  Json(4L).should.not.equal(Json(5f));

  ({
    Json(4).should.equal(5);
  }).should.throwException!TestException;

  ({
    Json(4).should.equal(Json(5));
  }).should.throwException!TestException;
}

/// It throws on comparing an integer Json with a string
unittest {
  ({
    Json(4).should.equal("5");
  }).should.throwException!TestException;

  ({
    Json(4).should.equal(Json("5"));
  }).should.throwException!TestException;
}

/// It should be able to compare two floating point numbers
unittest {
  Json(4f).should.equal(4L);
  Json(4.3).should.equal(4.3);
  Json(4.3).should.not.equal(5.3);

  Json(4.3).should.equal(Json(4.3));
  Json(4.3).should.not.equal(Json(5.3));

  ({
    Json(4.3).should.equal(5.3);
  }).should.throwException!TestException;

  ({
    Json(4.3).should.equal(Json(5.3));
  }).should.throwException!TestException;
}

/// It throws on comparing an floating point Json with a string
unittest {
  ({
    Json(4f).should.equal("5");
  }).should.throwException!TestException;

  ({
    Json(4f).should.equal(Json("5"));
  }).should.throwException!TestException;
}

/// It should be able to compare two booleans
unittest {
  Json(true).should.equal(true);
  Json(true).should.not.equal(false);

  Json(true).should.equal(Json(true));
  Json(true).should.not.equal(Json(false));

  ({
    Json(true).should.equal(false);
  }).should.throwException!TestException;

  ({
    Json(true).should.equal(Json(false));
  }).should.throwException!TestException;
}

/// It throws on comparing a bool Json with a string
unittest {
  ({
    Json(true).should.equal("5");
  }).should.throwException!TestException;

  ({
    Json(true).should.equal(Json("5"));
  }).should.throwException!TestException;
}

/// It should be able to compare two arrays
unittest {
  Json[] elements = [Json(1), Json(2)];
  Json[] otherElements = [Json(1), Json(2), Json(3)];

  Json(elements).should.equal([1, 2]);
  Json(elements).should.not.equal([1, 2, 3]);

  Json(elements).should.equal(Json(elements));
  Json(elements).should.not.equal(Json(otherElements));

  ({
    Json(elements).should.equal(otherElements);
  }).should.throwException!TestException;
}

/// It throws on comparing a Json array with a string
unittest {
  Json[] elements = [Json(1), Json(2)];

  ({
    Json(elements).should.equal("5");
  }).should.throwException!TestException;

  ({
    Json(elements).should.equal(Json("5"));
  }).should.throwException!TestException;
}

/// It should be able to compare two nested arrays
unittest {
  Json[] element1 = [Json(1), Json(2)];
  Json[] element2 = [Json(10), Json(20)];

  Json[] elements = [Json(element1), Json(element2)];
  Json[] otherElements = [Json(element1), Json(element2), Json(element1)];

  Json(elements).should.equal([element1, element2]);
  Json(elements).should.not.equal([element1, element2, element1]);

  Json(elements).should.equal(Json(elements));
  Json(elements).should.not.equal(Json(otherElements));

  ({
    Json(elements).should.equal(otherElements);
  }).should.throwException!TestException;

  ({
    Json(elements).should.equal(Json(otherElements));
  }).should.throwException!TestException;
}

/// It should be able to compare two nested arrays with different levels
unittest {
  Json nestedElement = Json([Json(1), Json(2)]);

  Json[] elements = [nestedElement, Json(1)];
  Json[] otherElements = [nestedElement, Json(1), nestedElement];

  Json(elements).should.equal([nestedElement, Json(1)]);
  Json(elements).should.not.equal([nestedElement, Json(1), nestedElement]);

  Json(elements).should.equal(Json(elements));
  Json(elements).should.not.equal(Json(otherElements));

  ({
    Json(elements).should.equal(otherElements);
  }).should.throwException!TestException;

  ({
    Json(elements).should.equal(Json(otherElements));
  }).should.throwException!TestException;
}

/// It should find the key differences inside a Json object
unittest {
  Json expectedObject = Json.emptyObject;
  Json testObject = Json.emptyObject;
  testObject["key"] = "some value";
  testObject["nested"] = Json.emptyObject;
  testObject["nested"]["item1"] = "hello";
  testObject["nested"]["item2"] = Json.emptyObject;
  testObject["nested"]["item2"]["value"] = "world";

  expectedObject["other"] = "other value";

  auto msg = ({
    testObject.should.equal(expectedObject);
  }).should.throwException!TestException.msg;

  msg.should.contain(`testObject should equal {`);
}

/// It should find the value differences inside a Json object
unittest {
  Json expectedObject = Json.emptyObject;
  Json testObject = Json.emptyObject;
  testObject["key1"] = "some value";
  testObject["key2"] = 1;

  expectedObject["key1"] = "other value";
  expectedObject["key2"] = 2;

  auto msg = ({
    testObject.should.equal(expectedObject);
  }).should.throwException!TestException.msg;

  msg.should.contain("testObject should equal {");
}

/// greaterThan support for Json Objects
unittest {
  Json(5).should.be.greaterThan(4);
  Json(4).should.not.be.greaterThan(5);

  Json(5f).should.be.greaterThan(4f);
  Json(4f).should.not.be.greaterThan(5f);
}

/// lessThan support for Json Objects
unittest {
  Json(4).should.be.lessThan(5);
  Json(5).should.not.be.lessThan(4);

  Json(4f).should.be.lessThan(5f);
  Json(5f).should.not.be.lessThan(4f);
}

/// between support for Json Objects
unittest {
  Json(5).should.be.between(6, 4);
  Json(5).should.not.be.between(5, 6);

  Json(5f).should.be.between(6f, 4f);
  Json(5f).should.not.be.between(5f, 6f);
}

/// should be able to use approximately for jsons
unittest {
  Json(10f/3f).should.be.approximately(3, 0.34);
  Json(10f/3f).should.not.be.approximately(3, 0.24);
}
