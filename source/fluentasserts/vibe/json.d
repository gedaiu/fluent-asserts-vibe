module fluentasserts.vibe.json;

version(Have_vibe_d_data):

import std.exception, std.conv, std.traits;
import std.array, std.algorithm, std.typecons;
import std.uni, std.string, std.math;

import vibe.data.json;
import fluentasserts.core.base;
import fluentasserts.core.results;

import fluentasserts.core.serializers;
import fluentasserts.core.operations.equal;
import fluentasserts.core.operations.arrayEqual;
import fluentasserts.core.operations.contain;
import fluentasserts.core.operations.startWith;
import fluentasserts.core.operations.endWith;
import fluentasserts.core.operations.registry;
import fluentasserts.core.operations.lessThan;
import fluentasserts.core.operations.greaterThan;
import fluentasserts.core.operations.between;
import fluentasserts.core.operations.approximately;

static this() {
  SerializerRegistry.instance.register(&jsonToString);
  Registry.instance.register!(Json, Json[])("equal", &fluentasserts.core.operations.equal.equal);
  Registry.instance.register!(Json[], Json)("equal", &fluentasserts.core.operations.equal.equal);
  Registry.instance.register!(Json[], Json[])("equal", &fluentasserts.core.operations.arrayEqual.arrayEqual);
  Registry.instance.register!(Json[][], Json[][])("equal", &fluentasserts.core.operations.arrayEqual.arrayEqual);
  Registry.instance.register!(Json, Json[][])("equal", &fluentasserts.core.operations.arrayEqual.arrayEqual);

  static foreach(Type; BasicNumericTypes) {
    Registry.instance.register!(Json, Type[])("equal", &fluentasserts.core.operations.equal.equal);
    Registry.instance.register!(Json, Type)("lessThan", &fluentasserts.core.operations.lessThan.lessThan!Type);
    Registry.instance.register!(Json, Type)("greaterThan", &fluentasserts.core.operations.greaterThan.greaterThan!Type);
    Registry.instance.register!(Json, Type)("between", &fluentasserts.core.operations.between.between!Type);
    Registry.instance.register!(Json, Type)("approximately", &fluentasserts.core.operations.approximately.approximately);
  }

  static foreach(Type; StringTypes) {
    Registry.instance.register(extractTypes!(Json[])[0], "void[]", "equal", &arrayEqual);

    Registry.instance.register!(Type[], Json[])("equal", &arrayEqual);

    Registry.instance.register!(Type, Json[])("contain", &contain);
    Registry.instance.register!(Type, Json)("contain", &contain);
    Registry.instance.register!(Type[], Json[])("contain", &arrayContain);
    Registry.instance.register!(Type[], Json[])("containOnly", &arrayContainOnly);

    Registry.instance.register!(Type, Json)("startWith", &startWith);
    Registry.instance.register!(Type, Json)("endWith", &endWith);
  }
}

string jsonToString(Json value) {
  return jsonToString(value, 0);
}

string jsonToString(Json value, size_t level) {

  if(value.type == Json.Type.array) {
    string prefix = rightJustifier(``, level * 2, ' ').array;
    return `[` ~ value.byValue.map!(a => jsonToString(a, level)).join(", ") ~ `]`;
  }

  if(value.type == Json.Type.object) {
    auto keys = value.keys
      .sort
      .filter!(key => value[key].type != Json.Type.null_ && value[key].type != Json.Type.undefined);

    if(keys.empty) {
      return `{}`;
    }

    string prefix = rightJustifier(``, 2 + level * 2, ' ').array;
    string endPrefix = rightJustifier(``, level * 2, ' ').array;

    return "{\n" ~ keys.map!(key => prefix ~ `"` ~ key ~ `": ` ~ value[key].jsonToString(level + 1)).join(",\n") ~ "\n" ~ endPrefix ~ "}";
  }

  if(value.type == Json.Type.null_) {
    return "null";
  }

  if(value.type == Json.Type.undefined) {
    return "undefined";
  }

  if(value.type == Json.Type.string) {
    return `"` ~ value.to!string ~ `"`;
  }

  if(value.type == Json.Type.float_) {
    return format("%.10f", value.to!double).strip("0").strip(".");
  }

  return value.to!string;
}


