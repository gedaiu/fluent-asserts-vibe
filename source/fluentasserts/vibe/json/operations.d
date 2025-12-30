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
    return jsonToString(parsed)[].idup;
  } catch (Exception e) {
    return jsonStr;
  }
}

/// Custom equality operation for Json that ignores whitespace differences.
/// Compares two JSON values by normalizing them first, then showing a diff on failure.
void jsonEqual(ref Evaluation evaluation) @safe nothrow {
  try {
    // Use slice directly without idup when possible - only allocate if needed for error output
    string normalizedActual = (() @trusted => normalizeJson(cast(string)evaluation.currentValue.strValue[]))();
    string normalizedExpected = (() @trusted => normalizeJson(cast(string)evaluation.expectedValue.strValue[]))();

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
      evaluation.result.expected.put(normalizedExpected);
      evaluation.result.actual.put(normalizedActual);
      evaluation.result.setDiff(normalizedExpected, normalizedActual);
    })();
  } catch (Exception e) {
  }
}

/// Normalizes JSON for comparison by parsing and re-serializing.
/// For JSON objects/arrays, parses and re-serializes with sorted keys.
/// For strings, returns the unquoted string value for consistent comparison.
string normalizeJson(string input) @trusted {
  if (input.length == 0) {
    return input;
  }

  // Quick check for simple cases to avoid parsing overhead
  immutable firstChar = input[0];
  immutable bool looksLikeJson = firstChar == '{' || firstChar == '[' || firstChar == '"';

  if (!looksLikeJson) {
    // Check if it's whitespace-prefixed JSON
    size_t i = 0;
    while (i < input.length && (input[i] == ' ' || input[i] == '\t' || input[i] == '\n' || input[i] == '\r')) {
      i++;
    }
    if (i == input.length) {
      return input;
    }
    immutable strippedFirst = input[i];
    if (strippedFirst != '{' && strippedFirst != '[' && strippedFirst != '"') {
      // Not JSON-like, try parsing as primitive
      try {
        auto parsed = parseJsonString(input);
        return jsonToString(parsed)[].idup;
      } catch (Exception) {
        return input;
      }
    }
    // Strip and continue with the stripped version
    input = input[i .. $];
  }

  try {
    auto parsed = parseJsonString(input);
    // For string values, return the raw string content (without quotes)
    if (parsed.type == Json.Type.string) {
      auto content = parsed.get!string;
      // Only try to parse as nested JSON if it looks like JSON
      if (content.length > 0 && (content[0] == '{' || content[0] == '[')) {
        try {
          auto innerParsed = parseJsonString(content);
          if (innerParsed.type == Json.Type.object || innerParsed.type == Json.Type.array) {
            return jsonToString(innerParsed)[].idup;
          }
        } catch (Exception) {
        }
      }
      return content;
    }
    return jsonToString(parsed)[].idup;
  } catch (Exception) {
    return input;
  }
}

/// normalizeJson handles Json[] serialization format
unittest {
  // This is the format that Json[] produces when serialized by the default serializer
  auto input = "[{\n  \"key\": \"value\"\n}]";
  auto normalized = normalizeJson(input);

  // After normalization, it should match the jsonToString format
  auto expected = "[\n  {\n    \"key\": \"value\"\n  }\n]";
  normalized.should.equal(expected);
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

/// Compare Json (containing array) with Json[] D array - mirrors response.bodyJson["features"].should.equal([site1])
unittest {
  auto site1 = Json.emptyObject;
  site1["_id"] = "000000000000000000000001";
  site1["name"] = "site1";

  auto responseJson = Json.emptyObject;
  responseJson["features"] = Json([site1]);

  // This is the exact pattern from the failing test
  responseJson["features"].should.equal([site1]);
}

/// Compare Json[] D array with Json (containing array)
unittest {
  auto obj = Json.emptyObject;
  obj["key"] = "value";

  Json[] dArray = [obj];
  auto jsonArray = Json([obj]);

  dArray.should.equal(jsonArray);
}
