module fluentasserts.vibe.json.serializer;

version (Have_vibe_serialization):

import std.algorithm : filter, map, sort;
import std.array : Appender, array;
import std.conv : to;
import std.format : sformat;

import vibe.data.json;

import fluentasserts.core.memory.heapstring : HeapString, toHeapString;

HeapString jsonToHeapString(Json value) @trusted {
  return toHeapString(jsonToString(value));
}

HeapString jsonArrayToHeapString(Json[] values) @trusted {
  return toHeapString(jsonToString(Json(values)));
}

/// it serializes an array to the same string as jsonArrayToHeapString
unittest {
  import fluentasserts.core.base;

  auto jsonList = Json([Json(1), Json(2), Json(3)]);
  auto dList = [Json(1), Json(2), Json(3)];

  jsonList.jsonToHeapString.should.equal(dList.jsonArrayToHeapString);
}

string jsonToString(Json value) {
  Appender!string result;
  result.reserve(256);
  jsonToStringImpl(value, 0, result);
  return result[];
}

// Pre-computed indentation strings for levels 0-16
private immutable string[] indentCache = [
  "",
  "  ",
  "    ",
  "      ",
  "        ",
  "          ",
  "            ",
  "              ",
  "                ",
  "                  ",
  "                    ",
  "                      ",
  "                        ",
  "                          ",
  "                            ",
  "                              ",
  "                                ",
];

private string getIndent(size_t level) pure nothrow @safe {
  if (level < indentCache.length) {
    return indentCache[level];
  }
  // Fallback for deeply nested JSON (rare)
  char[] result = new char[level * 2];
  result[] = ' ';
  return (() @trusted => cast(string)result)();
}

private void jsonToStringImpl(Json value, size_t level, ref Appender!string result) {
  if (value.type == Json.Type.array) {
    if (value.length == 0) {
      result ~= "[]";
      return;
    }

    immutable prefix = getIndent(level + 1);
    immutable endPrefix = getIndent(level);

    result ~= "[\n";
    bool first = true;
    foreach (element; value.byValue) {
      if (!first) {
        result ~= ",\n";
      }
      first = false;
      result ~= prefix;
      jsonToStringImpl(element, level + 1, result);
    }
    result ~= "\n";
    result ~= endPrefix;
    result ~= "]";
    return;
  }

  if (value.type == Json.Type.object) {
    // Collect and sort keys, filtering null/undefined
    string[] sortedKeys;
    foreach (kv; value.byKeyValue) {
      if (kv.value.type != Json.Type.null_ && kv.value.type != Json.Type.undefined) {
        sortedKeys ~= kv.key;
      }
    }

    if (sortedKeys.length == 0) {
      result ~= "{}";
      return;
    }

    sortedKeys.sort();

    immutable prefix = getIndent(level + 1);
    immutable endPrefix = getIndent(level);

    result ~= "{\n";
    bool first = true;
    foreach (key; sortedKeys) {
      if (!first) {
        result ~= ",\n";
      }
      first = false;
      result ~= prefix;
      result ~= `"`;
      result ~= key;
      result ~= `": `;
      jsonToStringImpl(value[key], level + 1, result);
    }
    result ~= "\n";
    result ~= endPrefix;
    result ~= "}";
    return;
  }

  if (value.type == Json.Type.null_) {
    result ~= "null";
    return;
  }

  if (value.type == Json.Type.undefined) {
    result ~= "undefined";
    return;
  }

  if (value.type == Json.Type.string && level == 0) {
    result ~= value.to!string;
    return;
  }

  if (value.type == Json.Type.string && level > 0) {
    result ~= `"`;
    result ~= value.to!string;
    result ~= `"`;
    return;
  }

  if (value.type == Json.Type.float_) {
    result ~= formatFloat(value.to!double);
    return;
  }

  result ~= value.to!string;
}

// Efficient float formatting without trailing zeros
private string formatFloat(double value) {
  char[32] buf;
  auto formatted = sformat(buf[], "%.10f", value);

  // Strip trailing zeros and decimal point
  size_t end = formatted.length;
  while (end > 0 && formatted[end - 1] == '0') {
    end--;
  }
  if (end > 0 && formatted[end - 1] == '.') {
    end--;
  }

  return formatted[0 .. end].idup;
}

/// it does not serialize undefined properties
unittest {
  import fluentasserts.core.base;

  auto obj = `{ "a": 1 }`.parseJsonString;

  obj.remove("a");

  obj.jsonToString.should.equal(`{}`);
}

/// it does not serialize null properties
unittest {
  import fluentasserts.core.base;

  auto obj = Json.emptyObject;

  obj["a"] = Json(null);

  obj.jsonToString.should.equal(`{}`);
}

/// it should convert a double to a string
unittest {
  import fluentasserts.core.base;

  Json(2.3).jsonToString.should.equal("2.3");
  Json(59.0 / 15.0).jsonToString.should.equal("3.9333333333");
}

/// serializes object with sorted keys and 2-space indentation
unittest {
  import fluentasserts.core.base;

  auto obj = Json.emptyObject;
  obj["zebra"] = 1;
  obj["apple"] = 2;
  obj["mango"] = 3;

  obj.jsonToString.should.equal("{\n  \"apple\": 2,\n  \"mango\": 3,\n  \"zebra\": 1\n}");
}

/// serializes nested objects with proper indentation
unittest {
  import fluentasserts.core.base;

  auto obj = Json.emptyObject;
  obj["outer"] = Json.emptyObject;
  obj["outer"]["inner"] = "value";

  obj.jsonToString.should.equal("{\n  \"outer\": {\n    \"inner\": \"value\"\n  }\n}");
}

/// serializes arrays with proper indentation
unittest {
  import fluentasserts.core.base;

  auto arr = Json([Json(1), Json(2), Json(3)]);

  arr.jsonToString.should.equal("[\n  1,\n  2,\n  3\n]");
}

/// serializes empty array
unittest {
  import fluentasserts.core.base;

  Json.emptyArray.jsonToString.should.equal("[]");
}

/// serializes object with string keys and string values
unittest {
  import fluentasserts.core.base;

  auto obj = Json.emptyObject;
  obj["name"] = "John";
  obj["city"] = "Berlin";

  obj.jsonToString.should.equal("{\n  \"city\": \"Berlin\",\n  \"name\": \"John\"\n}");
}
