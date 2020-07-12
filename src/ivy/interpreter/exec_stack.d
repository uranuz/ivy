module ivy.interpreter.exec_stack;

import ivy.interpreter.data_node: IvyData;
import ivy.interpreter.common: IvyInterpretException;

struct ExecStack
{
	import std.exception: enforce;

	IvyData[] _stack;
	size_t[] _stackBlocks;

	void addStackBlock() {
		this._stackBlocks ~= this._stack.length;
	}

	void removeStackBlock()
	{
		import std.range: popBack, empty;
		enforce!IvyInterpretException(!this._stackBlocks.empty, `Cannot remove stack block!`);
		this.popBackN(this.length); // Remove odd items from stack
		this._stackBlocks.popBack();
	}

	// Test if current stack block is empty
	bool empty() @property
	{
		import std.range: back, empty;
		if( this._stackBlocks.empty || this._stack.empty )
			return true;
		return this._stack.length <= this._stackBlocks.back;
	}

	// Get current item from the stack
	ref IvyData back() @property
	{
		import std.range: back;
		enforce!IvyInterpretException(!this.empty, `Cannot get exec stack "back" property, because it is empty!!!`);
		return this._stack.back();
	}

	// Drop current item from the stack
	IvyData popBack()
	{
		import std.range: popBack, back;
		enforce!IvyInterpretException(!this.empty, `Cannot execute "popBack" for exec stack, because it is empty!!!`);
		IvyData val = this._stack.back();
		this._stack.popBack();
		return val;
	}

	void popBackN(size_t count)
	{
		import std.range: popBackN;
		enforce!IvyInterpretException(count <= this.length, `Requested to remove more items than exists in stack block`);
		this._stack.popBackN(count);
	}

	void push(T)(auto ref T arg) {
		this._stack ~= IvyData(arg);
	}

	//void opOpAssign(string op : "~", T)(auto ref T arg) {
	//	this._stack ~= arg;
	//}

	import std.traits: isIntegral;

	void opIndexAssign(T, Int)(auto ref T arg, Int index)
		if( isIntegral!Int )
	{
		import std.range: back;
		enforce!IvyInterpretException(!this.empty, `Cannot assign item of empty exec stack!!!`);
		this._stack[index + _stackBlocks.back] = arg;
	}

	ref IvyData opIndex(Int)(Int index)
		if( isIntegral!Int )
	{
		import std.range: back;
		enforce!IvyInterpretException(!this.empty, `Cannot get item by index for empty exec stack!!!`);
		return this._stack[index + this._stackBlocks.back];
	}

	size_t length() @property
	{
		import std.range: empty, back;
		if( this._stackBlocks.empty )
			return 0;
		return this._stack.length - this._stackBlocks.back;
	}

	size_t opDollar() {
		return this.length;
	}
}