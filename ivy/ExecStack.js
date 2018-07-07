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
		popBack: function() {
			if( this.empty() ) {
				throw Error(`Cannot remove item from execution stack, because it is empty!`);
			}
			this._stack.pop();
		},
		/** Drop last `count` items from stack */
		popBackN: function(count) {
			if( count < this.getLength() ) {
				throw Error(`Cannot remove items from execution stack, because it is empty!`);
			}
			this._stack.splice(-count, count);
		},
		/** Check if stack is empty */
		empty: function() {
			if( this._stack.length === 0 || this._blocks.length === 0 ) {
				return true;
			}
			return this._stack.length > iu.back(this._blocks);
		},
		/** Get length of current block of stack */
		getLength: function() {
			if( this.empty() ) {
				return 0;
			}
			return this._stack.length - iu.back(this._blocks.length - 1);
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
			var blockStart = this._blocks.pop();
			this._stack.splice(blockStart, this._stack.length);
		}
	});
});