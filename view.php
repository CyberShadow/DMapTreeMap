<!DOCTYPE html>
<title>D Map TreeMap Viewer for map file <?=htmlspecialchars($_GET['id'])?></title>
<meta http-equiv="Content-Type" content="text/html; charset=utf-8">
<?php print '<script src="data/' . htmlspecialchars($_GET['id']) . '.json"></script>' ?>
<script src="//ajax.googleapis.com/ajax/libs/jquery/1.6.4/jquery.min.js"></script>
<style>
body {
	margin: 0;
}
.node {
	position: absolute;
	font-family: sans-serif;
	font-size: 7pt;
	line-height: 8pt;
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
	overflow: auto;
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
	var $rootDiv = $('<div>')
		.css('top', '0')
		.css('left', '0')
		.css('width', '100%')
		.appendTo($('body'));

	function populate(div, data, path, w, h) {
		var level = Math.min(path.length+1, 4);
		var colorMask = (0xFF >> level) * 0x010101;

		div.className = 'node';
		div.style.backgroundColor = colorStr(data.color);
		div.mapdata = data;
		div.textContent = data.treeName;

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

		children.sort(function(a, b) { return b.size!=a.size ? b.size - a.size : a.treeName.localeCompare(b.treeName); });

		w -=     PADDING+PADDING;
		h -= TOP_PADDING+PADDING;
		if (w<=0 || h<=0) return;
		var y = 0;

		while (children.length)
		{
			var rowTotal = 0, rowHeight = 0;

			for (var n=0; n<children.length; n++)
			{
				var newTotal = rowTotal + children[n].size;
				var newHeight = newTotal / data.total * h;
				var childWidth = children[n].size / newTotal * w;
				if (n && childWidth < newHeight)
					break;
				rowTotal = newTotal;
				rowHeight = newHeight;
			}

			var x = 0;
			for (var i=0; i<n; i++) {
				var child = children.shift();

				path.push(child.treeName);
				if (path[0]=='/')
					if (path.length==1)
						child.treePath = "Filesystem objects";
					else
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
				var childDiv = document.createElement('div');
				childDiv.className    = 'node';
				childDiv.style.left   = left+'px';
				childDiv.style.top    = top +'px';
				childDiv.style.width  = right-left+'px';
				childDiv.style.height = bottom-top+'px';
				div.appendChild(childDiv);
				x += childW;

				populate(childDiv, child, path, right-left, bottom-top);
				path.pop();
			}

			y += rowHeight;
		}
	}

	var rootWidth, rootHeight;

	function arrange() {
		$rootDiv
			.css("height", 0)
			.css("height", $(document).height())
			.empty();

		rootWidth  = $rootDiv.width ();
		rootHeight = $rootDiv.height();

		treeData.treeName = treeData.treePath = 'Program';
		treeData.color = 0xFFFFFF;
		populate($rootDiv[0], treeData, [], rootWidth, rootHeight);
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

	var popup = document.createElement('div');
	popup.className = 'popup';
	document.body.appendChild(popup);

	var selectedElement = null;

	$rootDiv[0].onmousemove = function(e) {
		e = e || window.event;
		e.stopPropagation();

		var s = popup.style;
		if (e.clientX < rootWidth/2) {
			s.right  = '';
			s.left   =              e.clientX + POPUP_DISTANCE + 'px';
		} else {
			s.left   = '';
			s.right  = rootWidth  - e.clientX + POPUP_DISTANCE + 'px';
		}

		if (e.clientY < rootHeight/2) {
			s.bottom = '';
			s.top    =              e.clientY + POPUP_DISTANCE + 'px';
		} else {
			s.top    = '';
			s.bottom = rootHeight - e.clientY + POPUP_DISTANCE + 'px';
		}

		var t = e.target;
		if (t == selectedElement)
			return;

		s.maxWidth  = rootWidth /2 - POPUP_DISTANCE*2 + 'px';
		s.maxHeight = rootHeight/2 - POPUP_DISTANCE*2 + 'px';

		var mapdata = t.mapdata;
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

		popup.innerHTML = html;
		if (window.getSelection)
			window.getSelection().removeAllRanges();

		var selected = document.getElementsByClassName('selected');
		for (var i in selected)
			selected[i].className = 'node';
		t.className += ' selected';

		selectedElement = t;
	};

	$rootDiv[0].onmousedown = function(e) {
		if (document.body.createTextRange) { // ms
			var range = document.body.createTextRange();
			range.moveToElementText(popup);
			range.select();
		} else if (window.getSelection) { // moz, opera, webkit
			var selection = window.getSelection();
			var range = document.createRange();
			range.selectNodeContents(popup);
			selection.removeAllRanges();
			selection.addRange(range);
		}
		e = e || window.event;
		e.stopPropagation();
		e.preventDefault();
	};
});

document.write('<style type="text/css">.nojs { display: none; }</style>');
</script>
<div class="nojs">Needs JavaScript (sorry, Nick!)</div>