/// it should convert a double to a string
unittest {
  Json(2.3).jsonToString.should.equal("2.3");
  Json(59.0 / 15.0).jsonToString.should.equal("3.9333333333");
}

/// Get all the keys from your Json object
string[] keys(Json obj, const string file = __FILE__, const size_t line = __LINE__) @trusted {
  string[] list;

  if(obj.type != Json.Type.object) {
    IResult[] results = [ cast(IResult) new MessageResult("Invalid Json type."),
                          cast(IResult) new ExpectedActualResult("object", obj.type.to!string),
                          cast(IResult) new SourceResult(file, line) ];

    throw new TestException(results, file, line);
  }

  static if(typeof(obj.byKeyValue).stringof == "Rng") {
    foreach(string key, Json value; obj.byKeyValue) {
      list ~= key;
    }

    list = list.sort.array;

    return list;
  } else {
    pragma(msg, "Json.keys is not compatible with your vibe.d version");
    assert(false, "Json.keys is not compatible with your vibe.d version");
  }
}

/// Empty Json object keys
unittest {
  Json.emptyObject.keys.length.should.equal(0);
}

/// Json object keys
unittest {
  auto obj = Json.emptyObject;
  obj["key1"] = 1;
  obj["key2"] = 3;

  obj.keys.should.containOnly(["key1", "key2"]);
}

/// Json array keys
unittest {
  auto obj = Json.emptyArray;

  ({
    obj.keys.should.contain(["key1", "key2"]);
  }).should.throwAnyException.msg.should.startWith("Invalid Json type.");
}

/// Get all the keys from your Json object. The levels will be separated by `.` or `[]`
string[] nestedKeys(Json obj) @trusted {
  return obj.flatten.byKeyValue.map!"a.key".array;
}

/// Empty Json object keys
unittest {
  Json.emptyObject.nestedKeys.length.should.equal(0);
}

/// Get all keys from nested object
unittest {
  auto obj = Json.emptyObject;
  obj["key1"] = 1;
  obj["key2"] = 2;
  obj["key3"] = Json.emptyObject;
  obj["key3"]["item1"] = "3";
  obj["key3"]["item2"] = Json.emptyObject;
  obj["key3"]["item2"]["item4"] = Json.emptyObject;
  obj["key3"]["item2"]["item5"] = Json.emptyObject;
  obj["key3"]["item2"]["item5"]["item6"] = Json.emptyObject;

  obj.nestedKeys.should.containOnly(["key1", "key2", "key3.item1", "key3.item2.item4", "key3.item2.item5.item6"]);
}

/// Get all keys from nested objects inside an array
unittest {
  auto obj = Json.emptyObject;
  Json elm = Json.emptyObject;
  elm["item5"] = Json.emptyObject;
  elm["item5"]["item6"] = Json.emptyObject;

  obj["key2"] = Json.emptyArray;
  obj["key3"] = Json.emptyArray;
  obj["key3"] ~= Json("3");
  obj["key3"] ~= Json.emptyObject;
  obj["key3"] ~= elm;
  obj["key3"] ~= [ Json.emptyArray ];

  obj.nestedKeys.should.containOnly(["key2", "key3[0]", "key3[1]", "key3[2].item5.item6", "key3[3]"]);
}

