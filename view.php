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
	position: absolute;
	font-family: sans-serif;
	font-size: 7pt;
	overflow: hidden;
	word-wrap: break-word;
	text-align: center;
	color: black;
}
.popup {
	position: absolute;
	border: 1px solid black;
	background-color: #FFFFDD;
	word-wrap: break-word;
	padding: 2px;
}
.selected {
	background-color: #4040FF !important;
	color: white;
}
</style>
<script>
var PADDING = 2;
var TOP_PADDING = 10;
var POPUP_DISTANCE = 10;

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
		.css('top', '0')
		.css('left', '0')
		.css('width', '100%')
		.appendTo($('body'));

	function populate(div, data, path) {
		var colorMask = (0xFF >> (path.length+1)) * 0x010101;

		div
			.css('background-color', colorStr(data.color))
			.addClass('node')
			.data('mapdata', data)
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

				path.push(child.treeName);
				if (path[0]=='/')
					child.treePath = path.join('/').substr(1);
				else
					child.treePath = path.join('.');

				if (child.color === undefined)
					child.color = ((randomColor() & colorMask) | 0x202020 | (i%2*0x101010)) ^ data.color;

				var childW = child.size / rowTotal * w;
				var left   = Math.floor(PADDING+x);
				var top    = Math.floor(TOP_PADDING+y);
				var right  = Math.floor(PADDING+x+childW);
				var bottom = Math.floor(TOP_PADDING+y+rowHeight);
				var childDiv = $('<div>')
					.css('left',   left+'px')
					.css('top',    top +'px')
					.css('width',  right-left+'px')
					.css("height", bottom-top+'px')
					.appendTo(div);
				x += childW;

				populate(childDiv, child, path);
				path.pop();
			}

			y += rowHeight;
		}
	}

	function arrange() {
		rootDiv
			.css("height", 0)
			.css("height", $(document).height())
			.empty();

		treeData.treeName = treeData.treePath = 'Program';
		treeData.color = 0xFFFFFF;
		populate(rootDiv, treeData, []);
	}

	var resizeTimer = null;
	$(window).resize(function() {
		if (resizeTimer)
			clearTimeout(resizeTimer);
		resizeTimer = setTimeout(function() {
			resizeTimer = null;
			arrange();
		}, 100);
	});

	arrange();

	var popup = $('<div>')
		.addClass('popup')
		.appendTo($('body'));

	$('.node').live('mousemove', function(e) {
		if (e.clientX < rootDiv.width()/2) {
			popup.css('left' , e.clientX+POPUP_DISTANCE);
			popup.css('right', '');
		} else {
			popup.css('left', '');
			popup.css('right' , $(document).width() - e.clientX + POPUP_DISTANCE);
		}

		if (e.clientY < rootDiv.height()/2) {
			popup.css('top' , e.clientY+POPUP_DISTANCE);
			popup.css('bottom', '');
		} else {
			popup.css('top', '');
			popup.css('bottom' , $(document).height() - e.clientY + POPUP_DISTANCE);
		}
		popup.css('max-width' , rootDiv.width ()/2 - POPUP_DISTANCE*2);
		popup.css('max-height', rootDiv.height()/2 - POPUP_DISTANCE*2);


		var mapdata = $(e.target).data('mapdata');
		var html = '';
		if (mapdata.mangledName !== undefined)
			html += '<b>Mangled name</b>: ' + mapdata.mangledName + '<br>';
		else
			html += mapdata.treePath + '<br>';

		if (mapdata.demangledName)
			html += '<b>Demangled name</b>: ' + mapdata.demangledName + '<br>';

		if (mapdata.total !== undefined)
			html += '<b>Total size</b>: ' + mapdata.total + ' bytes<br>';
		else
			html += '<b>Size</b>: ' + mapdata.size + ' bytes<br>';

		if (mapdata.address !== undefined)
			html += '<b>Address</b>: 0x' + mapdata.address.toString(16) + '<br>';

		popup.html(html);

		$('.selected').removeClass('selected');
		$(e.target).addClass('selected');
	});
});

document.write('<style type="text/css">.nojs { display: none; }</style>');
</script>
<div class="nojs">Needs JavaScript (sorry, Nick!)</div>