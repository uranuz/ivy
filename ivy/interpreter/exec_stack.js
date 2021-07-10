define('ivy/interpreter/exec_stack', [
	'ivy/exception',
	'ivy/utils'
], function(
	InterpreterException,
	iutil
) {
var assure = iutil.ensure.bind(iutil, InterpreterException);
return FirClass(
	function ExecStack() {
		this._stack = [];
		this._blocks = [];
	}, {
		/** Add item in the back of stack */
		push: function(val) {
			assure(this._blocks.length, "Cannot push execution stack value without any stask block");
			this._stack.push(val);
		},

		/** Returns last item added into stack */
		back: firProperty(function() {
			assure(!this.empty, "Cannot get exec stack \"back\" property, because it is empty!");
			return this._stack[this._stack.length - 1];
		}),

		/** Drop last item from stack */
		pop: function() {
			assure(!this.empty, "Cannot remove item from execution stack, because it is empty!");

			return this._stack.pop();
		},

		/** Drop last `count` items from stack */
		popN: function(count) {
			assure(count <= this.length, "Cannot remove items from execution stack, because there is not enough of them!");
			return this._stack.splice(-count, count);
		},

		/** Check if stack is empty */
		empty: firProperty(function() {
			return !this.length;
		}),

		/** Get length of current block of stack */
		length: firProperty(function() {
			return this._stack.length - this._backBlock;
		}),

		setAt: function(val, index) {
			assure(index < this.length, "Cannot assign item by index that not exists!");
			this._stack[index + this._backBlock] = val;
		},

		at: function(index) {
			assure(index < this.length, "Cannot get item by index that not exists!");
			return this._stack[index + this._backBlock];
		},

		/** Creates new block in stack */
		addBlock: function() {
			this._blocks.push(this._stack.length);
		},

		/** Removes last block from stack */
		removeBlock: function() {
			assure(this._blocks.length, "Cannot remove stack block. Execution stack is empty!");
			this.popN(this.length);
			this._blocks.pop();
		},

		_backBlock: firProperty(function() {
			return this._blocks.length? this._blocks[this._blocks.length - 1]: 0;
		})
	});
});