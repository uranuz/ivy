module plain_test;

import std.stdio;

struct A
{
	int a;
	int[] b;
	string name;
	
	this(this)
	{
		writeln("Postblit called on, ", name);
		name = name.dup;
	
	}

	ref A opAssign(ref A s)
	{
		writeln("opAssign called on, ", name);
		return this;
	}
	
	~this()
	{
		writeln("dtor called on, ", name);
	}

}


void main()
{
	A a1;
	a1.name = "a1";
	writeln("Initializing a2 with a1");
	A a2 = a1;
	writeln( "a2.name is a1.name: ", a2.name is a1.name );
	a2.name = "a2";
	writeln("Initializing a3 with a1");
	A a3 = a2;
	writeln( "a3.name is a2.name: ", a3.name is a2.name );
	a3.name = "a3";
	writeln("Assigning a3 with a1");
	a3 = a1;
	
	writeln( "a3.name is a2.name: ", a3.name is a2.name );
	writeln( "a3.name is a1.name: ", a3.name is a1.name );
	writeln( "a3.name is null: ", a3.name is null );
	writeln( "a3.name: ", a3.name );

}