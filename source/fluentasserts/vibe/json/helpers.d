module fluentasserts.vibe.json.helpers;

version (Have_vibe_serialization):

import std.algorithm : map, sort;
import std.array : array;
import std.conv : to;
import std.traits : isArray, isBasicType, isSomeString, Unqual;
import std.typecons : tuple, Tuple;

import vibe.data.json;

import fluentasserts.core.base;
import fluentasserts.core.evaluation.eval : Evaluation;
import fluentasserts.results.source.result : SourceResult;

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
