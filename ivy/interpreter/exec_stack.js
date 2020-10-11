define('ivy/interpreter/exec_stack', ['ivy/utils'], function(iutil) {
return FirClass(
	function ExecStack() {
		this._stack = [];
		this._blocks = [];
	}, {
		/** Returns last item added into stack */
		back: firProperty(function() {
			if( this.empty ) {
				throw Error(`Cannot get stack item! Execution stack is empty!`);
			}
			return iutil.back(this._stack);
		}),
		/** Drop last item from stack */
		pop: function() {
			if( this.empty ) {
				throw Error(`Cannot remove item from execution stack, because it is empty!`);
			}
			return this._stack.pop();
		},
		/** Drop last `count` items from stack */
		popN: function(count) {
			if( count < this.length ) {
				throw Error(`Cannot remove items from execution stack, because it is empty!`);
			}
			return this._stack.splice(-count, count);
		},
		/** Check if stack is empty */
		empty: firProperty(function() {
			if( this._stack.length === 0 || this._blocks.length === 0 ) {
				return true;
			}
			return this._stack.length <= iutil.back(this._blocks);
		}),
		/** Get length of current block of stack */
		length: firProperty(function() {
			if( this.empty ) {
				return 0;
			}
			return this._stack.length - iutil.back(this._blocks);
		}),
		/** Creates new block in stack */
		addStackBlock: function() {
			this._blocks.push(this._stack.length);
		},
		/** Removes last block from stack */
		removeStackBlock: function() {
			if( this._blocks.length === 0 ) {
				throw Error(`Cannot remove stack block. Execution stack is empty!`);
			}
			this.popN(this.length);
			this._blocks.pop();
		},
		/** Add item in the back of stack */
		push: function(val) {
			this._stack.push(val);
		},
		at: function(index) {
			if( index >= this.length || index < 0 ) {
				throw Error(`Index is out of stack bounds!`);
			}
			return this._stack[iutil.back(this._blocks) + index];
		},
		setAt: function(val, index) {
			if( index >= this.length || index < 0 ) {
				throw Error(`Index is out of stack bounds!`);
			}
			this._stack[iutil.back(this._blocks) + index] = val;
		}
	});
});