define('ivy/ClassNode', [], function() {
	function ClassNode() {
		throw new Error('Cannot create instance of abstract class!');
	};
	return __mixinProto(ClassNode, {});
});