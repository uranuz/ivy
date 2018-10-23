define('ivy/ExecutionFrame', [
	'ivy/Consts',
	'ivy/utils',
	'ivy/errors'
], function(
	Consts, iu, errors
) {
var
	FrameSearchMode = Consts.FrameSearchMode,
	IvyDataType = Consts.IvyDataType;
function ExecutionFrame(callableObj, modFrame, dataDict, isNoscope) {
	this._callableObj = callableObj;
	this._moduleFrame = modFrame;
	this._dataDict = dataDict || {};
	this._isNoscope = isNoscope || false;
};
return __mixinProto(ExecutionFrame, {
	getValue: function(varName) {
		var res = this.findValue(varName, FrameSearchMode.get);
		if( res.node === undefined && res.parent !== undefined ) {
			throw new errors.IvyError('Cannot find variable with name: ' + varName);
		}
		return res.node;
	},

	canFindValue: function(varName) {
		return this.findValue(varName, FrameSearchMode.tryGet).node !== undefined;
	},

	getDataNodeType(varName) {
		var res = this.findValue(varName, FrameSearchMode.get);
		if( res.node === undefined ) {
			throw new errors.IvyError('Cannot find variable with name: ' + varName);
		}
		return iu.getDataNodeType(res.node);
	},
	// Basic method used to search symbols in context
	// This method searches inside current frame without taking _moduleFrame into account
	findLocalValue: function(varName, mode) {
		if( !varName ) {
			throw new errors.IvyError('Variable name cannot be empty');
		}
		var
			nameSplitted = varName.split('.'),
			res = {node: this._dataDict},
			partIdx = 0,
			namePart;

		for( ; partIdx < nameSplitted.length && res.node !== undefined; ++partIdx )
		{
			namePart = nameSplitted[partIdx];
			res = {parent: res.node};

			switch( iu.getDataNodeType(res.parent) ) {
				case IvyDataType.AssocArray: {
					if( res.parent.hasOwnProperty(namePart) ) {
						// If node exists in assoc array then push it as next parent node (or as a result if it's the last)
						res.node = res.parent[namePart];
					}
					else
					{
						if( mode == FrameSearchMode.setWithParents ) {
							// In setWithParents mode we create parent nodes as assoc array if they are not exist
							res.parent[namePart] = {}; // Allocating dict
							res.node = res.parent[namePart];
						}
					}
					break;
				}
				case IvyDataType.ExecutionFrame: {
					if( iu.getDataNodeType(res.parent._dataDict) !== IvyDataType.AssocArray )
					{
						if( mode === FrameSearchMode.tryGet ) {
							break;
						} else {
							throw new errors.IvyError(
								'Cannot find node, because execution frame data dict is not of assoc array type!!!');
						}
					}

					if( res.parent._dataDict.hasOwnProperty(namePart) ) {
						res.node = res.parent._dataDict[namePart];
					} else {
						if( [FrameSearchMode.setWithParents, FrameSearchMode.set].indexOf(mode) >= 0 ) {
							throw new errors.IvyError(
								'Cannot set node with name: ' + varName + ', because parent node: ' + namePart
								+ ' not exists or cannot set value in foreign execution frame!'
							);
						}
					}
					break;
				}
				case IvyDataType.ClassNode: {
					// If there is class nodes in the path to target path, so it's property this way
					// No matter if it's set or get mode. The last node setting is handled by code at the start of loop
					var tmpNode = res.parent.getAttr(namePart);
					if( tmpNode !== undefined ) {
						res.node = tmpNode;
					} else {
						if( [FrameSearchMode.setWithParents, FrameSearchMode.set].indexOf(mode) >= 0 ) {
							throw new errors.IvyError(
								'Cannot set node with name: ' + varName + ', because parent node: ' + namePart
								+ 'not exist or cannot add new attribute to class node!'
							);
						}
					}
					break;
				}
				default:
					break;
			}
		}
		if( (nameSplitted.length - partIdx) < 2 ) {
			return res;
		}

		return {};
	},

	findValue: function(varName, mode)
	{
		// If current frame has it's own scope then try to find in it.
		// If it is noscope then search into it's _moduleFrame, because we could still have some symbols there
		var res = this.findLocalValue(varName, mode);
		if( res.node !== undefined ) {
			return res;
		}

		var modResult = {};
		if( this._moduleFrame ) {
			modResult = this._moduleFrame.findLocalValue(varName, mode);
		}

		if( modResult.node !== undefined ) {
			return modResult;
		}
		return res;
	},

	_assignNodeAttribute: function(parent, value, varName) {
		var attrName = iu.back(varName.split('.'));
		switch( iu.getDataNodeType(parent) ) {
			case IvyDataType.AssocArray:
				parent[attrName] = value;
				break;
			case IvyDataType.ClassNode:
				parent.classNode.setAttr(value, attrName);
				break;
			default:
				throw new errors.IvyError('Unexpected node type');
		}
	},

	setValue: function(varName, value) {
		var result = this.findValue(varName, FrameSearchMode.set);
		this._assignNodeAttribute(result.parent, value, varName);
	},

	setValueWithParents(varName, value) {
		var result = this.findValue(varName, FrameSearchMode.setWithParents);
		this._assignNodeAttribute(result.parent, value, varName);
	},

	hasOwnScope: function() {
		return !this._isNoscope;
	}
});
});