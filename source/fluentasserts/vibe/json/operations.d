module fluentasserts.vibe.json.operations;

version (Have_vibe_serialization):

import vibe.data.json;

import fluentasserts.core.base;
import fluentasserts.core.evaluation.eval : Evaluation;
import fluentasserts.vibe.json.serializer : jsonToString;

/// Normalizes a JSON string by parsing and re-serializing with consistent formatting.
/// This removes whitespace differences between JSON values.
string normalizeJsonString(string jsonStr) @trusted {
  try {
    auto parsed = parseJsonString(jsonStr);
    return jsonToString(parsed);
  } catch (Exception e) {
    return jsonStr;
  }
}

/// Custom equality operation for Json that ignores whitespace differences.
/// Compares two JSON values by normalizing them first, then showing a diff on failure.
void jsonEqual(ref Evaluation evaluation) @safe nothrow {
  try {
    string actualStr = (() @trusted => evaluation.currentValue.strValue[].idup)();
    string expectedStr = (() @trusted => evaluation.expectedValue.strValue[].idup)();

    string normalizedActual = (() @trusted => normalizeJson(actualStr))();
    string normalizedExpected = (() @trusted => normalizeJson(expectedStr))();

    bool isEqual = normalizedActual == normalizedExpected;
    bool passed = evaluation.isNegated ? !isEqual : isEqual;

    if (passed) {
      return;
    }

    evaluation.result.negated = evaluation.isNegated;

    if (evaluation.isNegated) {
      (() @trusted => evaluation.result.expected.put("not equal to"))();
    }

    (() @trusted {
      evaluation.result.expected.put(expectedStr);
      evaluation.result.actual.put(actualStr);
      evaluation.result.setDiff(expectedStr, actualStr);
    })();
  } catch (Exception e) {
  }
}

/// Normalizes JSON for comparison by parsing and re-serializing.
/// For JSON objects/arrays, parses and re-serializes with sorted keys.
/// For strings, returns the unquoted string value for consistent comparison.
string normalizeJson(string input) @trusted {
  import std.string : strip;

  // First try to parse as-is
  try {
    auto parsed = parseJsonString(input);
    // For string values, return the raw string content (without quotes)
    if (parsed.type == Json.Type.string) {
      auto content = parsed.get!string;
      // Try to parse the content as JSON (handles escaped JSON strings)
      try {
        auto innerParsed = parseJsonString(content);
        if (innerParsed.type == Json.Type.object || innerParsed.type == Json.Type.array) {
          return jsonToString(innerParsed);
        }
      } catch (Exception) {
      }
      return content;
    }
    return jsonToString(parsed);
  } catch (Exception e) {
    // Parsing failed - might be a raw string that looks like JSON but has extra whitespace
    // Try stripping and parsing again
    auto stripped = input.strip;
    if (stripped.length > 0 && (stripped[0] == '{' || stripped[0] == '[')) {
      try {
        auto parsed = parseJsonString(stripped);
        return jsonToString(parsed);
      } catch (Exception) {
      }
    }
    return input;
  }
}

/// normalizeJson extracts string content from quoted JSON strings
unittest {
  auto normalized1 = normalizeJson(`"3"`);  // Quoted JSON string
  auto normalized2 = normalizeJson(`3`);    // Unquoted (parsed as int)

  // JSON string "3" should normalize to just 3 (content without quotes)
  normalized1.should.equal("3");
  // Integer 3 should normalize to 3
  normalized2.should.equal("3");
}

/// normalizeJson normalizes JSON objects with different whitespace
unittest {
  auto normalized1 = normalizeJson(`{"key": "value"}`);
  auto normalized2 = normalizeJson(`{  "key"  :  "value"  }`);

  // Both should normalize to the same formatted JSON
  normalized1.should.equal(normalized2);
}

/// JSON equality ignores whitespace differences
unittest {
  auto json1 = `{"key": "value"}`.parseJsonString;
  auto json2 = `{  "key"  :  "value"  }`.parseJsonString;

  json1.should.equal(json2);
}

/// JSON equality detects actual differences
unittest {
  auto json1 = `{"key": "value1"}`.parseJsonString;
  auto json2 = `{"key": "value2"}`.parseJsonString;

  ({
    json1.should.equal(json2);
  }).should.throwException!TestException;
}

/// JSON equality works with nested objects ignoring whitespace
unittest {
  auto json1 = `{"outer":{"inner":"value"}}`.parseJsonString;
  auto json2 = `{
    "outer": {
      "inner": "value"
    }
  }`.parseJsonString;

  json1.should.equal(json2);
}

/// JSON equality works with arrays ignoring whitespace
unittest {
  auto json1 = `[1,2,3]`.parseJsonString;
  auto json2 = `[ 1 , 2 , 3 ]`.parseJsonString;

  json1.should.equal(json2);
}

/// JSON equality with key order differences (sorted keys make them equal)
unittest {
  auto json1 = `{"b": 2, "a": 1}`.parseJsonString;
  auto json2 = `{"a": 1, "b": 2}`.parseJsonString;

  json1.should.equal(json2);
}

/// JSON not equal works correctly
unittest {
  auto json1 = `{"key": "value1"}`.parseJsonString;
  auto json2 = `{"key": "value2"}`.parseJsonString;

  json1.should.not.equal(json2);
}
