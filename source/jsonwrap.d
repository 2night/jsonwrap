module jsonwrap;
/++ Some extra functions to make easier to work with json
---
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
   // auto j = parseJSON(`{"field1" : "value1", "field2" : "..."}`);

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
---
+/

import std.json : JSONValue, JSONType;
import std.string : isNumeric, indexOf;
import std.typecons : Tuple;
import std.conv : to;
import std.traits : isIntegral, isSomeString;

alias JSOB = JsonObjectBuilder;  /// Shorthand
alias JSAB = JsonArrayBuilder;   /// Shorthand

deprecated(".get() is deprecated. Use .safe() instead")
{
   alias get = jsonwrap.safe;
}

/// A simple struct. It is returned by .safe and .as functions
struct SafeValue(T)
{
	@safe @nogc nothrow
	this(in bool exists, in bool ok, in T value = T.init)
	{
		this._exists = exists;
		this._ok = ok;
		this.value = value;
	}

   // Return true if key is found.
   @property @safe @nogc nothrow exists() inout { return _exists; }

   // Return true if value is read without errors
   @property @safe @nogc nothrow ok() inout { return _ok; }

	private bool _exists   = false;
	private bool _ok 	     = false;

   T value = T.init;

   alias value this;
}

/// It allows you to read deep values inside a json. If possibile it converts value to type T.
pure nothrow
SafeValue!T as(T)(in JSONValue json, in string path = "", /* lazy */ in T defaultValue = T.init)
{
   // A way to check if to!T is valid
   pure
   void tryConv(T, K)(in K value, ref SafeValue!T result)
   {
      static if (__traits(compiles,to!T(value)))
      {
         result.value = to!T(value);
         result._ok = true;
      }
      else
      {
         result.value = defaultValue;
         result._ok = false;

      }
   }

   immutable 	splitted = split_json_path(path);
	immutable  	isLast	= splitted.remainder.length == 0;
	JSONValue 	value;

   // Split the path passed in tokens and take the first JSONValue
	try
	{
		if (json.type() == JSONType.object) value = json[splitted.token];
		else if (json.type() == JSONType.array) value = json[to!size_t(splitted.token)];
      else value = json;
   }
   catch (Exception e) {  return SafeValue!T(false, false, defaultValue); }

	immutable type	= value.type();

	// The token is a leaf on json, but it's not a leaf on requested path
	if (!isLast && type != JSONType.array && type != JSONType.object)
      return SafeValue!T(false, false, defaultValue);

	SafeValue!T result = SafeValue!T(true, true, defaultValue);

   try
   {
   	final switch(type)
   	{
   		case JSONType.null_:
   			result._ok 	= is(T == typeof(null));
   			break;

   		case JSONType.false_:
   			static if (is(T == bool)) result.value = false;
   			else tryConv!T(false, result);
   			break;

   		case JSONType.true_:
   			static if (is(T == bool)) result.value = true;
   			else tryConv!T(true, result);
   			break;

   		case JSONType.float_:
            static if (is(T == float) || is(T == double)) result.value = to!T(value.floating());
            else tryConv!T(value.floating(), result);
            break;

   		case JSONType.integer:
            static if (isIntegral!T) result.value = to!T(value.integer());
            else tryConv!T(value.integer(), result);
   			break;

   		case JSONType.uinteger:
            static if (isIntegral!T) result.value = to!T(value.uinteger());
            else tryConv!T(value.uinteger(), result);
   			break;

   		case JSONType.string:
            static if (isSomeString!T) result.value = to!T(value.str());
            else tryConv!T(value.str(), result);
   			break;

         case JSONType.object:
   			if (isLast)
   			{
               // We are on the last token of path and we have a object. If user asks for a JSONValue it's ok.
   				static if (is(T == JSONValue)) result.value = value.object();
   				else result._ok = false;
   			}
            // Recursion: read next part of path
   			else return as!T(value, splitted.remainder, defaultValue);
   			break;

         // Ricorsivo: richiamo per l'elemento indicizzato con il percorso accorciato
         case JSONType.array:
   			if (isLast)
   			{
   				// We are on the last token of path and we have an array. If user asks for a JSONValue it's ok.
   				static if  (is(T == JSONValue)) result.value = value.array();
   				else result._ok = false;
   			}
   			// Recursion: read next part of path
   			else return as!T(value, splitted.remainder, defaultValue);
   			break;
   	}

   }
   catch (Exception ce)
   {
      // Something goes wrong with conversions. Sorry, we give you back a default value
      return SafeValue!T(true, false, defaultValue);
   }

	return result;
}

