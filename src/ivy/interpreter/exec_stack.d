module ivy.interpreter.exec_stack;

struct ExecStack
{
	import trifle.utils: ensure;

	import ivy.types.data: IvyData;
	import ivy.interpreter.exception: IvyInterpretException;

	alias assure = ensure!IvyInterpretException;

private:
	IvyData[] _stack;
	size_t[] _blocks;

public:
	void push(T)(auto ref T arg) {
		assure(this._blocks.length, "Cannot push execution stack value without any stask block");
		this._stack ~= IvyData(arg);
	}

	// Get current item from the stack
	ref IvyData back() @property {
		assure(!this.empty, "Cannot get exec stack \"back\" property, because it is empty!");
		return this._stack[this._stack.length - 1];
	}

	// Drop current item from the stack
	IvyData pop() {
		import std.range: popBack;
		assure(!this.empty, "Cannot remove item from execution stack, because it is empty!");
		IvyData val = this.back;
		this._stack.popBack();
		return val;
	}

	void popN(size_t count) {
		import std.range: popBackN;
		assure(count <= this.length, "Cannot remove items from execution stack, because there is not enough of them!");
		this._stack.popBackN(count);
	}

	// Test if current stack block is empty
	bool empty() @property {
		return !this.length;
	}

	size_t length() @property {
		return this._stack.length - this._backBlock;
	}

	import std.traits: isIntegral;

	void opIndexAssign(T, Int)(auto ref T arg, Int index)
		if( isIntegral!Int )
	{
		assure(index < this.length, "Cannot assign item by index that not exists!");
		this._stack[index + this._backBlock] = arg;
	}

	ref IvyData opIndex(Int)(Int index)
		if( isIntegral!Int )
	{
		assure(index < this.length, "Cannot get item by index that not exists!");
		return this._stack[index + this._backBlock];
	}

	/** Creates new block in stack */
	void addBlock() {
		this._blocks ~= this._stack.length;
	}

	/** Removes last block from stack */
	void removeBlock() {
		import std.range: popBack;
		assure(this._blocks.length, "Cannot remove stack block. Execution stack is empty!");
		this.popN(this.length); // Remove odd items from stack
		this._blocks.popBack();
	}

	size_t _backBlock() @property {
		return this._blocks.length? this._blocks[this._blocks.length - 1]: 0;
	}

	size_t opDollar() {
		return this.length;
	}
}