/// Takes a nested Json object and moves the values to a Json assoc array where the key
/// is the path from the original object to that value
Json[string] flatten(Json object) @trusted {
  Json[string] elements;

  auto root = tuple("", object);
  Tuple!(string, Json)[] queue = [ root ];

  while(queue.length > 0) {
    auto element = queue[0];

    if(element[0] != "") {
      if(element[1].type != Json.Type.object && element[1].type != Json.Type.array) {
        elements[element[0]] = element[1];
      }

      if(element[1].type == Json.Type.object && element[1].length == 0) {
        elements[element[0]] = element[1];
      }

      if(element[1].type == Json.Type.array && element[1].length == 0) {
        elements[element[0]] = element[1];
      }
    }

    if(element[1].type == Json.Type.object) {
      foreach(string key, value; element[1].byKeyValue) {
        string nextKey = key;

        if(element[0] != "") {
          nextKey = element[0] ~ "." ~ nextKey;
        }

        queue ~= tuple(nextKey, value);
      }
    }

    if(element[1].type == Json.Type.array) {
      size_t index;

      foreach(value; element[1].byValue) {
        string nextKey = element[0] ~ "[" ~ index.to!string ~ "]";

        queue ~= tuple(nextKey, value);
        index++;
      }
    }

    queue = queue[1..$];
  }

  return elements;
}

/// Get a flatten object
unittest {
  auto obj = Json.emptyObject;
  obj["key1"] = 1;
  obj["key2"] = 2;
  obj["key3"] = Json.emptyObject;
  obj["key3"]["item1"] = "3";
  obj["key3"]["item2"] = Json.emptyObject;
  obj["key3"]["item2"]["item4"] = Json.emptyObject;
  obj["key3"]["item2"]["item5"] = Json.emptyObject;
  obj["key3"]["item2"]["item5"]["item6"] = Json.emptyObject;

  auto result = obj.flatten;
  result.byKeyValue.map!(a => a.key).should.containOnly(["key1", "key2", "key3.item1", "key3.item2.item4", "key3.item2.item5.item6"]);
  result["key1"].should.equal(1);
  result["key2"].should.equal(2);
  result["key3.item1"].should.equal("3");
  result["key3.item2.item4"].should.equal(Json.emptyObject);
  result["key3.item2.item5.item6"].should.equal(Json.emptyObject);
}

auto unpackJsonArray(T : U[], U)(Json data) if(!isArray!U && isBasicType!U) {
  return data.byValue.map!(a => a.to!U).array.dup;
}

auto unpackJsonArray(T : U[], U)(Json data) if(!isArray!U && is(Unqual!U == Json)) {
  U[] result;

  foreach(element; data.byValue) {
    result ~= element;
  }

  return result;
}

auto unpackJsonArray(T : U[], U)(Json data) if(isArray!(U) && !isSomeString!(U[])) {
  U[] result;

  foreach(element; data.byValue) {
    result ~= unpackJsonArray!(U)(element);
  }

  return result;
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
  auto msg = ({
    Json.emptyObject.should.equal(Json.emptyArray);
  }).should.throwException!TestException.msg;

  msg.split("\n")[0].strip.should.equal(`Json.emptyObject should equal []. {} is not equal to [].`);
  msg.split("\n")[2].strip.should.equal(`[-[]][+{}]`);
  msg.split("\n")[4].strip.should.equal("Expected:[]");
  msg.split("\n")[5].strip.should.equal("Actual:{}");

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

  auto msg = ({
    Json("test string").should.equal("test");
  }).should.throwException!TestException.msg;

  msg.split("\n")[0].should.equal(`Json("test string") should equal "test". "test string" is not equal to "test".`);
}

/// It throw on comparing a Json number with a string
unittest {
  auto msg = ({
    Json(4).should.equal("some string");
  }).should.throwException!TestException.msg;

  msg.split("\n")[0].strip.should.equal(`Json(4) should equal "some string". 4 is not equal to "some string".`);
  msg.split("\n")[2].strip.should.equal(`[-"some string"][+4]`);
  msg.split("\n")[4].strip.should.equal(`Expected:"some string"`);
  msg.split("\n")[5].strip.should.equal(`Actual:4`);
}

