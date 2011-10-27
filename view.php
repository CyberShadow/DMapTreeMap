<!DOCTYPE html>
<title>D Map TreeMap Viewer for map file <?=htmlspecialchars($_GET['id'])?></title>
<meta http-equiv="Content-Type" content="text/html; charset=utf-8">
<?='<script src="data/' . htmlspecialchars($_GET['id']) . '.json"></script>'?>
<script src="http://ajax.googleapis.com/ajax/libs/jquery/1.6.4/jquery.min.js"></script>
<style>
body {
	margin: 0;
}
.node {
	font-family: sans-serif;
	font-size: 7pt;
	overflow: hidden;
	word-wrap: break-word;
	text-align: center;
}
</style>
<script>
var PADDING = 2;
var TOP_PADDING = 10;

function colorStr(c) {
	var r = Math.floor(c).toString(16);
	while (r.length<6) r = '0'+r;
	return '#'+r;
}
function randomColor() {
	return Math.floor(Math.random()*0x1000000);
}

$(document).ready(function() {
	var rootDiv = $('<div>')
		.css('position', 'absolute')
		.css('top', '0')
		.css('left', '0')
		.css('width', '100%')
		.addClass('node')
		.appendTo($('body'));

	function populate(div, data, depth) {
		var colorMask = (0xFF >> depth) * 0x010101;

		div
			.css('background-color', colorStr(data.color))
			.text(data.treeName);

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
				child.color = ((randomColor() & colorMask) | 0x202020 | (i%2*0x101010)) ^ data.color;
				var childW = child.size / rowTotal * w;
				var left   = Math.floor(PADDING+x);
				var top    = Math.floor(TOP_PADDING+y);
				var right  = Math.floor(PADDING+x+childW);
				var bottom = Math.floor(TOP_PADDING+y+rowHeight);
				var childDiv = $('<div>')
					.css('position', 'absolute')
					.css('left',   left+'px')
					.css('top',    top +'px')
					.css('width',  right-left+'px')
					.css("height", bottom-top+'px')
					.addClass('node')
					.appendTo(div);
				x += childW;
				populate(childDiv, child, depth+1);
			}

			y += rowHeight;
		}
	}

	function arrange() {
		rootDiv
			.css("height", $(document).height())
			.empty();

		treeData.treeName = 'Program';
		treeData.color = 0xFFFFFF;
		populate(rootDiv, treeData, 1);
	}

	//$(window).resize(arrange);

	arrange();
});
</script>
