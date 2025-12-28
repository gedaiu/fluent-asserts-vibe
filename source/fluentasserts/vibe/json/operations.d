module fluentasserts.vibe.json.operations;

version (Have_vibe_d_data):

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

    string normalizedActual = normalizeJson(actualStr);
    string normalizedExpected = normalizeJson(expectedStr);

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
string normalizeJson(string input) @trusted nothrow {
  try {
    if (input.length >= 2 && input[0] == '"' && input[$ - 1] == '"') {
      input = input[1 .. $ - 1];
    }

    auto parsed = parseJsonString(input);
    return jsonToString(parsed);
  } catch (Exception e) {
    return input;
  }
}

/// JSON equality ignores whitespace differences
unittest {
  auto json1 = `{"key": "value"}`.parseJsonString;
  auto json2 = `{  "key"  :  "value"  }`.parseJsonString;

  json1.should.equal(json2);
}

/// JSON equality with string comparison ignores whitespace
unittest {
  auto json = `{"key": "value"}`.parseJsonString;

  json.should.equal(`{  "key"  :  "value"  }`);
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