/// It throws when you compare a Json string with integer values
unittest {
  auto msg = ({
    byte val = 4;
    Json("some string").should.equal(val);
  }).should.throwException!TestException.msg;

  msg.split("\n")[0].strip.should.equal(`Json("some string") should equal 4. "some string" is not equal to 4.`);
  msg.split("\n")[2].strip.should.equal(`[-4][+"some string"]`);
  msg.split("\n")[4].strip.should.equal("Expected:4");
  msg.split("\n")[5].strip.should.equal(`Actual:"some string"`);

  msg = ({
    short val = 4;
    Json("some string").should.equal(val);
  }).should.throwException!TestException.msg;

  msg.split("\n")[0].strip.should.equal(`Json("some string") should equal 4. "some string" is not equal to 4.`);

  msg = ({
    int val = 4;
    Json("some string").should.equal(val);
  }).should.throwException!TestException.msg;

  msg.split("\n")[0].strip.should.equal(`Json("some string") should equal 4. "some string" is not equal to 4.`);

  msg = ({
    long val = 4;
    Json("some string").should.equal(val);
  }).should.throwException!TestException.msg;

  msg.split("\n")[0].strip.should.equal(`Json("some string") should equal 4. "some string" is not equal to 4.`);
}

/// It throws when you compare a Json string with unsigned integer values
unittest {
  auto msg = ({
    ubyte val = 4;
    Json("some string").should.equal(val);
  }).should.throwException!TestException.msg;

  msg.split("\n")[0].strip.should.equal(`Json("some string") should equal 4. "some string" is not equal to 4.`);

  msg = ({
    ushort val = 4;
    Json("some string").should.equal(val);
  }).should.throwException!TestException.msg;

  msg.split("\n")[0].strip.should.equal(`Json("some string") should equal 4. "some string" is not equal to 4.`);

  msg = ({
    uint val = 4;
    Json("some string").should.equal(val);
  }).should.throwException!TestException.msg;

  msg.split("\n")[0].strip.should.equal(`Json("some string") should equal 4. "some string" is not equal to 4.`);

  msg = ({
    ulong val = 4;
    Json("some string").should.equal(val);
  }).should.throwException!TestException.msg;

  msg.split("\n")[0].strip.should.equal(`Json("some string") should equal 4. "some string" is not equal to 4.`);
}

/// It throws when you compare a Json string with floating point values
unittest {
  auto msg = ({
    float val = 3.14;
    Json("some string").should.equal(val);
  }).should.throwException!TestException.msg;

  msg.split("\n")[0].strip.should.equal(`Json("some string") should equal 3.14. "some string" is not equal to 3.14.`);
  msg.split("\n")[2].strip.should.equal(`[-3.14][+"some string"]`);
  msg.split("\n")[4].strip.should.equal("Expected:3.14");
  msg.split("\n")[5].strip.should.equal(`Actual:"some string"`);

  msg = ({
    double val = 3.14;
    Json("some string").should.equal(val);
  }).should.throwException!TestException.msg;

  msg.split("\n")[0].strip.should.equal(`Json("some string") should equal 3.14. "some string" is not equal to 3.14.`);
}

/// It throws when you compare a Json string with bool values
unittest {
  auto msg = ({
    Json("some string").should.equal(false);
  }).should.throwException!TestException.msg;

  msg.split("\n")[0].strip.should.equal(`Json("some string") should equal false. "some string" is not equal to false.`);
}

/// It should be able to compare two integers
unittest {
  Json(4L).should.equal(4f);
  Json(4).should.equal(4);
  Json(4).should.not.equal(5);

  Json(4).should.equal(Json(4));
  Json(4).should.not.equal(Json(5));
  Json(4L).should.not.equal(Json(5f));

  auto msg = ({
    Json(4).should.equal(5);
  }).should.throwException!TestException.msg;

  msg.split("\n")[0].should.equal(`Json(4) should equal 5. 4 is not equal to 5.`);

  msg = ({
    Json(4).should.equal(Json(5));
  }).should.throwException!TestException.msg;

  msg.split("\n")[0].should.equal(`Json(4) should equal 5. 4 is not equal to 5.`);
}

/// It throws on comparing an integer Json with a string
unittest {
  auto msg = ({
    Json(4).should.equal("5");
  }).should.throwException!TestException.msg;

  msg.split("\n")[0].should.equal(`Json(4) should equal "5". 4 is not equal to "5".`);

  msg = ({
    Json(4).should.equal(Json("5"));
  }).should.throwException!TestException.msg;

  msg.split("\n")[0].should.equal(`Json(4) should equal "5". 4 is not equal to "5".`);
}

