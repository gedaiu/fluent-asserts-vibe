module fluentasserts.vibe.json.serializer;

version (Have_vibe_serialization):

import std.algorithm : filter, map, sort;
import std.array : array;
import std.conv : to;

import vibe.data.json;

import fluentasserts.core.memory.heapstring : HeapString, toHeapString;
import fluentasserts.core.conversion.toheapstring : toFloatingString;

HeapString jsonToHeapString(Json value) @trusted {
  return jsonToString(value);
}

HeapString jsonArrayToHeapString(Json[] values) @trusted {
  return jsonToString(Json(values));
}

/// it serializes an array to the same string as jsonArrayToHeapString
unittest {
  import fluentasserts.core.base;

  auto jsonList = Json([Json(1), Json(2), Json(3)]);
  auto dList = [Json(1), Json(2), Json(3)];

  jsonList.jsonToHeapString.should.equal(dList.jsonArrayToHeapString);
}

HeapString jsonToString(Json value) {
  HeapString result;
  result.reserve(256);
  jsonToStringImpl(value, 0, result);
  return result;
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

private void jsonToStringImpl(Json value, size_t level, ref HeapString result) {
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
    // Use stack buffer for small objects, heap for large
    enum STACK_KEYS_SIZE = 32;
    string[STACK_KEYS_SIZE] stackKeys = void;
    string[] sortedKeys;
    size_t keyCount = 0;

    foreach (kv; value.byKeyValue) {
      if (kv.value.type != Json.Type.null_ && kv.value.type != Json.Type.undefined) {
        if (keyCount < STACK_KEYS_SIZE) {
          stackKeys[keyCount] = kv.key;
        } else if (keyCount == STACK_KEYS_SIZE) {
          // Overflow to heap
          sortedKeys = stackKeys[0 .. STACK_KEYS_SIZE].dup;
          sortedKeys ~= kv.key;
        } else {
          sortedKeys ~= kv.key;
        }
        keyCount++;
      }
    }

    if (keyCount == 0) {
      result ~= "{}";
      return;
    }

    // Sort the appropriate array
    if (keyCount <= STACK_KEYS_SIZE) {
      stackKeys[0 .. keyCount].sort();
    } else {
      sortedKeys.sort();
    }

    immutable prefix = getIndent(level + 1);
    immutable endPrefix = getIndent(level);

    result ~= "{\n";
    bool first = true;

    if (keyCount <= STACK_KEYS_SIZE) {
      foreach (key; stackKeys[0 .. keyCount]) {
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
    } else {
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
    // Use 10 decimal precision for JSON serialization (matches original behavior)
    auto floatStr = toFloatingString(value.to!double, 10);
    result ~= floatStr[];
    return;
  }

  result ~= value.to!string;
}

/// it does not serialize undefined properties
unittest {
  import fluentasserts.core.base;

  auto obj = `{ "a": 1 }`.parseJsonString;

  obj.remove("a");

  obj.jsonToString[].should.equal(`{}`);
}

/// it does not serialize null properties
unittest {
  import fluentasserts.core.base;

  auto obj = Json.emptyObject;

  obj["a"] = Json(null);

  obj.jsonToString[].should.equal(`{}`);
}

/// it should convert a double to a string
unittest {
  import fluentasserts.core.base;

  Json(2.3).jsonToString[].should.equal("2.3");
  Json(59.0 / 15.0).jsonToString[].should.equal("3.9333333333");
}

/// serializes object with sorted keys and 2-space indentation
unittest {
  import fluentasserts.core.base;

  auto obj = Json.emptyObject;
  obj["zebra"] = 1;
  obj["apple"] = 2;
  obj["mango"] = 3;

  obj.jsonToString[].should.equal("{\n  \"apple\": 2,\n  \"mango\": 3,\n  \"zebra\": 1\n}");
}

/// serializes nested objects with proper indentation
unittest {
  import fluentasserts.core.base;

  auto obj = Json.emptyObject;
  obj["outer"] = Json.emptyObject;
  obj["outer"]["inner"] = "value";

  obj.jsonToString[].should.equal("{\n  \"outer\": {\n    \"inner\": \"value\"\n  }\n}");
}

/// serializes arrays with proper indentation
unittest {
  import fluentasserts.core.base;

  auto arr = Json([Json(1), Json(2), Json(3)]);

  arr.jsonToString[].should.equal("[\n  1,\n  2,\n  3\n]");
}

/// serializes empty array
unittest {
  import fluentasserts.core.base;

  Json.emptyArray.jsonToString[].should.equal("[]");
}

/// serializes object with string keys and string values
unittest {
  import fluentasserts.core.base;

  auto obj = Json.emptyObject;
  obj["name"] = "John";
  obj["city"] = "Berlin";

  obj.jsonToString[].should.equal("{\n  \"city\": \"Berlin\",\n  \"name\": \"John\"\n}");
}
