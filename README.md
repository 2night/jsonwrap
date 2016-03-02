# jsonwrap
Just a wrap over dlang std.json.

### Setup

Add jsonwrap to your dub project:

```json
"dependencies":
{
  "jsonwrap" : "*"
}
```

### How to

It works using UCFS on standard JSONValue.
Basic usage:

```d
import std.json;
import jsonwrap;

// Standard way to parse json
JSONValue json = parseJSON(`{"hello":"world"}`);

// Read a value
string world = json.get!string("hello");

// Write a value 
json.put("foo", "bar");

// Now json == {"hello":"world", "foo":"bar"}
```

More ways to read:

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
  string user = json.get!string("user"); // Read a string from json
  assert(user == "foo");
}

{
  // Read a string, user is a SafeValue!string
  auto user = json.get!string("user");
  assert(user.ok == true);
  assert(user.exists == true);
  
  // This field doesn't exists on json 
  // I can set a default value
  auto notfound = json.get!string("blah", "my default value");
  assert(notfound.ok == false);
  assert(notfound.exists == false);
  assert(notfound == "my default value");
  
  // This field exists but it's not an int, it's a string 
  auto wrong = json.get!int("user");
  assert(wrong.ok == false);
  assert(wrong.exists == true); 
  assert(wrong == int.init);
}

{
  // I can read deep fields
  assert(json.get!string("/address/city") == "venice");
  
  // also inside an array
  assert(json.get!string("/tags/2/key") == "value");
}

{
  // Using as!T you can convert field 
  assert(json.as!string("/tags/1") == "3"); // On json "/tags/1" is an int.
}

// get!T and as!T are nothrow functions and they return a SafeValue!T.
// read!T throw an exception on error

{
  import std.exception: assertThrown;
  assert(json.read!string("/tags/2/key") == "value");
  assertThrown(json.read!int("/blah/blah"));
}

```

More:

```d


{
  // You can check if a field exists or not
  assert(json.exists("/address/country") == true);
  
  // You can remove it
  json.remove("/address/country");
  
  // It doesn't exists anymore
  assert(json.exists("/address/country") == false);
}

{
  // You can write using put.
  json.put("/address/country", "italy"); // Restore deleted field 
  json.put("/this/is/a/deep/value", 100); // It create the whole tree
  json.put("/this/is/an/array/5", "hello"); // Ditto
  
  assert(json.get!int("/this/is/a/deep/value") == 100);
  assert(json.get!string("/this/is/an/array/5") == "hello"); // elements 0,1,2,3,4 are nulled
}
```

Object and Array builders (CTFE-compatible):

```d
{
  // A fast way to build object CTFE compatible. 
  // JSOB is an alias for JsonObjectBuilder and JSAB for JsonArrayBuilder
  enum jv = JSOB
  (
     "array", [1,2,3], 
     "key", "value", 
     "mixed_array", JSAB(1, "hello", 3.0f),
     "obj", JSOB("subkey", 3)
  );
  
  /* jv ==
    {
      "array":[1,2,3],
      "key":"value",
      "mixed_array":[1,"hello",3],
      "obj": { "subkey" : 3 }
    }
  */
}
```