/// Shortcut. You can write as!null instead of as!(typeof(null))
pure nothrow
SafeValue!(typeof(null)) as(typeof(null) T)(in JSONValue json, in string path = "")
{
   return as!(typeof(null))(json, path);
}

unittest
{
	immutable js = JSOB("string", "str", "null", null, "obj", JSOB("int", 1, "float", 3.0f, "arr", JSAB("1", 2)));

	assert(js.as!(typeof(null))("null").ok == true);
	assert(js.as!(typeof(null))("string").ok == false);
	assert(js.as!string("/string") == "str");
	assert(js.as!string("/obj/int") == "1");
	assert(js.as!int("/obj/arr/0") == 1);
	assert(js.as!int("/obj/arr/1") == 2);
	assert(js.as!float("/obj/float") == 3.0f);
	assert(js.as!int("/obj/int/blah").exists == false);
	assert(js.as!string("bau").exists == false);
	assert(js.as!int("/string").exists == true);
	assert(js.as!int("/string").ok == false);
}

/// Works like as!T but it doesn't convert between types.
pure nothrow
SafeValue!T safe(T)(in JSONValue json, in string path = "", in T defaultValue = T.init)
{
   alias Ret = SafeValue!T;

	immutable 	splitted = split_json_path(path);
   immutable   isLast 	= splitted.remainder.length == 0;
   JSONValue   value;

   // Split the path passed in tokens and take the first JSONValue
	try
   {
      if (json.type() == JSONType.object) value = json[splitted.token];
      else if (json.type() == JSONType.array) value = json[to!size_t(splitted.token)];
      else value = json;
   }
   catch (Exception e)
   {
		return Ret(false, false, defaultValue);
   }

   immutable type  = value.type();

   // The token is a leaf on json, but it's not a leaf on requested path
	if (!isLast && type != JSONType.array && type != JSONType.object)
      return Ret(false, false, defaultValue);

   try
   {
      final switch(type)
      {
         case JSONType.null_:       static if (is(T == typeof(null))) return Ret(true, true, null); else break;
         case JSONType.false_:      static if (is(T == bool)) return Ret(true, true, false); else break;
         case JSONType.true_:       static if (is(T == bool)) return Ret(true, true, true); else break;
         case JSONType.float_:      static if (is(T == float) || is(T == double)) return Ret(true, true, value.floating()); else break;
         case JSONType.integer:    static if (isIntegral!T) return Ret(true, true, to!T(value.integer())); else break;
         case JSONType.uinteger:   static if (isIntegral!T) return Ret(true, true, to!T(value.uinteger())); else break;
         case JSONType.string:     static if (isSomeString!T) return Ret(true, true, value.str()); else break;

         case JSONType.object:
            if (isLast) {
               // See also: as!T
               static if (is(T == JSONValue))
                  return Ret(true, true, JSONValue(value.object));
               else break;
            }
            else return safe!T(value, splitted.remainder, defaultValue);

         case JSONType.array:
            if (isLast) {
               // See also: as!T
               static if (is(T == JSONValue))
                  return Ret(true, true, JSONValue(value.array));
               else break;
            }
            else return safe!T(value, splitted.remainder, defaultValue);
      }
   }
   catch (Exception e)
   {
      return Ret(true, false, defaultValue);
   }

   // Wrong conversion requested.
   return Ret(true, false, defaultValue);
}

/// Shortcut. You can write safe!null instead of safe!(typeof(null))
pure nothrow
SafeValue!(typeof(null)) safe(typeof(null) T)(in JSONValue json, in string path = "")
{
   return safe!(typeof(null))(json, path);
}

