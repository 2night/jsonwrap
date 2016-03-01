# jsonwrap
Just a wrap over dlang std.json

### How it works?

```d
import std.json : parseJSON;
import jsonwrap;

// Standard way
JSONValue json = parseJSON(`{"user" : "foo", "address" : {"city" : "venice", "country" : "italy"}, "tags" : ["hello" , 3 , {"key" : "value"}]}`);

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

{
  // A fast way to build object CTFE compatible. 
  // JSOB is an alias for JsonObjectBuilder and JSAB for JsonArrayBuilder
  JSONValue jv = JSOB
  (
     "key", "value", 
     "obj", JSOB("subkey", 3), 
     "array", [1,2,3], 
     "mixed_array", JSAB(1, "hello", 3.0f)
  );
  
  assert(jv.toString == `{"array":[1,2,3],"key":"value","mixed_array":[1,"hello",3],"obj":{"subkey":3}}`);
}
```
