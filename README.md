# jsonwrap
Just a wrap over dlang std.json. Documentation available [here](https://jsonwrap.dpldocs.info/jsonwrap.html)

## Create a json
```d
// Standard D way
JSONValue json = parseJSON(`{"name":"John Doe", "age":31, "tags":["user", "admin"]}`);

// jsonwrap helper
json.parse(`{"name":"John Doe", "age":31, "tags":["user", "admin"]}`);

// JSOB/JSAB builders
json = JSOB("name", "John Doe", "age", 31, "tags", JSAB("user", "admin"));
```
## Read a value
```d
JSONValue json = parseJSON(`
    {
    "user" : { "name" : "John Doe", "age" : 31, "tags" : ["user", "admin"]},
    "city" : "London"
    }
`);

// Plain read
assert(json.read!string("user/name") == "John Doe");
assert(json.read!string("/user/tags/1") == "admin");

// safe() and as()
assertThrown(json.read!string("user/age")); // Exception: user/age is an int, not string.
assert(json.safe!string("user/age", "N/D") == "N/D"); // safe method returns a default value on error
assert(json.as!string("user/age") == "31"); // as method convert value to requested type
```

## Put a value
```d
JSONValue json;

json.put("name", "John");
json.put("tags", ["1", "2", "3"]);
json.put("arr", JSAB("mixed", 10, "array"));

// Append to an existing array
json.append("tags", 4);

// Create a new array and append an element
json.append("new_array", 1);

// Convert existing element to array and append
json.append("name", "Doe");

/+ Result:
{
    "name" : ["John","Doe"],
    "arr" : ["mixed",10,"array"],
    "tags" : ["1","2","3",4],
    "new_array" : [1]
}
+/

// Add a new value, recreating the whole json tree
j.put("hello/world/so/deep", "yay!");
```
## Other methods

```d
// Check if a key exists
assert(j.exists("/user/name") == true);

// Remove a key
j.remove("/field2/subfield2");
```

## Working with safe()

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