/// It should be able to compare two floating point numbers
unittest {
  Json(4f).should.equal(4L);
  Json(4.3).should.equal(4.3);
  Json(4.3).should.not.equal(5.3);

  Json(4.3).should.equal(Json(4.3));
  Json(4.3).should.not.equal(Json(5.3));

  auto msg = ({
    Json(4.3).should.equal(5.3);
  }).should.throwException!TestException.msg;

  msg.split("\n")[0].should.equal("Json(4.3) should equal 5.3. 4.3 is not equal to 5.3.");

  msg = ({
    Json(4.3).should.equal(Json(5.3));
  }).should.throwException!TestException.msg;

  msg.split("\n")[0].should.equal("Json(4.3) should equal 5.3. 4.3 is not equal to 5.3.");
}

/// It throws on comparing an floating point Json with a string
unittest {
  auto msg = ({
    Json(4f).should.equal("5");
  }).should.throwException!TestException.msg;

  msg.split("\n")[0].should.equal(`Json(4f) should equal "5". 4 is not equal to "5".`);

  msg = ({
    Json(4f).should.equal(Json("5"));
  }).should.throwException!TestException.msg;

  msg.split("\n")[0].should.equal(`Json(4f) should equal "5". 4 is not equal to "5".`);
}

/// It should be able to compare two booleans
unittest {
  Json(true).should.equal(true);
  Json(true).should.not.equal(false);

  Json(true).should.equal(Json(true));
  Json(true).should.not.equal(Json(false));

  auto msg = ({
    Json(true).should.equal(false);
  }).should.throwException!TestException.msg;

  msg.split("\n")[0].should.equal("Json(true) should equal false. true is not equal to false.");

  msg = ({
    Json(true).should.equal(Json(false));
  }).should.throwException!TestException.msg;

  msg.split("\n")[0].should.equal("Json(true) should equal false. true is not equal to false.");
}

/// It throws on comparing a bool Json with a string
unittest {
  auto msg = ({
    Json(true).should.equal("5");
  }).should.throwException!TestException.msg;

  msg.split("\n")[0].should.equal(`Json(true) should equal "5". true is not equal to "5".`);

  msg = ({
    Json(true).should.equal(Json("5"));
  }).should.throwException!TestException.msg;

  msg.split("\n")[0].should.equal(`Json(true) should equal "5". true is not equal to "5".`);
  msg.split("\n")[2].should.equal(`[-"5"][+true]`);
  msg.split("\n")[4].should.equal(` Expected:"5"`);
  msg.split("\n")[5].should.equal(`   Actual:true`);
}

/// It should be able to compare two arrays
unittest {
  Json[] elements = [Json(1), Json(2)];
  Json[] otherElements = [Json(1), Json(2), Json(3)];

  Json(elements).should.equal([1, 2]);
  Json(elements).should.not.equal([1, 2, 3]);

  Json(elements).should.equal(Json(elements));
  Json(elements).should.not.equal(Json(otherElements));

  auto msg = ({
    Json(elements).should.equal(otherElements);
  }).should.throwException!TestException.msg;

  msg.split("\n")[0].should.equal("Json(elements) should equal [1, 2, 3]. [1, 2] is not equal to [1, 2, 3].");

  msg = ({
    Json(elements).should.equal(otherElements);
  }).should.throwException!TestException.msg;

  msg.split("\n")[0].should.equal("Json(elements) should equal [1, 2, 3]. [1, 2] is not equal to [1, 2, 3].");
}

