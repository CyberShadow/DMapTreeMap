<!DOCTYPE html>
<title>Map TreeMap viewer for map file <?=htmlspecialchars($_GET['id'])?></title>
<meta http-equiv="Content-Type" content="text/html; charset=utf-8">
<?='<script src="data/' . htmlspecialchars($_GET['id']) . '.json"></script>'?>
<script src="http://ajax.googleapis.com/ajax/libs/jquery/1.6.4/jquery.min.js"></script>
<style>
body {
	margin: 0;
}
.node {
	font-family: sans-serif;
	font-size: 6pt;
	overflow: hidden;
	word-wrap: break-word;
	text-align: center;
}
</style>
<script>
var PADDING = 2;
var TOP_PADDING = 10;

$(document).ready(function() {
	var rootDiv = $('<div>')
		.css('position', 'absolute')
		.css('top', '0')
		.css('left', '0')
		.css('width', '100%')
		.css("height", $(document).height())
		.addClass('node')
		.appendTo($('body'));

	function populate(div, data) {
		div.text(data.treeName);

		var children = [];
		for (var name in data.children) {
			var child = data.children[name];
			child.treeName = name;
			child.size = child.total;
			children.push(child);
		}
		for (var name in data.leaves) {
			var child = data.leaves[name];
			child.treeName = name;
			children.push(child);
		}
		if (!children.length)
			return;

		children.sort(function(a, b) { return b.size - a.size; });
		var w, h;

		var w = div.width () - (    PADDING+PADDING);
		var h = div.height() - (TOP_PADDING+PADDING);
		if (w<=0 || h<=0) return;
		var y = 0;

		while (children.length)
		{
			var n = 0;
			var rowTotal = 0;

			do
			{
				rowTotal += children[n].size;
				n++;
				var rowHeight = rowTotal / data.total * h;
			}
			while (rowHeight < w/n && n < children.length);

			var x = 0;
			for (var i=0; i<n; i++) {
				var child = children.shift();
				var childW = child.size / rowTotal * w;
				var childDiv = $('<div>')
					.css('position', 'absolute')
					.css('left',   PADDING+x+'px')
					.css('top',    TOP_PADDING+y+'px')
					.css('width',  childW+'px')
					.css("height", rowHeight+'px')
					.css('background-color', '#'+Math.floor(Math.random()*0x1000000).toString(16))
					.addClass('node')
					.appendTo(div);
				x += childW;
				populate(childDiv, child);
			}

			y += rowHeight;
		}
	}

	function arrange() {
		rootDiv.empty();

		treeData.treeName = 'Program';
		populate(rootDiv, treeData);
	}

	arrange();
});
</script>
