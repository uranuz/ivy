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
		if( res.parent === undefined ) {
			throw new errors.IvyError('Cannot find variable with name: ' + varName);
		}
		return res.node;
	},

	canFindValue: function(varName) {
		return this.findValue(varName, FrameSearchMode.tryGet).parent !== undefined;
	},

	getDataNodeType(varName) {
		var res = this.findValue(varName, FrameSearchMode.get);
		if( res.parent === undefined ) {
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
			namePart,
			parent;

		for( ; partIdx < nameSplitted.length; ++partIdx )
		{
			namePart = nameSplitted[partIdx];
			parent = res.node;
			res = {};

			switch( iu.getDataNodeType(parent) ) {
				case IvyDataType.AssocArray: {
					if( parent.hasOwnProperty(namePart) ) {
						// If node exists in assoc array then push it as next parent node (or as a result if it's the last)
						res = {parent: parent, node: parent[namePart]};
					}
					else
					{
						if( mode === FrameSearchMode.setWithParents ) {
							// In setWithParents mode we create parent nodes as assoc array if they are not exist
							parent[namePart] = {}; // Allocating dict
							res = {parent: parent, node: parent[namePart]};
						} else if( mode === FrameSearchMode.set ) {
							res = {parent: parent};
						}
					}
					break;
				}
				case IvyDataType.ExecutionFrame: {
					if( iu.getDataNodeType(parent._dataDict) !== IvyDataType.AssocArray )
					{
						if( mode === FrameSearchMode.tryGet ) {
							break;
						} else {
							throw new errors.IvyError(
								'Cannot find node, because execution frame data dict is not of assoc array type!!!');
						}
					}

					if( parent._dataDict.hasOwnProperty(namePart) ) {
						res = {parent: parent, node: parent._dataDict[namePart]};
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
					var tmpNode = parent.getAttr(namePart);
					if( tmpNode !== undefined ) {
						res = {parent: parent, node: tmpNode};
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
				default: break;
			}
			if( mode === FrameSearchMode.get ) {
				if( nameSplitted.length > 1 && (nameSplitted.length - partIdx) === 1 && res.parent === undefined ) {
					// If this name part is a property of object (not a stand alone var) then return that we found "undefined" value
					// For this we should put parent on it's place
					res.parent = parent;
				}
			}
		}
		return res;
	},

	findValue: function(varName, mode)
	{
		// If current frame has it's own scope then try to find in it.
		// If it is noscope then search into it's _moduleFrame, because we could still have some symbols there
		var res = this.findLocalValue(varName, mode);
		if( res.parent !== undefined ) {
			return res;
		}

		var modResult = {};
		if( this._moduleFrame ) {
			modResult = this._moduleFrame.findLocalValue(varName, mode);
		}

		if( modResult.parent !== undefined ) {
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
		var res = this.findValue(varName, FrameSearchMode.set);
		this._assignNodeAttribute(res.parent, value, varName);
	},

	setValueWithParents(varName, value) {
		var res = this.findValue(varName, FrameSearchMode.setWithParents);
		this._assignNodeAttribute(res.parent, value, varName);
	},

	hasOwnScope: function() {
		return !this._isNoscope;
	}
});
});