/// It throws on comparing a Json array with a string
unittest {
  Json[] elements = [Json(1), Json(2)];
  auto msg = ({
    Json(elements).should.equal("5");
  }).should.throwException!TestException.msg;

  msg.split("\n")[0].should.equal(`Json(elements) should equal "5". [1, 2] is not equal to "5".`);

  msg = ({
    Json(elements).should.equal(Json("5"));
  }).should.throwException!TestException.msg;

  msg.split("\n")[0].should.equal(`Json(elements) should equal "5". [1, 2] is not equal to "5".`);
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

  auto msg = ({
    Json(elements).should.equal(otherElements);
  }).should.throwException!TestException.msg;

  msg.split("\n")[0].should.equal("Json(elements) should equal [[1, 2], [10, 20], [1, 2]]. [[1, 2], [10, 20]] is not equal to [[1, 2], [10, 20], [1, 2]].");

  msg = ({
    Json(elements).should.equal(Json(otherElements));
  }).should.throwException!TestException.msg;

  msg.split("\n")[0].should.equal("Json(elements) should equal [[1, 2], [10, 20], [1, 2]]. [[1, 2], [10, 20]] is not equal to [[1, 2], [10, 20], [1, 2]].");
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

  auto msg = ({
    Json(elements).should.equal(otherElements);
  }).should.throwException!TestException.msg;

  msg.split("\n")[0].should.equal("Json(elements) should equal [[1, 2], 1, [1, 2]]. [[1, 2], 1] is not equal to [[1, 2], 1, [1, 2]].");

  msg = ({
    Json(elements).should.equal(Json(otherElements));
  }).should.throwException!TestException.msg;

  msg.split("\n")[0].should.equal("Json(elements) should equal [[1, 2], 1, [1, 2]]. [[1, 2], 1] is not equal to [[1, 2], 1, [1, 2]].");
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

  msg.should.startWith(`testObject should equal {`);
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

  msg.should.startWith("testObject should equal {");
}

/// greaterThan support for Json Objects
unittest {
  Json(5).should.be.greaterThan(4);
  Json(4).should.not.be.greaterThan(5);

  Json(5f).should.be.greaterThan(4f);
  Json(4f).should.not.be.greaterThan(5f);

  auto msg = ({
    Json("").should.greaterThan(3);
  }).should.throwException!TestException.msg;

  msg.split("\n")[0].should.equal(`Json("") should greater than 3.`);
  msg.split("\n")[1].should.equal("Can't convert the values to int");

  msg = ({
    Json(false).should.greaterThan(3f);
  }).should.throwException!TestException.msg;

  msg.split("\n")[0].should.equal(`Json(false) should greater than 3.`);
  msg.split("\n")[1].should.equal("Can't convert the values to float");
}

/// lessThan support for Json Objects
unittest {
  Json(4).should.be.lessThan(5);
  Json(5).should.not.be.lessThan(4);

  Json(4f).should.be.lessThan(5f);
  Json(5f).should.not.be.lessThan(4f);

  auto msg = ({
    Json("").should.lessThan(3);
  }).should.throwException!TestException.msg;

  msg.split("\n")[0].should.equal(`Json("") should less than 3.`);
  msg.split("\n")[1].should.equal(`Can't convert the values to int`);

  msg = ({
    Json(false).should.lessThan(3f);
  }).should.throwException!TestException.msg;

  msg.split("\n")[0].should.equal(`Json(false) should less than 3.`);
  msg.split("\n")[1].should.equal(`Can't convert the values to float`);
}

/// between support for Json Objects
unittest {
  Json(5).should.be.between(6, 4);
  Json(5).should.not.be.between(5, 6);

  Json(5f).should.be.between(6f, 4f);
  Json(5f).should.not.be.between(5f, 6f);

  auto msg = ({
    Json(true).should.be.between(6f, 4f);
  }).should.throwException!TestException.msg;

  msg.split("\n")[0].should.equal("Json(true) should be between 6 and 4. ");
  msg.split("\n")[1].should.equal("Can't convert the values to float");
}

/// should be able to use approximately for jsons
unittest {
  Json(10f/3f).should.be.approximately(3, 0.34);
  Json(10f/3f).should.not.be.approximately(3, 0.24);

  auto msg = ({
    Json("").should.be.approximately(3, 0.34);
  }).should.throwException!TestException.msg;

  msg.should.contain(`Can't parse the provided arguments!`);
}