unittest
{
	immutable js = JSOB("string", "str", "null", null, "obj", JSOB("int", 1, "float", 3.0f, "arr", JSAB("1", 2)));

	assert(js.safe!(typeof(null))("null").ok == true);
	assert(js.safe!(typeof(null))("string").ok == false);
	assert(js.safe!string("/string") == "str");

	assert(js.safe!string("/obj/int").ok == false);
	assert(js.safe!string("/obj/int") == string.init);

	assert(js.safe!int("/obj/arr/0").ok == false);
	assert(js.safe!int("/obj/arr/0") == int.init);

	assert(js.safe!int("/obj/arr/1") == 2);
	assert(js.safe!float("/obj/float") == 3.0f);
	assert(js.safe!int("/obj/int/blah").exists == false);
	assert(js.safe!string("bau").exists == false);
	assert(js.safe!int("/string").exists == true);
	assert(js.safe!int("/string").ok == false);
}

unittest
{
	immutable js = JSOB("notnull", 0, "null", null);

	assert(js.as!null("/null").ok == true);
	assert(js.as!null("/notnull").ok == false);

	assert(js.safe!null("/null").ok == true);
	assert(js.safe!null("/notnull").ok == false);
}

/// Works like safe but return T instead of SafeValue!T and throw an exception if something goes wrong (can't convert value or can't find key)
pure
T read(T)(in JSONValue json, in string path = "")
{
	auto ret = safe!T(json, path);

   if (!ret.ok || !ret.exists)
      throw new Exception("Can't read " ~ path ~ " from json");

   return ret.value;
}

unittest
{
   import std.exception: assertThrown;
   immutable js = JSOB("string", "str", "null", null, "obj", JSOB("int", 1, "float", 3.0f, "arr", JSAB("1", 2)));

   assert(js.read!string("string") == "str");
   assert(js.read!int("/obj/int") == 1);
   assertThrown(js.read!int("string"));
   assertThrown(js.read!int("other"));
}


/// Write a value. It creates missing objects and array (also missing elements)
pure
ref JSONValue put(T)(return ref JSONValue json, in string path, in T value)
{
   // Take a token from path
   immutable splitted = split_json_path(path);
   immutable isLast   = splitted.remainder.length == 0;

	enum nullValue = JSONValue(null);

   // If token is a number, we are trying to write an array.
   if (isNumeric(splitted.token))
   {
      immutable idx = to!size_t(splitted.token);

      // Are we reading an existing element from an existing array?
      if (json.type == JSONType.array && json.array.length > idx)
      {
         if (!isLast) put!T(json.array[idx], splitted.remainder, value);
         else json.array[idx] = value;
      }
      else
      {
         if (json.type != JSONType.array)
            json = JSONValue[].init;

         json.array.length = idx+1;

         if (!isLast) put!T(json.array[idx], splitted.remainder, value);
         else json.array[idx] = value;
      }
   }
   // If token is *NOT* a number, we are trying to write an object.
   else
   {
      immutable idx = splitted.token;

      // Are we reading an existing object?
      if (json.type == JSONType.object)
      {
         if (!isLast)
         {
            if (idx !in json.object)
               json.object[idx] = nullValue;

            put!T(json.object[idx], splitted.remainder, value);
         }
         else json.object[idx] = value;
      }
      else
      {
         json = string[string].init;

         if (!isLast)
         {
            json.object[idx] = nullValue;
            put!T(json.object[idx], splitted.remainder, value);
         }
         else json.object[idx] = value;
      }
   }

   return json;
}

unittest
{
	auto js = JSOB("string", "str", "null", null, "obj", JSOB("int", 1, "float", 3.0f, "arr", JSAB("1", 2)));

	js.put("/string", "hello");
	js.put("/null/not", 10);
	js.put("/obj/arr/3", JSOB);
	js.put("hello", "world");

	assert(js.safe!string("/string") == "hello");
	assert(js.safe!int("/null/not") == 10);
	assert(js.safe!null("/obj/arr/2").ok);
	assert(js.safe!JSONValue("/obj/arr/3") == JSOB);
	assert(js.safe!JSONValue("/obj/arr/3").ok == true);
	assert(js.safe!string("hello") == "world");
}

