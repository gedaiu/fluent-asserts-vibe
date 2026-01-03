module fluentasserts.vibe.json.serializer;

version (Have_vibe_serialization):

import std.algorithm : filter, map, sort;
import std.array : array, join, replicate;
import std.conv : to;
import std.format : format;
import std.string : strip;

import vibe.data.json;

import fluentasserts.core.memory.heapstring : HeapString, toHeapString;

string escapeJsonString(string s) {
  import std.array : appender;

  auto result = appender!string();
  result.reserve(s.length);

  foreach (c; s) {
    switch (c) {
      case '"':  result ~= `\"`; break;
      case '\\': result ~= `\\`; break;
      case '\n': result ~= `\n`; break;
      case '\r': result ~= `\r`; break;
      case '\t': result ~= `\t`; break;
      case '\b': result ~= `\b`; break;
      case '\f': result ~= `\f`; break;
      default:
        if (c < 0x20) {
          result ~= format(`\u%04x`, cast(uint) c);
        } else {
          result ~= c;
        }
    }
  }

  return result.data;
}

HeapString jsonToHeapString(Json value) @trusted {
  return toHeapString(jsonToStringNative(value));
}

HeapString jsonArrayToHeapString(Json[] values) @trusted {
  return toHeapString(jsonToStringNative(Json(values)));
}

/// it serializes an array to the same string as jsonArrayToHeapString
unittest {
  import fluentasserts.core.base;

  auto jsonList = Json([Json(1), Json(2), Json(3)]);
  auto dList = [Json(1), Json(2), Json(3)];

  jsonList.jsonToHeapString.should.equal(dList.jsonArrayToHeapString);
}

HeapString jsonToString(Json value) {
  return toHeapString(jsonToStringNative(value));
}

string jsonToStringNative(Json value) {
  return jsonToStringImpl(value, 0);
}

string jsonToStringSlice(Json value) {
  return jsonToStringImpl(value, 0);
}

private string jsonToStringImpl(Json value, size_t level) {
  if (value.type == Json.Type.array) {
    if (value.length == 0) {
      return `[]`;
    }

    string prefix = replicate("  ", level + 1);
    string endPrefix = replicate("  ", level);
    auto elements = value.byValue.map!(a => prefix ~ jsonToStringImpl(a, level + 1)).array;

    return "[\n" ~ elements.join(",\n") ~ "\n" ~ endPrefix ~ "]";
  }

  if (value.type == Json.Type.object) {
    string[] keys;
    foreach (kv; value.byKeyValue) {
      if (kv.value.type != Json.Type.null_ && kv.value.type != Json.Type.undefined) {
        keys ~= kv.key;
      }
    }

    if (keys.length == 0) {
      return `{}`;
    }

    keys.sort();

    string prefix = replicate("  ", level + 1);
    string endPrefix = replicate("  ", level);
    auto entries = keys.map!(key =>
      prefix ~ `"` ~ key ~ `": ` ~ jsonToStringImpl(value[key], level + 1)
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
    return `"` ~ escapeJsonString(value.to!string) ~ `"`;
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

  obj.jsonToStringNative.should.equal(`{}`);
}

/// it does not serialize null properties
unittest {
  import fluentasserts.core.base;

  auto obj = Json.emptyObject;

  obj["a"] = Json(null);

  obj.jsonToStringNative.should.equal(`{}`);
}

/// it should convert a double to a string
unittest {
  import fluentasserts.core.base;

  Json(2.3).jsonToStringNative.should.equal("2.3");
  Json(59.0 / 15.0).jsonToStringNative.should.equal("3.9333333333");
}

/// serializes object with sorted keys and 2-space indentation
unittest {
  import fluentasserts.core.base;

  auto obj = Json.emptyObject;
  obj["zebra"] = 1;
  obj["apple"] = 2;
  obj["mango"] = 3;

  obj.jsonToStringNative.should.equal("{\n  \"apple\": 2,\n  \"mango\": 3,\n  \"zebra\": 1\n}");
}

/// serializes nested objects with proper indentation
unittest {
  import fluentasserts.core.base;

  auto obj = Json.emptyObject;
  obj["outer"] = Json.emptyObject;
  obj["outer"]["inner"] = "value";

  obj.jsonToStringNative.should.equal("{\n  \"outer\": {\n    \"inner\": \"value\"\n  }\n}");
}

/// serializes arrays with proper indentation
unittest {
  import fluentasserts.core.base;

  auto arr = Json([Json(1), Json(2), Json(3)]);

  arr.jsonToStringNative.should.equal("[\n  1,\n  2,\n  3\n]");
}

/// serializes empty array
unittest {
  import fluentasserts.core.base;

  Json.emptyArray.jsonToStringNative.should.equal("[]");
}

/// serializes object with string keys and string values
unittest {
  import fluentasserts.core.base;

  auto obj = Json.emptyObject;
  obj["name"] = "John";
  obj["city"] = "Berlin";

  obj.jsonToStringNative.should.equal("{\n  \"city\": \"Berlin\",\n  \"name\": \"John\"\n}");
}

/// escapes special characters in strings
unittest {
  import fluentasserts.core.base;

  Json("hello\nworld").jsonToStringNative.should.equal(`"hello\nworld"`);
  Json("tab\there").jsonToStringNative.should.equal(`"tab\there"`);
  Json(`quote"here`).jsonToStringNative.should.equal(`"quote\"here"`);
  Json("back\\slash").jsonToStringNative.should.equal(`"back\\slash"`);
}

/// serializes complex object with escaped strings
unittest {
  import fluentasserts.core.base;

  auto message = `{
          "html":"<p>Hello ---,<\/p>\n\n<p>John just registered with the email leader@gmail.com at OGM. You can check their profile at<\/p>\n\n<p>/browse/profiles/000000000000000000000001<\/p>\n",
          "isSent":false,
          "actions":{"View profile":"/browse/profiles/000000000000000000000001"},
          "text":"Hello ---,\nJohn just registered with the email leader@gmail.com at OGM. You can check their profile at\n/browse/profiles/000000000000000000000001",
          "to":{"type":"","value":""},
          "uniqueKey":"notification-user-new-000000000000000000000001",
          "_id":"000000000000000000000001",
          "type":"admin",
          "subject":"There is a new user at OGM","sentOn":"0001-01-01T00:00:00+00:00",
          "useGenericTemplate":true
        }`.parseJsonString;

  message.jsonToStringNative.should.equal(`{
  "_id": "000000000000000000000001",
  "actions": {
    "View profile": "/browse/profiles/000000000000000000000001"
  },
  "html": "<p>Hello ---,</p>\n\n<p>John just registered with the email leader@gmail.com at OGM. You can check their profile at</p>\n\n<p>/browse/profiles/000000000000000000000001</p>\n",
  "isSent": false,
  "sentOn": "0001-01-01T00:00:00+00:00",
  "subject": "There is a new user at OGM",
  "text": "Hello ---,\nJohn just registered with the email leader@gmail.com at OGM. You can check their profile at\n/browse/profiles/000000000000000000000001",
  "to": {
    "type": "",
    "value": ""
  },
  "type": "admin",
  "uniqueKey": "notification-user-new-000000000000000000000001",
  "useGenericTemplate": true
}`);
}
