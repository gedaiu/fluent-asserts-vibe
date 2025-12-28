module fluentasserts.vibe.json.serializer;

version (Have_vibe_d_data):

import std.algorithm : filter, map, sort;
import std.array : array, join, replicate;
import std.conv : to;
import std.format : format;
import std.string : strip;

import vibe.data.json;

import fluentasserts.core.memory.heapstring : HeapString, toHeapString;

HeapString jsonToHeapString(Json value) @trusted {
  return toHeapString(jsonToString(value));
}

string jsonToString(Json value) {
  return jsonToString(value, 0);
}

string jsonToString(Json value, size_t level) {
  if (value.type == Json.Type.array) {
    if (value.length == 0) {
      return `[]`;
    }

    string prefix = replicate("  ", level + 1);
    string endPrefix = replicate("  ", level);
    auto elements = value.byValue.map!(a => prefix ~ jsonToString(a, level + 1)).array;

    return "[\n" ~ elements.join(",\n") ~ "\n" ~ endPrefix ~ "]";
  }

  if (value.type == Json.Type.object) {
    auto sortedKeys = value.keys.sort.filter!(key =>
      value[key].type != Json.Type.null_ && value[key].type != Json.Type.undefined
    );

    if (sortedKeys.empty) {
      return `{}`;
    }

    string prefix = replicate("  ", level + 1);
    string endPrefix = replicate("  ", level);
    auto entries = sortedKeys.map!(key =>
      prefix ~ `"` ~ key ~ `": ` ~ jsonToString(value[key], level + 1)
    ).array;

    return "{\n" ~ entries.join(",\n") ~ "\n" ~ endPrefix ~ "}";
  }

  if (value.type == Json.Type.null_) {
    return "null";
  }

  if (value.type == Json.Type.undefined) {
    return "undefined";
  }

  if (value.type == Json.Type.string) {
    return `"` ~ value.to!string ~ `"`;
  }

  if (value.type == Json.Type.float_) {
    return format("%.10f", value.to!double).strip("0").strip(".");
  }

  return value.to!string;
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