/// Remove a field (if it exists). It returns the object itself
pure
ref JSONValue remove(return ref JSONValue json, in string path)
{
   immutable splitted 	= split_json_path(path);
   immutable isLast  	= splitted.remainder.length == 0;

   // See above
   if (isNumeric(splitted.token))
   {
      immutable idx = to!size_t(splitted.token);

      if (json.type == JSONType.array && json.array.length > idx)
      {
         if (isLast) json.array = json.array[0..idx] ~ json.array[idx+1 .. $];
         else  json.array[idx].remove(splitted.remainder);
      }

   }
   else
   {
      immutable idx = splitted.token;

      if (json.type == JSONType.object && idx in json.object)
      {
         if (isLast) json.object.remove(idx);
         else json.object[idx].remove(splitted.remainder);
      }
   }


   return json;
}

/// Check if a field exists or not
pure
bool exists(in JSONValue json, in string path)
{
   immutable splitted 	= split_json_path(path);
   immutable isLast  	= splitted.remainder.length == 0;

   // See above
   if (isNumeric(splitted.token))
   {
      immutable idx = to!size_t(splitted.token);

      if (json.type == JSONType.array && json.array.length > idx)
      {
         if (isLast) return true;
         else return json.array[idx].exists(splitted.remainder);
      }

   }
   else
   {
      immutable idx = splitted.token;

      if (json.type == JSONType.object && idx in json.object)
      {
         if (isLast) return true;
         else return json.object[idx].exists(splitted.remainder);
      }
   }

   return false;
}

unittest
{
	auto js = JSOB("string", "str", "null", null, "obj", JSOB("int", 1, "float", 3.0f, "arr", JSAB("1", 2)));

	js.put("/string", "hello");
	js.put("/null/not", 10);
	js.put("/obj/arr/3", JSOB);
	js.put("hello", "world");

	js.remove("/obj/arr/2");
	js.remove("string");

	assert(js.exists("/string") == false);
	assert(js.exists("/obj/arr/3") == false);
	assert(js.exists("/obj/arr/2") == true);
	assert(js.safe!JSONValue("/obj/arr/2") == JSOB);
}


private alias SplitterResult = Tuple!(string, "token", string, "remainder");

/// Used to split path like /hello/world in tokens
pure nothrow @safe @nogc
private SplitterResult split_json_path(in string path)
{
	immutable idx = path.indexOf('/');

	switch (idx)
	{
		case  0: return split_json_path(path[1..$]);
		case -1: return SplitterResult(path, string.init);
		default: return SplitterResult(path[0..idx], path[idx+1..$]);
	}

	assert(0);
}

/// You can build a json object with JsonObjectBuilder("key", 32, "another_key", "hello", "subobject", JsonObjectBuilder(...));
pure
JSONValue JsonObjectBuilder(T...)(T vals)
{
   void appendJsonVals(T...)(ref JSONValue value, T vals)
   {
      // Appends nothing, recursion ends
      static if (vals.length == 0) return;

      // We're working with a tuple (key, value, key, value, ...) so args%2==0 is key and args%2==1 is value
      else static if (vals.length % 2 == 0)
      {
         // Key should be a string!
         static if (!isSomeString!(typeof(vals[0])))
            throw new Exception("Wrong param type. Key not valid.");

			else value[vals[0]] = vals[1];

         // Recursion call
         static if (vals.length > 2)
            appendJsonVals(value, vals[2..$]);

      } else throw new Exception("Wrong params. Should be: JsonObjectBuilder(string key1, T1 val1, string key2, T2 val2, ...)");
   }

   JSONValue value = string[string].init;

   static if (vals.length > 0)
		appendJsonVals(value, vals);

   return value;
}

/// You can build a json array with JsonArrayBuilder("first", 32, "another_element", 2, 23.4, JsonObjectBuilder(...));
pure
JSONValue JsonArrayBuilder(T...)(T vals)
{
   JSONValue value = JSONValue[].init;
   value.array.length = vals.length;

   foreach(idx, v; vals)
      value[idx] = v;

   return value;
}

