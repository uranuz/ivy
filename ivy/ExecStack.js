define('ivy/ExecStack', ['ivy/utils'], function(iu) {
	function ExecStack() {
		this._stack = [];
		this._blocks = [0];
	};
	return __mixinProto(ExecStack, {
		/** Returns last item added into stack */
		back: function() {
			if( this.empty() ) {
				throw Error(`Cannot get stack item! Execution stack is empty!`);
			}
			return iu.back(this._stack);
		},
		/** Drop last item from stack */
		pop: function() {
			if( this.empty() ) {
				throw Error(`Cannot remove item from execution stack, because it is empty!`);
			}
			return this._stack.pop();
		},
		/** Drop last `count` items from stack */
		popN: function(count) {
			if( count < this.getLength() ) {
				throw Error(`Cannot remove items from execution stack, because it is empty!`);
			}
			return this._stack.splice(-count, count);
		},
		/** Check if stack is empty */
		empty: function() {
			if( this._stack.length === 0 || this._blocks.length === 0 ) {
				return true;
			}
			return this._stack.length <= iu.back(this._blocks);
		},
		/** Get length of current block of stack */
		getLength: function() {
			if( this.empty() ) {
				return 0;
			}
			return this._stack.length - iu.back(this._blocks);
		},
		/** Creates new block in stack */
		addStackBlock: function() {
			this._blocks.push(this._stack.length);
		},
		/** Removes last block from stack */
		removeStackBlock: function() {
			if( this.empty() ) {
				throw Error(`Cannot remove stack block. Execution stack is empty!`);
			}
			this.popBackN(this.getLength());
			this._blocks.pop();
		},
		/** Add item in the back of stack */
		push: function(val) {
			this._stack.push(val);
		},
		at: function(index) {
			if( index >= this.getLength() || index < 0 ) {
				throw Error(`Index is out of stack bounds!`);
			}
			return this._stack[iu.back(this._blocks) + index];
		},
		setAt: function(val, index) {
			if( index >= this.getLength() || index < 0 ) {
				throw Error(`Index is out of stack bounds!`);
			}
			this._stack[iu.back(this._blocks) + index] = val;
		}
	});
});