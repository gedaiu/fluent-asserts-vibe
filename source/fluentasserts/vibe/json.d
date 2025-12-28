module fluentasserts.vibe.json;

version (Have_vibe_d_data):

import std.exception, std.conv, std.traits;
import std.array, std.algorithm, std.typecons;
import std.uni, std.string, std.math;

import vibe.data.json;

import fluentasserts.core.base;
import fluentasserts.core.evaluation.eval : Evaluation;
import fluentasserts.core.memory.heapstring : HeapString, toHeapString;
import fluentasserts.results.serializers.heap_registry : HeapSerializerRegistry;
import fluentasserts.results.source.result : SourceResult;

static this() {
  HeapSerializerRegistry.instance.register!Json(&jsonToHeapString);
}

HeapString jsonToHeapString(Json value) @trusted {
  return toHeapString(jsonToString(value));
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

/// it does not serialize undefined properties
unittest {
  auto obj = `{ "a": 1 }`.parseJsonString;

  obj.remove("a");

  obj.jsonToString.should.equal(`{}`);
}

/// it does not serialize null properties
unittest {
  auto obj = Json.emptyObject;

  obj["a"] = Json(null);

  obj.jsonToString.should.equal(`{}`);
}

/// it should convert a double to a string
unittest {
  Json(2.3).jsonToString.should.equal("2.3");
  Json(59.0 / 15.0).jsonToString.should.equal("3.9333333333");
}

/// Get all the keys from your Json object
string[] keys(Json obj, const string file = __FILE__, const size_t line = __LINE__) @trusted {
  string[] list;

  if (obj.type != Json.Type.object) {
    Evaluation evaluation;
    evaluation.isEvaluated = true;
    evaluation.source = SourceResult.create(file, line);
    evaluation.result.addText("Invalid Json type.");
    evaluation.result.expected.put("object");
    evaluation.result.actual.put(obj.type.to!string);

    throw new TestException(evaluation);
  }

  static if (typeof(obj.byKeyValue).stringof == "Rng") {
    foreach (string key, Json value; obj.byKeyValue) {
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
  }).should.throwAnyException.msg.should.contain("Invalid Json type.");
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
        if(value.type == Json.Type.null_ || value.type == Json.Type.undefined) {
          continue;
        }

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

/// it ignores the null values
unittest {
  auto obj = Json.emptyObject;
  obj["key1"] = Json(null);

  auto result = obj.flatten;
  result.byKeyValue.map!(a => a.key).should.containOnly([]);
}

/// it ignores the undefined values
unittest {
  auto obj = Json.emptyObject;
  obj["key1"] = Json();

  auto result = obj.flatten;
  result.byKeyValue.map!(a => a.key).should.containOnly([]);
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