unittest
{
   {
      enum js = JSOB("array", JSAB(1,2,"blah"), "subobj", JSOB("int", 1, "string", "str", "array", [1,2,3]));
      assert(js.safe!int("/array/1") == 2);
      assert(js.safe!int("/subobj/int") == 1);
      assert(js.safe!string("/subobj/string") == "str");
      assert(js.as!string("/subobj/array/2") == "3");
      assert(js.exists("/subobj/string") == true);
      assert(js.exists("/subobj/other") == false);

      // /array/1 it's an integer
      {
         // Can't get a string
         {
            immutable val = js.safe!string("/array/1", "default");
            assert(val.exists == true);
            assert(val.ok == false);
            assert(val == "default");
         }

         // Can read as string
         {
            immutable val = js.as!string("/array/1", "default");
            assert(val.exists == true);
            assert(val.ok == true);
            assert(val == "2");
         }
      }


      // This value doesn't exist
      {
         immutable val = js.as!string("/subobj/other", "default");
         assert(val.exists == false);
         assert(val.ok == false);
         assert(val == "default");
      }


      // Value exists but can't convert to int
      {
         immutable val = js.as!int("/array/2", 15);
         assert(val.exists == true);
         assert(val.ok == false);
         assert(val == 15);
      }

      // Can't edit an enum, of course
      assert(__traits(compiles, js.remove("/subobj/string")) == false);

      // But I can edit a copy
      JSONValue cp = js;
      assert(cp == js);
      assert(cp.toString == js.toString);

      cp.remove("/subobj/string");
      assert(cp.exists("/subobj/string") == false);
      assert(cp.exists("/subobj/int") == true);

   }
}


unittest
{
   import std.json : parseJSON;

   // Standard way
   JSONValue json = parseJSON(`{"user" : "foo", "address" : {"city" : "venice", "country" : "italy"}, "tags" : ["hello" , 3 , {"key" : "value"}]}`);

   {
      string user = json.safe!string("user"); // Read a string from json
      assert(user == "foo");
   }

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

   {
      // I can read deep fields
      assert(json.safe!string("/address/city") == "venice");

      // also inside an array
      assert(json.safe!string("/tags/2/key") == "value");
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

      assert(json.safe!int("/this/is/a/deep/value") == 100);
      assert(json.safe!string("/this/is/an/array/5") == "hello"); // elements 0,1,2,3,4 are nulled
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

      assert(jv.toString == `{"array":[1,2,3],"key":"value","mixed_array":[1,"hello",3.0],"obj":{"subkey":3}}`);
   }

   {
      JSONValue jv = JSOB
      (
         "key", "value",
         "obj", JSOB("subkey", 3),
         "array", [1,2,3],
         "mixed_array", JSAB(1, "hello", 3.0f)
      );

      foreach(size_t idx, o; jv.safe!JSONValue("/array"))
      {
         assert(o.safe!int("/") == idx+1);
         assert(o.as!float("") == idx+1);
         assert(o.read!int("/")== idx+1);
         assert(o.safe!int == idx+1);
         assert(o.as!float == idx+1);
         assert(o.read!int == idx+1);
      }
   }
}

/// Append value to array. Array is created if not exists.
pure
ref JSONValue append(T)(return ref JSONValue json, in string path, in T value)
{
    auto r = json.as!JSONValue(path);

    if (!r.exists) json.put(path ~ "/0", value);
    else if (r.value.type != JSONType.array) json.put(path, JSAB(r.value, value));
    else json.put(path ~ "/" ~ r.array.length.to!string, value);

    return json;
}

unittest 
{
    auto j = JSOB("k-1", "v-1", "k-2", 1);

    j.put("/k-3/0", "v-3-1");
    j.put("/k-3/1", "v-3-2");

    j.append("/k-3", "v-3-3");
    j.append("k-4", "v-4-1");
    j.append("k-4", "v-4-2");
    j.append("k-2", "v-2-2");

    assert(j.toString == `{"k-1":"v-1","k-2":[1,"v-2-2"],"k-3":["v-3-1","v-3-2","v-3-3"],"k-4":["v-4-1","v-4-2"]}`);
}

/// Parse a string
pure
ref JSONValue parse(return ref JSONValue json, in string data)
{
    import std.json : parseJSON;
    json = parseJSON(data);
    return json;
}
