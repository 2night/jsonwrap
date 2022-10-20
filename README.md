# jsonwrap
Just a wrap over dlang std.json.

## Setup

Add jsonwrap to your dub project:

```dub add jsonwrap```

## Quickstart

jsonwrap just adds some useful methods to ```JSONValue``` from ```std.json```.

```d
import jsonwrap;

void main()
{
  import std.exception :assertThrown;

  // This works with CTFE, too.
  auto j = JSOB(
    "field1", "value1",
    "field2", JSOB(
      "subfield1", "value2",
      "subfield2", 3,
      "subfield3", [1,2,3],
    ),
    "field3", JSAB("mixed", 10, "array", JSOB("obj", 15))
  );

  // Or
  // auto j = parseJSON(`{"field" : "value1"}`);

  // Read will throw on error
  assert(j.read!string("/field2/subfield1") == "value2");
  assert(j.read!int("/field3/1") == 10);
  assert(j.read!int("/field3/3/obj") == 15);
  assertThrown(j.read!string("/field2/subfield2")); // Wrong type

  // Safe return default value on error
  assert(j.safe!string("/field2/subfield2") == string.init);  // subfield2 is a int, wrong type.
  assert(j.safe!string("/field2/wrong/path") == string.init);
  assert(j.safe!string("/field2/wrong/path", "default") == "default");

  // Like safe, but it tries to convert
  assert(j.as!string("/field2/subfield1"), "value2");
  assert(j.as!string("/field2/subfield2"), "3");

  // Check if a key exists
  assert(j.exists("/field2/subfield1") == true);
  assert(j.exists("/field3/test") == false);

  // Remove a key
  assert(j.exists("/field2/subfield2") == true);
  j.remove("/field2/subfield2");
  assert(j.exists("/field2/subfield2") == false);

  // Add a new value, recreating the whole tree
  j.put("hello/world/so/deep", "yay!");
  assert(j.exists("hello/world/so/deep") == true);

}
```

## One more thing

```d
import std.json;
import jsonwrap;

// std.json way to parse json
JSONValue json = parseJSON(`
{
  "user" : "foo",
  "address" :
  {
    "city" : "venice",
    "country" : "italy"
  },
  "tags" : ["hello" , 3 , {"key" : "value"}]
}
`);

{
  // Read a string, user is a SafeValue!string
  auto user = json.safe!string("user");
  assert(user.ok == true);
  assert(user.exists == true);

  // This field doesn't exists on json
  // I can set a default value
  auto notfound = json.safe!string("blah", "my default value");
  assert(notfound.ok == false);
  assert(notfound.exists == false);
  assert(notfound == "my default value");

  // This field exists but it's not an int, it's a string
  auto wrong = json.safe!int("user");
  assert(wrong.ok == false);
  assert(wrong.exists == true);
  assert(wrong == int.init);
}

```

Documentation available [here](https://jsonwrap.dpldocs.info/jsonwrap.html)

